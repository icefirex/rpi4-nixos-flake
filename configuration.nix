{ config, pkgs, lib, ... }:

{
  # Basic system configuration for Raspberry Pi 4
  
  # Disable ZFS to avoid the build error
  boot.supportedFilesystems.zfs = lib.mkForce false;
  
  # Set hostname - using your custom name
  networking.hostName = "rpi4-nixos-ice";
  
  # Configure WiFi with your network details
  networking.wireless = {
    enable = true;
    networks = {
      "TP-Link_E4FC_5G" = {
        psk = "your-wifi-password";
      };
    };
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Create a regular user with your SSH key
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "-your-ssh-key-here"
    ];
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
  
  # Expand the root partition to fill the SD card
  sdImage.expandOnBoot = true;
  
  # Basic system packages including your additions
  environment.systemPackages = with pkgs; [
    vim
    git
    btop
  ];

  # Set your timezone to Dublin
  time.timeZone = "Europe/Dublin";

  # Audio configuration with pulseaudio as you specified
  services.pulseaudio.enable = true;

  # System settings
  system.stateVersion = "24.11"; # Keep this unchanged
}
