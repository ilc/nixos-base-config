{
  description = "Ira's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # PINNED: GCC 15 (C23 default) breaks dfu-programmer - 'false' is now a keyword
    # See: https://trofi.github.io/posts/326-gcc-15-switched-to-c23.html
    # To test if unpinning is safe, run:
    #   nix build nixpkgs#dfu-programmer
    # If it builds, you can remove this input and the overlay in modules/system/default.nix
    nixpkgs-qmk.url = "github:NixOS/nixpkgs/c0b0e0fddf73fd517c3471e546c0df87a42d53f4";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-qmk, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

      # Overlay to use pinned nixpkgs for QMK packages (GCC 15 breaks dfu-programmer)
      qmkOverlay = final: prev: let
        pinnedPkgs = import nixpkgs-qmk { inherit system; config.allowUnfree = true; };
      in {
        qmk = pinnedPkgs.qmk;
        qmk_hid = pinnedPkgs.qmk_hid;
        via = pinnedPkgs.via;
        vial = pinnedPkgs.vial;
      };

      # Helper function to create a NixOS configuration for a host
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname; };
        modules = [
          # Host-specific hardware
          ./hosts/${hostname}/hardware-configuration.nix

          # System modules
          ./modules/system

          # QMK overlay
          { nixpkgs.overlays = [ qmkOverlay ]; }

          # Home-manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = { inherit inputs hostname; };
              users.ira = ./users/ira.nix;
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        bear = mkHost "bear";
        slime = mkHost "slime";
        thunder = mkHost "thunder";
      };
    };
}
