{
  # the source of your packages
  inputs = {
    # normal nix stuff
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    # home-manager stuff
    home-manager.url = "github:nix-community/home-manager/master";
#    home-manager.url = "github:nix-community/home-manager/release-23.05";

    # use the version of nixpkgs we specified above rather than the one HM would ordinarily use
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  # what will be produced (i.e. the build)
  outputs = inputs@{self, nixpkgs, ...}: {
    nixosConfigurations."owl" = inputs.nixpkgs.lib.nixosSystem {
      # system to build for
      system = "x86_64-linux";
      # modules to use
      modules = [
        ./configuration.nix # our previous config file
        inputs.home-manager.nixosModules.home-manager # make home manager available to configuration.nix
        {
          # use system-level nixpkgs rather than the HM private ones
          # "This saves an extra Nixpkgs evaluation, adds consistency, and removes the dependency on NIX_PATH, which is otherwise used for importing Nixpkgs."
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.ira = ./home.nix;
        }
      ];
    };
    nixosConfigurations."storm" = inputs.nixpkgs.lib.nixosSystem {
      # system to build for
      system = "x86_64-linux";
      # modules to use
      modules = [
        ./configuration.nix # our previous config file
        inputs.home-manager.nixosModules.home-manager # make home manager available to configuration.nix
        {
          # use system-level nixpkgs rather than the HM private ones
          # "This saves an extra Nixpkgs evaluation, adds consistency, and removes the dependency on NIX_PATH, which is otherwise used for importing Nixpkgs."
          home-manager.useGlobalPkgs = true;
        }
      ];
    };
    # define a "nixos" build
  };
}
