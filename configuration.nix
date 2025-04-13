{ config, pkgs, lib, ... }:

let
  # Check if we're running on actual hardware (not building an image)
  isActualHardware = builtins.pathExists "/run/secrets";
in
{
  # Basic system configuration for Raspberry Pi 4
  
  # Disable ZFS to avoid the build error
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # Define file systems for the running system
  # The SD card typically uses these labels on a Raspberry Pi with NixOS
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS_BOOT";
      fsType = "vfat";
    };
  };
  
  # Set hostname - using your custom name
  networking.hostName = "rpi4-nixos-ice";

  # Configure sops-nix (only apply when not building an image)
  sops = lib.mkIf (!config.sdImage.enable or false) {
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
  
  # Configure WiFi with your network details
  networking = {
    wireless = {
      enable = true;
      # Use imported networks from secrets file
      # Set up networks conditionally
      networks = lib.mkMerge [
        # When building image or initially (no decrypted secrets):
        (lib.mkIf ((config.sdImage.enable or false) || !isActualHardware) {
          "TP-Link_E4FC_5G" = {
            # Plaintext for initial boot only - will be replaced after first deployment
            psk = "-snip-";
          };
        })
        
        # When running with sops available (after first deployment):
        (lib.mkIf (!config.sdImage.enable or false && isActualHardware) {
          "TP-Link_E4FC_5G" = {
            pskFile = config.sops.secrets.wifi_TP-Link_E4FC_5G.path;
          };
        })
      ];
      userControlled.enable = true;
    };
    
    # Ensure firewall doesn't block SSH
    firewall = {
      allowedTCPPorts = [ 22 ];
    };
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
    # This option ensures SSH starts early in the boot process
    startWhenNeeded = false;
    # Make sure sshd doesn't restart during config activation
    # which can disconnect you during deployment
    # stopIfChanged = false; # todo check validity
  };

  # Create a regular user with your SSH key
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    # Use a conditional for the SSH key too
    openssh.authorizedKeys = {
      # Fallback for initial setup
      keys = lib.mkIf ((config.sdImage.enable or false) || !isActualHardware) [
        "ssh-ed25519 -snip-"
      ];
      
      # Use the secret path when available
      keyFiles = lib.mkIf (!config.sdImage.enable or false && isActualHardware) [
        config.sops.secrets.ssh_authorized_key.path
      ];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  # Enable experimental Nix flakes
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Allow unsigned packages - needed for cross-deployment
    require-sigs = false;
    trusted-users = [ "root" "nixos" ];
  };

  # Basic bootloader configuration
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Use latest kernel packages as in your configuration
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Enable firmware for Raspberry Pi
  hardware.enableRedistributableFirmware = true;
  
  # Basic system packages including your additions
  environment.systemPackages = with pkgs; [
    vim
    git
    btop
    # Add some networking tools for troubleshooting
    inetutils
    iw
    wirelesstools
    # Add sops for managing secrets on the device
    sops
    age
  ];

  # Set your timezone to Dublin
  time.timeZone = "Europe/Dublin";

  # Audio configuration with pulseaudio as you specified
  services.pulseaudio.enable = true;

  # System settings
  system.stateVersion = "24.11"; # Keep this unchanged
}
