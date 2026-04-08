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

  isoImage = {
    edition = lib.mkDefault "gnome-niri-installer";
    volumeID = lib.mkDefault "NIRIINSTALL";
  };

  networking.networkmanager.enable = true;

  environment.systemPackages = [
    installerExecutor
    installerUi
    pkgs.gnome-control-center
  ];

  environment.etc."xdg/autostart/niri-installer-ui.desktop".source =
    (installerUi + "/share/applications/niri-installer-ui.desktop");

  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };

  services.desktopManager.gnome = {
    enable = true;
    favoriteAppsOverride = ''
      [org.gnome.shell]
      favorite-apps=[ 'niri-installer-ui.desktop', 'org.gnome.Settings.desktop', 'org.gnome.Terminal.desktop', 'firefox.desktop', 'org.gnome.Nautilus.desktop' ]
    '';
  };

  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };

  system.nixos.tags = [
    "niri-installer"
  ];
}
