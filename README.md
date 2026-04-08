# Niri Installer ISO

This project builds a custom `x86_64-linux` NixOS installer ISO that boots into a GNOME live session and auto-starts a guided installer.

The guided flow requires no shell commands:

- blocks until working networking is available,
- collects only username, password, and target disk,
- wipes the selected disk completely,
- partitions as `EFI 1 GiB + OS (remainder except last 128 GiB) + DATA 128 GiB`,
- installs a NixOS target that boots into Niri.

## Build

Build on a machine that already has Nix and can build `x86_64-linux` NixOS images:

```bash
nix build .#installer-iso
```

The generated ISO will appear under `result/iso/`.

## Build On GitHub Actions

This repository includes a workflow at [`.github/workflows/build-installer-iso.yml`](./.github/workflows/build-installer-iso.yml).

After pushing the project to GitHub:

1. Open the repository's `Actions` tab.
2. Select `Build Installer ISO`.
3. Run the workflow manually with `Run workflow`.
4. Download the ISO from the workflow artifact named `niri-installer-iso-<run_number>`.

The workflow:

- runs on GitHub-hosted `ubuntu-24.04`,
- installs Nix,
- runs `nix flake check`,
- builds `.#installer-iso`,
- uploads the generated ISO and `SHA256SUMS`.

To publish the ISO into a GitHub Release instead of only an Actions artifact, run [`.github/workflows/release-installer-iso.yml`](./.github/workflows/release-installer-iso.yml) and provide a tag such as `v0.1.0`.

Important:

- The workflow builds on Linux runners, so your local machine does not need to be NixOS.
- This project still does not include a committed `flake.lock`, so CI builds resolve floating inputs until you add one from a Nix-enabled machine.

## Checks

```bash
nix flake check
```

## Outputs

- `packages.x86_64-linux.installer-iso`
- `packages.x86_64-linux.installer-ui`
- `packages.x86_64-linux.installer-executor`
