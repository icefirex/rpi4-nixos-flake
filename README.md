# NixOS for Raspberry Pi 4

This repository contains a flake-based NixOS configuration for Raspberry Pi 4. It creates a bootable SD card image with SSH and WiFi pre-configured for headless operation.

## Features

- Flake-based configuration
- Headless setup with SSH pre-configured
- WiFi configuration included in the image
- Cross-compilation support for building on x86_64 systems
- Configuration files preserved in the image for immediate `nixos-rebuild` use
- Optimized for Raspberry Pi 4

## Prerequisites

### NixOS

If you're running NixOS, ensure you have flakes enabled in your configuration:

```nix
# In your configuration.nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Apply the change with:

```bash
sudo nixos-rebuild switch
```

### Linux with Nix

Install Nix using Determinate Nix installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

This installer automatically enables flakes and other useful features.

### Windows with WSL

1. Install WSL with a Linux distribution (NixOS recommended, see https://github.com/nix-community/NixOS-WSL)

## Setup Instructions

1. Clone this repository:

```bash
git clone https://github.com/icefirex/rpi4-nixos-flake.git
cd nixos-rpi4
```

2. Customize the configuration for your needs:

   - Edit `configuration.nix` to configure your system
   - Update the WiFi settings in `configuration.nix`:
   
     ```nix
     networking.wireless = {
       enable = true;
       networks = {
         "YourWiFiSSID" = {
           psk = "YourWiFiPassword";
         };
       };
     };
     ```
   
   - Update the SSH key in `configuration.nix`:
   
     ```nix
     users.users.nixos = {
       isNormalUser = true;
       extraGroups = [ "wheel" ];
       openssh.authorizedKeys.keys = [
         "ssh-ed25519 YOUR_SSH_PUBLIC_KEY_HERE"
       ];
     };
     ```

## Building the SD Card Image

### On NixOS (x86_64)

For cross-compilation on NixOS, you might need to add this to your configuration.nix:

```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

And run:

```bash
sudo nixos-rebuild switch
```

Then build the image:

```bash
nix build .#default
```

### On other systems with Nix

```bash
# Standard build command
nix build .#default
```

The build process will create an SD card image file in the `result` directory that can be flashed to your SD card.

## Flashing the SD Card Image

### With Caligula (Recommended)

[Caligula](https://github.com/m-frederickson/caligula) is a simple SD card flashing tool.

```bash
# Install Caligula using Nix
nix-shell -p caligula

# Decompress the image (if it's compressed)
zstd -d result/sd-image/*-linux.img.zst -o nixos-rpi4.img

# Flash the image to SD card
# Replace /dev/sdX with your SD card device (be careful!)
sudo caligula write nixos-rpi4.img /dev/sdX
```

### Alternative Methods

#### With dd (Linux/NixOS/WSL with sudo access)

```bash
# Decompress the image if needed
zstd -d result/sd-image/*-linux.img.zst -o nixos-rpi4.img

# Flash to SD card (replace /dev/sdX with your SD card device - be careful!)
sudo dd if=nixos-rpi4.img of=/dev/sdX bs=4M status=progress conv=fsync
```

#### With balenaEtcher (Cross-platform)

1. Download [balenaEtcher](https://www.balena.io/etcher/)
2. If the image is compressed, extract it: `zstd -d result/sd-image/*-linux.img.zst`
3. Launch balenaEtcher and follow the UI to select the image and flash to your SD card

## First Boot and Access

1. Insert the SD card into your Raspberry Pi 4
2. Connect power to the Raspberry Pi
3. Wait for it to boot and connect to your WiFi network
4. Connect via SSH:

```bash
ssh nixos@rpi4-nixos-ice.local
# or
ssh nixos@<IP_ADDRESS>
```

Since we configured the system with passwordless sudo for the nixos user (through SSH key authentication), you can immediately run:

```bash
# Check your configuration if it exists
ls -la /etc/nixos/

# If the config files are present, you can update your system with:
sudo nixos-rebuild switch --flake /etc/nixos#rpi4
```

## Customizing After Deployment

Since the configuration files are set up in `/etc/nixos/` on the Raspberry Pi, you can:

1. Edit the configuration directly on the Pi:

```bash
sudo nano /etc/nixos/configuration.nix
```

2. Apply changes:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#rpi4
```

3. Optionally, set up version control for your configuration:

```bash
cd /etc/nixos
sudo git init
sudo git add .
sudo git config --global user.email "your.email@example.com"
sudo git config --global user.name "Your Name"
sudo git commit -m "Initial configuration"
```

## Troubleshooting

### Cross-Compilation Issues

If you encounter errors related to cross-compilation:

```bash
# For NixOS users, add this to configuration.nix:
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
sudo nixos-rebuild switch

# Then try building again
nix build .#default
```

### SSH Connection Issues

If you cannot connect via SSH:

1. Ensure your Raspberry Pi is connected to the network
2. Try to find its IP address from your router's admin page
3. Verify that you're using the correct SSH key
4. Make sure your local machine trusts the Raspberry Pi's host key

### Configuration Issues

If you encounter configuration problems after boot:

1. Connect a monitor and keyboard to your Raspberry Pi for direct access
2. Log in with the `nixos` user
3. Examine the system logs: `journalctl -xb`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [NixOS](https://nixos.org/) for the operating system
- [NixOS Hardware](https://github.com/NixOS/nixos-hardware) for Raspberry Pi support
- [The Nix community](https://discourse.nixos.org/) for their documentation and support
