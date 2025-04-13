{ config, pkgs, lib, ... }:

{
  # Enable wireless with a temporary password for initial boot
  networking.wireless = {
    enable = true;
    networks = {
      "TP-Link_E4FC_5G" = {
        # Must be at least 8 characters to satisfy WPA requirements
        psk = "-your-wifi-password-here-";
      };
    };
    userControlled.enable = true;
  };

  # Create a regular user with your SSH key
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 -your-ssh-key-here-"
    ];
  };
}
