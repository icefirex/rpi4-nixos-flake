{ config, pkgs, lib, ... }:

let
  # Check if we're running on actual hardware (not building an image)
  isActualHardware = builtins.pathExists "/run/secrets";
in
{
  # Configure sops-nix
  sops = {
    # Use age as the default encryption method
    age.keyFile = "/root/.config/sops/age/keys.txt";
    
    # Default path to look for secrets
    defaultSopsFile = ./secrets.yaml;
    
    # Define secrets to be made available in the system
    secrets = {
      wifi_TP-Link_E4FC_5G = {};
      # If you add more WiFi networks to secrets.yaml, add them here too
      # wifi_Another_Network = {};
      
      # Optional: SSH key secret if you want to manage it this way
      ssh_authorized_key = {};
    };
  };
  
  # Configure WiFi with your network details - modified approach
  networking.wireless = {
    enable = true;
    networks = lib.mkIf isActualHardware {
      "TP-Link_E4FC_5G" = {
        # Use psk directly during build, but it will be replaced at runtime
        # This is just to satisfy the build system
        psk = "12345678";
      };
    };
    userControlled.enable = true;
  };

  # Add a systemd service to set up WiFi properly after boot
  systemd.services.setup-wifi = lib.mkIf isActualHardware {
    description = "Set up WiFi with secrets";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "setup-wifi" ''
        #!/bin/sh
        # Get the password from the sops secret
        if [ -f "${config.sops.secrets.wifi_TP-Link_E4FC_5G.path}" ]; then
          PASSWORD=$(cat ${config.sops.secrets.wifi_TP-Link_E4FC_5G.path})
          # Configure wpa_supplicant directly
          wpa_cli set_network 0 psk "\"$PASSWORD\""
          wpa_cli enable_network 0
          wpa_cli save_config
        fi
      '';
    };
  };

  # Create a regular user with your SSH key from sops
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keyFiles = lib.mkIf isActualHardware [
      config.sops.secrets.ssh_authorized_key.path
    ];
  };

  # Add sops-related packages
  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
