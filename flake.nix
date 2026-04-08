{
  description = "Zero-command NixOS + Niri installer ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, nixpkgs, disko }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      installerExecutor = pkgs.callPackage ./nix/pkgs/installer-executor.nix {
        diskoPackage = disko.packages.${system}.default;
      };

      installerUi = pkgs.callPackage ./nix/pkgs/installer-ui.nix {
        installerExecutor = installerExecutor;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      packages.${system} = {
        installer-executor = installerExecutor;
        installer-ui = installerUi;
        installer-iso = self.nixosConfigurations.installerIso.config.system.build.isoImage;
        default = self.packages.${system}.installer-iso;
      };

      checks.${system} = {
        shell = pkgs.runCommand "shellcheck-install-executor" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
          shellcheck ${./scripts/install-executor.sh}
          touch "$out"
        '';

        python = pkgs.runCommand "pycompile-installer-ui" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 -m py_compile ${./scripts/installer-ui.py}
          touch "$out"
        '';
      };

      nixosConfigurations.installerIso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self installerExecutor installerUi;
        };
        modules = [
          ./nix/modules/installer-iso.nix
        ];
      };
    };
}
