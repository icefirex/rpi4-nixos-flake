{ config, lib, pkgs, ... }:

{
  # SD image specific configuration
  sdImage = {
    # Enable expansion of the root partition on first boot
    expandOnBoot = true;
    
    # This is the only option we need to change - increase the firmware partition size
    # The default is around 30-40MB which is too small for NixOS
    firmwareSize = 512; # MB
  };
  
  # Keep only 2 generations to save space
  boot.loader.generic-extlinux-compatible.configurationLimit = 2;
}
