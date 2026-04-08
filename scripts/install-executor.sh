#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${INSTALLER_LOG_FILE:-/var/log/niri-installer.log}"
WORK_ROOT="${INSTALLER_WORK_ROOT:-/tmp/niri-installer}"
TARGET_ROOT="/mnt"
HOSTNAME="${INSTALLER_HOSTNAME:-niri-host}"
DATA_GIB=128
OS_MIN_GIB=64

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

resolve_parent_disk() {
  local source="$1"
  local canonical=""
  local parent=""
  local direct=""

  canonical="$(readlink -f "$source" 2>/dev/null || printf '%s' "$source")"
  parent="$(lsblk -dn -o PKNAME "$canonical" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$parent" ]]; then
    printf '/dev/%s\n' "$parent"
    return 0
  fi

  direct="$(lsblk -dn -o PATH "$canonical" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$direct" ]]; then
    printf '%s\n' "$direct"
    return 0
  fi

  return 1
}

protected_disks() {
  local mount_point=""
  local source=""
  for mount_point in /iso /run/rootfsbase /nix/.ro-store /; do
    source="$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null | head -n 1 || true)"
    if [[ -z "$source" ]]; then
      continue
    fi

    resolve_parent_disk "$source" || true
  done | sort -u
}

check_network() {
  nm-online -q --timeout=20
  curl --fail --silent --show-error --location --max-time 15 \
    https://cache.nixos.org/nix-cache-info > /dev/null
}

validate_username() {
  local username="$1"
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]
}

validate_disk() {
  local disk="$1"
  local type=""
  local size_bytes=0
  local required_bytes=0

  [[ -b "$disk" ]] || fail "Target disk ${disk} is not a block device."

  type="$(lsblk -dn -o TYPE "$disk" 2>/dev/null | head -n 1 || true)"
  [[ "$type" == "disk" ]] || fail "Target device ${disk} is not a whole disk."

  if protected_disks | grep -Fxq "$disk"; then
    fail "Refusing to overwrite the live installer media: ${disk}"
  fi

  size_bytes="$(blockdev --getsize64 "$disk")"
  required_bytes=$(( (1 + DATA_GIB + OS_MIN_GIB) * 1024 * 1024 * 1024 ))
  if (( size_bytes < required_bytes )); then
    fail "Disk ${disk} is too small. Need at least $((1 + DATA_GIB + OS_MIN_GIB)) GiB."
  fi
}

render_configuration() {
  local username="$1"
  local password_hash="$2"
  local output="$3"

  sed \
    -e "s|@USERNAME@|$(escape_sed "$username")|g" \
    -e "s|@PASSWORD_HASH@|$(escape_sed "$password_hash")|g" \
    -e "s|@HOSTNAME@|$(escape_sed "$HOSTNAME")|g" \
    "$INSTALLER_CONFIGURATION_TEMPLATE" > "$output"
}

render_disko() {
  local disk="$1"
  local output="$2"

  sed \
    -e "s|@TARGET_DISK@|$(escape_sed "$disk")|g" \
    "$INSTALLER_DISKO_TEMPLATE" > "$output"
}

prepare_target_root() {
  mkdir -p "$TARGET_ROOT"
  if mountpoint -q "$TARGET_ROOT"; then
    umount -R "$TARGET_ROOT" || true
  fi
}

copy_target_assets() {
  mkdir -p "$TARGET_ROOT/etc/nixos/installer-assets"
  install -Dm644 "$INSTALLER_NIRI_CONFIG" "$TARGET_ROOT/etc/nixos/installer-assets/niri-config.kdl"
  install -Dm644 "$INSTALLER_WAYBAR_CONFIG" "$TARGET_ROOT/etc/nixos/installer-assets/waybar-config.jsonc"
  install -Dm644 "$INSTALLER_WAYBAR_STYLE" "$TARGET_ROOT/etc/nixos/installer-assets/waybar-style.css"
}

persist_log() {
  mkdir -p "$TARGET_ROOT/var/log"
  install -Dm600 "$LOG_FILE" "$TARGET_ROOT/var/log/niri-installer.log"
}

main() {
  local username=""
  local password=""
  local disk=""
  local password_hash=""
  local workdir=""
  local config_file=""
  local disko_file=""

  if [[ $# -ne 3 ]]; then
    printf 'usage: %s <username> <password> <disk>\n' "$0" >&2
    exit 2
  fi

  username="$1"
  password="$2"
  disk="$3"

  mkdir -p "$(dirname "$LOG_FILE")" "$WORK_ROOT"
  : > "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1

  log "Starting NixOS + Niri installation."
  [[ $EUID -eq 0 ]] || fail "Installer executor must run as root."
  [[ -n "${INSTALLER_CONFIGURATION_TEMPLATE:-}" ]] || fail "Missing configuration template."
  [[ -n "${INSTALLER_DISKO_TEMPLATE:-}" ]] || fail "Missing disko template."
  [[ -n "${INSTALLER_NIRI_CONFIG:-}" ]] || fail "Missing Niri config asset."
  [[ -n "${INSTALLER_WAYBAR_CONFIG:-}" ]] || fail "Missing Waybar config asset."
  [[ -n "${INSTALLER_WAYBAR_STYLE:-}" ]] || fail "Missing Waybar style asset."
  [[ -n "${INSTALLER_NIXPKGS_SOURCE:-}" ]] || fail "Missing nixpkgs source."

  validate_username "$username" || fail "Username must match ^[a-z_][a-z0-9_-]{0,30}$."
  [[ ${#password} -ge 8 ]] || fail "Password must be at least 8 characters."
  check_network || fail "A working internet connection is required before installation."
  validate_disk "$disk"

  password_hash="$(mkpasswd --method=sha-512 "$password")"
  workdir="$(mktemp -d "$WORK_ROOT/run.XXXXXX")"
  config_file="$workdir/configuration.nix"
  disko_file="$workdir/disko.nix"

  render_configuration "$username" "$password_hash" "$config_file"
  render_disko "$disk" "$disko_file"

  prepare_target_root

  log "Partitioning and mounting ${disk}."
  disko --mode destroy,format,mount "$disko_file"

  log "Generating hardware configuration."
  nixos-generate-config --root "$TARGET_ROOT"

  log "Copying declarative target assets."
  install -Dm644 "$config_file" "$TARGET_ROOT/etc/nixos/configuration.nix"
  copy_target_assets
  persist_log

  log "Running nixos-install."
  nixos-install \
    --root "$TARGET_ROOT" \
    --no-root-passwd \
    -I "nixpkgs=$INSTALLER_NIXPKGS_SOURCE" \
    -I "nixos-config=$TARGET_ROOT/etc/nixos/configuration.nix"

  persist_log
  sync
  log "Installation finished successfully."
}

main "$@"
