{ config, pkgs, lib, ... }:

{
  # Basic system configuration for Raspberry Pi 4
  
  # Disable ZFS to avoid the build error
  # boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.loader.timeout = 1;
  boot.supportedFilesystems = lib.mkForce [ "ext4" "vfat" ];
  boot.kernelParams = [ "boot.shell_on_fail" ];

  # Limit generations to save space
  boot.loader.systemd-boot.configurationLimit = 3;

  # Enable tmpfs for /tmp to save disk space
  boot.tmp.cleanOnBoot = true;
  boot.tmp.useTmpfs = true;

  # Create symbolic links for partition labels to handle different naming schemes
  boot.initrd.postDeviceCommands = lib.mkBefore ''
    # Create symlinks for partition labels to ensure compatibility
    mkdir -p /dev/disk/by-label
    for label in NIXOS_BOOT BOOT boot FIRMWARE; do
      if [ -e /dev/disk/by-label/$label ]; then
        # Create symlinks for all possible names
        for target in NIXOS_BOOT BOOT boot FIRMWARE; do
          if [ "$label" != "$target" ]; then
            ln -sf /dev/disk/by-label/$label /dev/disk/by-label/$target 2>/dev/null || true
          fi
        done
        break
      fi
    done
    
    # Similarly for root partition
    for label in NIXOS_SD nixos nixos-root root; do
      if [ -e /dev/disk/by-label/$label ]; then
        for target in NIXOS_SD nixos nixos-root root; do
          if [ "$label" != "$target" ]; then
            ln -sf /dev/disk/by-label/$label /dev/disk/by-label/$target 2>/dev/null || true
          fi
        done
        break
      fi
    done
  '';

  # Define file systems for the running system
  # The SD card typically uses these labels on a Raspberry Pi with NixOS
  fileSystems = {
    "/" = {
      device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "nodiratime" "discard" ];
    };
    
    "/boot" = {
      # The SD image module uses FIRMWARE as the boot partition label
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      # Continue even if not mountable
      options = [ "defaults" "nofail" ]; 
    };
  };
  
  # Set hostname - using your custom name
  networking.hostName = "rpi4-nixos-ice";

  # Configure common networking settings
  networking = {
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
    htop
    # Add some networking tools for troubleshooting
    inetutils
    iw
    wirelesstools
  ];

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Optimize storage by turning off some history
  nix.settings.auto-optimise-store = true;
  nix.optimise.automatic = true;

  # Set your timezone to Dublin
  time.timeZone = "Europe/Dublin";

  # Audio configuration with pulseaudio as you specified
  services.pulseaudio.enable = true;

  # System settings
  system.stateVersion = "24.11"; # Keep this unchanged
}
