{
  description = "NixOS configuration for Raspberry Pi 4 (Ice)";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };
  
  outputs = { self, nixpkgs, nixos-hardware, ... }:
  let
    # Define systems
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    
    # Function to create system configuration
    nixosSystem = system: modules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules;
      };
      
    # Module to embed configuration files into /etc/nixos
    embedConfigModule = { config, lib, pkgs, ... }: {
      # Enable flakes
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      
      # Use environment.etc to include the files directly in the image
      environment.etc = {
        "nixos/flake.nix" = {
          source = ./flake.nix;
          mode = "0644";
        };
        "nixos/flake.lock" = {
          source = ./flake.lock;
          mode = "0644";
        };
        "nixos/configuration.nix" = {
          source = ./configuration.nix;
          mode = "0644";
        };
      };
    };
  in {
    # NixOS configuration
    nixosConfigurations.rpi4 = nixosSystem "aarch64-linux" [
      nixos-hardware.nixosModules.raspberry-pi-4
      ./configuration.nix
      # Import the SD image module
      "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      # Add the embed config module
      embedConfigModule
    ];

    # Create packages for both architectures
    packages = forAllSystems (system: {
      default =
        if system == "aarch64-linux" then
          self.nixosConfigurations.rpi4.config.system.build.sdImage
        else
          let
            crossPkgs = import nixpkgs {
              inherit system;
              crossSystem = {
                config = "aarch64-unknown-linux-gnu";
                system = "aarch64-linux";
              };
            };
            crossConfig = nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = [
                nixos-hardware.nixosModules.raspberry-pi-4
                ./configuration.nix
                "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
                # Also add the embed config module here
                embedConfigModule
              ];
              pkgs = crossPkgs;
            };
          in
            crossConfig.config.system.build.sdImage;
    });
  };
}
