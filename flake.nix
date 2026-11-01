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

    # The nixpkgs before the CVE-2026-98432 update, for packages that update
    # left broken (see holdbackOverlay). Drop it once that list is empty.
    # This nixpkgs is from 2026-10-10; held back since 2026-10-31. The older
    # it gets, the more security fixes those packages miss.
    nixpkgs-holdback.url = "github:NixOS/nixpkgs/6510408d147d8c5e6d76043e899e9251756f6a75";
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

      # nats-server 2.15.1 (nixpkgs has 2.14.7): skips 2.15.0's issues, and every
      # host builds it from this one lock, so all servers run the same version.
      natsServerOverlay = final: prev: {
        nats-server = prev.nats-server.overrideAttrs (finalAttrs: old: {
          version = "2.15.1";
          src = prev.fetchFromGitHub {
            owner = "nats-io";
            repo = "nats-server";
            rev = "v${finalAttrs.version}";
            hash = "sha256-VjCUNo8gbMCqHBslUHsJGn9lhb0hNoGMDlttVy0BmYw=";
          };
          vendorHash = "sha256-4HUEDsjHfOUcrenjZ4r1TdpI7VKYxIuLrsTKw0419gU=";
        });
      };

      # Packages taken from nixpkgs-holdback because the current nixpkgs marks
      # them, or something they need, broken. Each entry is temporary: the
      # packages are frozen at nixpkgs of 2026-10-10 (held since 2026-10-31).
      #   azure-cli: needs python fabric, broken with invoke 3 (fabric #2376).
      #   vagrant: needs libguestfs, broken while it is stuck on fuse2.
      holdbackOverlay = final: prev:
        let held = import inputs.nixpkgs-holdback { inherit system; inherit (prev) config; }; in {
          azure-cli = held.azure-cli;
          vagrant = held.vagrant;
        };

      # Host classes — single source of truth (consumed via specialArgs below).
      # Intel hosts get iHD/VAAPI drivers + thermald; RAM-tight build boxes
      # (16-32GB) get the compile throttle. AMD/big hosts (slime, kraken) are in
      # neither. Add a new host to the relevant list(s) here — nowhere else.
      intelHosts = [ "thunder" "bear" "owl" ];
      ramTightHosts = [ "thunder" "owl" ];
      laptopHosts = [ "thunder" "bear" "owl" "kraken" ];
      secureBootHosts = [ "kraken" ];
      snapshotHosts = [ "kraken" "slime" ];
      homeBackupHosts = [ "slime" ];  # kraken: parked
      natsHosts = [ "slime" "kraken" ];

      # Helper function to create a NixOS configuration for a host
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
          isIntel = builtins.elem hostname intelHosts;
          isRamTight = builtins.elem hostname ramTightHosts;
          isLaptop = builtins.elem hostname laptopHosts;
          isSecureBoot = builtins.elem hostname secureBootHosts;
          isSnapshot = builtins.elem hostname snapshotHosts;
          isHomeBackup = builtins.elem hostname homeBackupHosts;
          isNats = builtins.elem hostname natsHosts;
        };
        modules = [
          # Host-specific hardware
          ./hosts/${hostname}/hardware-configuration.nix

          # System modules
          ./modules/system

          # Overlays
          { nixpkgs.overlays = [ dfuProgrammerOverlay natsServerOverlay holdbackOverlay inputs.claude-code-nix.overlays.default ]; }

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
