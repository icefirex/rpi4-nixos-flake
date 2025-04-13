{
  description = "NixOS configuration for Raspberry Pi 4 (Ice)";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, nixos-hardware, sops-nix, ... }:
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

    # Base modules for both configurations
    baseModules = [
      nixos-hardware.nixosModules.raspberry-pi-4
      ./base-configuration.nix
      ./base-cleanup.nix
    ];
      
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
        "nixos/base-configuration.nix" = {
          source = ./base-configuration.nix;
          mode = "0644";
        };
        "nixos/sd-image-configuration.nix" = {
          source = ./sd-image-configuration.nix;
          mode = "0644";
        };
        "nixos/sops-configuration.nix" = {
          source = ./sops-configuration.nix;
          mode = "0644";
        };
        "nixos/base-cleanup.nix" = {
          source = ./base-cleanup.nix;
          mode = "0644";
        };
        # Include sops configuration files
        "nixos/.sops.yaml" = lib.mkIf (builtins.pathExists ./.sops.yaml) {
          source = ./.sops.yaml;
          mode = "0644";
        };
        "nixos/secrets.yaml" = lib.mkIf (builtins.pathExists ./secrets.yaml) {
          source = ./secrets.yaml;
          mode = "0600";
        };
        # Include SD image configuration if it exists
        "nixos/sd-image.nix" = lib.mkIf (builtins.pathExists ./sd-image.nix) {
          source = ./sd-image.nix;
          mode = "0644";
        };
      };

      # Set up the age key directory for sops-nix
      systemd.tmpfiles.rules = [
        "d /root/.config/sops/age 0700 root root - -"
      ];

      # Create a hook to copy the age key if it exists on the deploying machine
      system.activationScripts.setupSopsKey = lib.stringAfter [ "users" "groups" ] ''
        if [ -f ~/.config/sops/age/keys.txt ]; then
          echo "Copying age key for sops-nix..."
          mkdir -p /root/.config/sops/age/
          cp -f ~/.config/sops/age/keys.txt /root/.config/sops/age/keys.txt
          chmod 600 /root/.config/sops/age/keys.txt
        fi
      '';
    };
  in {
    # NixOS configuration for the running system
    nixosConfigurations = {
      # Configuration for creating SD image
      rpi4-sdimage = nixosSystem "aarch64-linux" (
        baseModules ++ [
          # SD image module
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          # SD image specific settings
          ./sd-image.nix
          # SD image specific configuration
          ./sd-image-configuration.nix
          # Add the embed config module
          embedConfigModule
          # DO NOT include sops-nix for SD image
        ]
      );
      
      # Configuration for deploying to a running system
      rpi4 = nixosSystem "aarch64-linux" (
        baseModules ++ [
          # Include sops-nix
          sops-nix.nixosModules.sops
          # Include sops configuration
          ./sops-configuration.nix
          # Add the embed config module
          embedConfigModule
        ]
      );
    };

    # Create packages for both architectures
    packages = forAllSystems (system: {
      # SD image builder
      sdImage = 
        if system == "aarch64-linux" then
          self.nixosConfigurations.rpi4-sdimage.config.system.build.sdImage
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
              modules = baseModules ++ [
                "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
                ./sd-image.nix
                ./sd-image-configuration.nix
                embedConfigModule
                # DO NOT include sops-nix for SD image
              ];
              pkgs = crossPkgs;
            };
          in
            crossConfig.config.system.build.sdImage;
            
      # Default is still the SD image for backward compatibility
      default = self.packages.${system}.sdImage;

      # System closure for deploying to an existing system
      toplevel = 
        if system == "aarch64-linux" then
          self.nixosConfigurations.rpi4.config.system.build.toplevel
        else
          let
            crossPkgs = import nixpkgs {
              inherit system;
              crossSystem = {
                config = "aarch64-unknown-linux-gnu";
                system = "aarch64-linux";
              };
            };
            # For cross-compiling, use a simpler configuration without sops
            crossConfig = nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = baseModules ++ [
                # Add a simplified version of the wireless config for building only
                ({ lib, ... }: {
                  networking.wireless = {
                    enable = true;
                    networks."TP-Link_E4FC_5G" = {
                      # Use a dummy password for build only
                      psk = "12345678";
                    };
                    userControlled.enable = true;
                  };
                  
                  # Create a regular user with a placeholder SSH key
                  users.users.nixos = {
                    isNormalUser = true;
                    extraGroups = [ "wheel" "networkmanager" ];
                    openssh.authorizedKeys.keys = [
                      "ssh-ed25519 -your-ssh-key-here-"
                    ];
                  };
                  
                  # Still embed sops files in the result
                  environment.etc = {
                    "nixos/sops-configuration.nix" = {
                      source = ./sops-configuration.nix;
                      mode = "0644";
                    };
                    # Include sops configuration files
                    "nixos/.sops.yaml" = lib.mkIf (builtins.pathExists ./.sops.yaml) {
                      source = ./.sops.yaml;
                      mode = "0644";
                    };
                    "nixos/secrets.yaml" = lib.mkIf (builtins.pathExists ./secrets.yaml) {
                      source = ./secrets.yaml;
                      mode = "0600";
                    };
                  };
                })
                embedConfigModule
              ];
              pkgs = crossPkgs;
            };
          in
            crossConfig.config.system.build.toplevel;

      # Deploy script remains the same
      deploy = 
        if system == "x86_64-linux" then
          let
            pkgs = import nixpkgs { inherit system; };
            toplevel = self.packages.${system}.toplevel;
          in
            pkgs.writeShellScriptBin "deploy-to-rpi" ''
              #!/usr/bin/env bash
              set -e
              
              TARGET_HOST="''${1:-nixos@rpi4-nixos-ice}"
              TOPLEVEL="${toplevel}"
              
              echo "Copying system closure to $TARGET_HOST..."
              nix copy --to ssh://$TARGET_HOST $TOPLEVEL
              
              echo "Activating configuration on $TARGET_HOST..."
              ssh $TARGET_HOST "sudo nix-env -p /nix/var/nix/profiles/system --set $TOPLEVEL && sudo $TOPLEVEL/bin/switch-to-configuration switch"
              
              echo "Deployment complete!"
              
              if [ "''${2:-no}" = "reboot" ]; then
                echo "Rebooting system..."
                ssh $TARGET_HOST "sudo reboot"
              else
                echo "If a reboot is needed, run: ssh $TARGET_HOST 'sudo reboot'"
              fi
            ''
        else null;
    });
  };
}
