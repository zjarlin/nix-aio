{
  inputs,
  installerExecutor,
  installerUi,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix")
  ];

  isoImage.edition = lib.mkForce "gnome-niri-installer";
  isoImage.volumeID = lib.mkForce "NIRIINSTALL";
  isoImage.squashfsCompression = lib.mkForce "xz -Xdict-size 100%";
  isoImage.compressImage = lib.mkForce true;

  networking.networkmanager.enable = true;

  environment.systemPackages = [
    installerExecutor
    installerUi
    pkgs.gnome-control-center
  ];

  environment.etc."xdg/autostart/niri-installer-ui.desktop".source =
    (installerUi + "/share/applications/niri-installer-ui.desktop");

  services.desktopManager.gnome.favoriteAppsOverride = lib.mkForce ''
    [org.gnome.shell]
    favorite-apps=[ 'niri-installer-ui.desktop', 'org.gnome.Settings.desktop', 'org.gnome.Terminal.desktop', 'firefox.desktop', 'org.gnome.Nautilus.desktop' ]
  '';

  system.nixos.tags = [
    "niri-installer"
  ];
}
