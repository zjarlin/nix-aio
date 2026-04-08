{
  installerExecutor,
  lib,
  pkgs,
}:
let
  python = pkgs.python3.withPackages (ps: [
    ps.pygobject3
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "niri-installer-ui";
  version = "0.1.0";
  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.wrapGAppsHook4
  ];

  buildInputs = [
    python
    pkgs.gsettings-desktop-schemas
    pkgs.gtk4
  ];

  installPhase = ''
    mkdir -p "$out/bin" "$out/libexec" "$out/share/applications"

    install -Dm755 ${../../scripts/installer-ui.py} "$out/libexec/installer-ui.py"

    makeWrapper ${python}/bin/python3 "$out/bin/niri-installer-ui" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "$out/libexec/installer-ui.py" \
      --set EXECUTOR_BIN ${installerExecutor}/bin/niri-installer-executor \
      --set INSTALLER_LOG_FILE /var/log/niri-installer.log \
      --prefix PATH : ${lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
        pkgs.findutils
        pkgs.gnome-control-center
        pkgs.gnugrep
        pkgs.jq
        pkgs.networkmanager
        pkgs.sudo
        pkgs.systemd
        pkgs.util-linux
      ]}

    cat > "$out/share/applications/niri-installer-ui.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Niri Installer
Exec=$out/bin/niri-installer-ui
Terminal=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=2
EOF
  '';
}
