{
  diskoPackage,
  lib,
  nixpkgsSource,
  pkgs,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "niri-installer-executor";
  version = "0.1.0";
  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  installPhase = ''
    mkdir -p "$out/bin" "$out/libexec"

    install -Dm755 ${../../scripts/install-executor.sh} "$out/libexec/install-executor.sh"

    makeWrapper "$out/libexec/install-executor.sh" "$out/bin/niri-installer-executor" \
      --set INSTALLER_CONFIGURATION_TEMPLATE ${../../scripts/target-system.nix.in} \
      --set INSTALLER_DISKO_TEMPLATE ${../../scripts/disko-layout.nix.in} \
      --set INSTALLER_NIRI_CONFIG ${../../scripts/niri-config.kdl} \
      --set INSTALLER_WAYBAR_CONFIG ${../../scripts/waybar-config.jsonc} \
      --set INSTALLER_WAYBAR_STYLE ${../../scripts/waybar-style.css} \
      --set INSTALLER_HOSTNAME niri-host \
      --set INSTALLER_NIXPKGS_SOURCE ${nixpkgsSource} \
      --set INSTALLER_LOG_FILE /var/log/niri-installer.log \
      --prefix PATH : ${lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        diskoPackage
        pkgs.findutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.jq
        pkgs.networkmanager
        pkgs.util-linux
        pkgs.whois
      ]}
  '';
}
