# Omarchy Portable Dotfiles & Environment Setup

This repository contains a portable, zero-compilation restoration configuration for Omarchy (Arch Linux + Hyprland).

## Features
- **Zero-Compile App Restoration**: Uses pre-compiled binaries (`-bin` AUR packages & Pacman official packages) to restore the environment in under 3 minutes.
- **Hardware Abstraction**: Dynamic monitor detection for laptop setups (`~/.config/hypr/monitors.conf`).
- **Clean Omarchy Separation**: Preserves Omarchy's core upstream configs while layering user overrides on top via Chezmoi.

## Restoring on a New Laptop

1. Install base **Omarchy ISO** on the target machine.
2. Clone this repository and run `install.sh`:

```bash
git clone https://github.com/nikhilmaity00/omarchy-dotfiles.git ~/.local/share/omarchy-dotfiles
cd ~/.local/share/omarchy-dotfiles
chmod +x install.sh
./install.sh
```

## Package Manifests
- `manifests/pacman-official.txt` - Official Arch binary packages.
- `manifests/aur-binaries.txt` - Pre-compiled AUR binary packages.
- `manifests/flatpak.txt` - Flatpak applications.
