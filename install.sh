#!/usr/bin/env bash
# ==============================================================================
# Omarchy Reproducible Environment Restoration Engine
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"

echo "============================================================"
echo "  Starting Omarchy Reproducible Restoration"
echo "============================================================"

# 1. Environment Verification
if ! command -v pacman &> /dev/null; then
    echo "ERROR: Pacman not found. This script must be run on Arch/Omarchy Linux." >&2
    exit 1
fi

# 2. Ensure AUR Helper (yay)
if ! command -v yay &> /dev/null; then
    echo "==> Installing yay AUR helper..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# 3. Restore Official Arch Packages (Zero Compile Time)
if [[ -f "$MANIFESTS_DIR/pacman-official.txt" ]]; then
    echo "==> Installing Official Arch packages..."
    grep -v '^#' "$MANIFESTS_DIR/pacman-official.txt" | grep -v '^$' | xargs -r sudo pacman -S --needed --noconfirm
fi

# 4. Restore Pre-compiled AUR Binaries
if [[ -f "$MANIFESTS_DIR/aur-binaries.txt" ]]; then
    echo "==> Installing AUR binaries..."
    grep -v '^#' "$MANIFESTS_DIR/aur-binaries.txt" | grep -v '^$' | xargs -r yay -S --needed --noconfirm
fi

# 5. Restore Flatpaks (if any listed)
if [[ -f "$MANIFESTS_DIR/flatpak.txt" ]] && command -v flatpak &> /dev/null; then
    echo "==> Checking Flatpak applications..."
    grep -v '^#' "$MANIFESTS_DIR/flatpak.txt" | grep -v '^$' | while read -r app; do
        if [ -n "$app" ]; then
            flatpak install -y flathub "$app" || true
        fi
    done
fi

# 6. Hardware Abstraction: Auto-configure Hyprland Monitor Output
echo "==> Configuring laptop display output..."
mkdir -p "$HOME/.config/hypr"
MONITOR_CONF="$HOME/.config/hypr/monitors.conf"

if [[ ! -f "$MONITOR_CONF" ]]; then
    if command -v hyprctl &> /dev/null && hyprctl monitors &> /dev/null; then
        DETECTED_MONITOR=$(hyprctl monitors | grep "Monitor" | awk '{print $2}' | head -n 1)
        if [[ -n "$DETECTED_MONITOR" ]]; then
            echo "monitor=$DETECTED_MONITOR,preferred,auto,1" > "$MONITOR_CONF"
            echo "Auto-detected monitor: $DETECTED_MONITOR -> $MONITOR_CONF"
        else
            echo "monitor=,preferred,auto,1" > "$MONITOR_CONF"
        fi
    else
        echo "monitor=,preferred,auto,1" > "$MONITOR_CONF"
    fi
fi

# 7. Apply Chezmoi Dotfiles (if setup)
if command -v chezmoi &> /dev/null && [[ -d "$HOME/.local/share/chezmoi" ]]; then
    echo "==> Applying Chezmoi dotfiles..."
    chezmoi apply
fi

echo "============================================================"
echo "  Restoration Complete! Reboot or log out to finish setup."
echo "============================================================"
