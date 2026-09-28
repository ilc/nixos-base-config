{
  description = "Ira's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # llama.cpp source — pinned for Qwen3.6 hybrid architecture (SSM/Mamba)
    # support and MTP. Used by modules/system/llama-server.nix to build with
    # the embedded web UI disabled (so no npm fetch).
    # Update with: nix flake lock --update-input llama-cpp-src
    llama-cpp-src = {
      url = "github:ggml-org/llama.cpp";
      flake = false;
    };

    # Secure Boot with our own keys (signed UKIs; see modules/system/secureboot.nix).
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

      # Update dfu-programmer to 1.1.0 (nixpkgs has ancient 0.7.2 from 2014)
      # TODO: Submit PR to nixpkgs and remove this overlay
      dfuProgrammerOverlay = final: prev: {
        dfu-programmer = prev.stdenv.mkDerivation rec {
          pname = "dfu-programmer";
          version = "1.1.0";

          src = prev.fetchFromGitHub {
            owner = "dfu-programmer";
            repo = "dfu-programmer";
            rev = "v${version}";
            hash = "sha256-YhiBD8rpzEVVaP3Rdfq74lhZ0Mu7OEbrMsM3fBL1Kvk=";
          };

          postPatch = ''
            touch ChangeLog
            patchShebangs .
          '';

          nativeBuildInputs = [ prev.autoreconfHook prev.pkg-config ];
          buildInputs = [ prev.libusb1 ];

          meta = with prev.lib; {
            description = "Device Firmware Update based USB programmer for Atmel chips";
            homepage = "https://github.com/dfu-programmer/dfu-programmer";
            license = licenses.gpl2Plus;
            platforms = platforms.unix;
            mainProgram = "dfu-programmer";
          };
        };
      };

      # Host classes — single source of truth (consumed via specialArgs below).
      # Intel hosts get iHD/VAAPI drivers + thermald; RAM-tight build boxes
      # (16-32GB) get the compile throttle. AMD/big hosts (slime, kraken) are in
      # neither. Add a new host to the relevant list(s) here — nowhere else.
      intelHosts = [ "thunder" "bear" "owl" ];
      ramTightHosts = [ "thunder" "owl" ];
      laptopHosts = [ "thunder" "bear" "owl" "kraken" ];
      secureBootHosts = [ "kraken" ];

      # Helper function to create a NixOS configuration for a host
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
          isIntel = builtins.elem hostname intelHosts;
          isRamTight = builtins.elem hostname ramTightHosts;
          isLaptop = builtins.elem hostname laptopHosts;
          isSecureBoot = builtins.elem hostname secureBootHosts;
        };
        modules = [
          # Host-specific hardware
          ./hosts/${hostname}/hardware-configuration.nix

          # System modules
          ./modules/system

          # Overlays
          { nixpkgs.overlays = [ dfuProgrammerOverlay inputs.claude-code-nix.overlays.default ]; }

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
        owl = mkHost "owl";
        kraken = mkHost "kraken";
      };
    };
}
