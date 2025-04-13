{ config, lib, pkgs, ... }:

{
  # Automatic garbage collection with mkForce to override other definitions
  nix.gc = {
    automatic = lib.mkForce true;
    dates = lib.mkForce "weekly";
    options = lib.mkForce "--delete-older-than 14d";
  };

  # Limit generations to save space
  boot.loader.generic-extlinux-compatible.configurationLimit = lib.mkDefault 2;

  # Enable tmpfs for /tmp to save disk space
  boot.tmp.cleanOnBoot = lib.mkDefault true;
  boot.tmp.useTmpfs = lib.mkDefault true;

  # Optimize storage
  nix.settings.auto-optimise-store = lib.mkDefault true;
  nix.optimise.automatic = lib.mkDefault true;
  
  # Ensure we don't run out of space as easily
  boot.postBootCommands = lib.mkAfter ''
    # Clean up any failed boot attempts
    if [ -d /boot/nixos ]; then
      find /boot/nixos -name "*.tmp.*" -delete || true
    fi
  '';
}
