#!/usr/bin/env bash
# ==============================================================================
# Omarchy Automated Backup Engine (export.sh)
# Captures currently installed packages, plugins, extensions, and configs.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"
CONFIG_DIR="$SCRIPT_DIR/config"

mkdir -p "$MANIFESTS_DIR" "$CONFIG_DIR"

echo "============================================================"
echo "  Starting Omarchy Automated Backup / State Export"
echo "============================================================"

# ------------------------------------------------------------------------------
# 1. Environment Verification
# ------------------------------------------------------------------------------
if ! command -v pacman &> /dev/null; then
    echo "ERROR: Pacman not found. This script must be run on Arch/Omarchy Linux." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Export Native Pacman Packages
# ------------------------------------------------------------------------------
echo "==> Exporting official Arch Linux packages..."
# Get all explicitly installed native packages (excluding AUR/foreign)
pacman -Qent > "$MANIFESTS_DIR/pacman-raw.txt" || true
pacman -Qent | awk '{print $1}' > "$MANIFESTS_DIR/pacman-official.txt" || true
echo "    Saved $(wc -l < "$MANIFESTS_DIR/pacman-official.txt") packages to manifests/pacman-official.txt"

# ------------------------------------------------------------------------------
# 3. Export Foreign / AUR Packages
# ------------------------------------------------------------------------------
echo "==> Exporting foreign / AUR packages..."
# Get all explicitly installed foreign packages
pacman -Qemt > "$MANIFESTS_DIR/aur-raw.txt" || true
# Extract package names
pacman -Qemt | awk '{print $1}' > "$MANIFESTS_DIR/aur-all.txt" || true

# Filter binary (-bin) AUR packages into aur-binaries.txt for fast restoration
grep -E '(-bin|-appimage|-git)$' "$MANIFESTS_DIR/aur-all.txt" > "$MANIFESTS_DIR/aur-binaries.txt" || true
# If aur-binaries is empty, use all AUR packages as fallback
if [[ ! -s "$MANIFESTS_DIR/aur-binaries.txt" ]]; then
    cp "$MANIFESTS_DIR/aur-all.txt" "$MANIFESTS_DIR/aur-binaries.txt"
fi
rm -f "$MANIFESTS_DIR/aur-all.txt"
echo "    Saved $(wc -l < "$MANIFESTS_DIR/aur-binaries.txt") AUR binary packages to manifests/aur-binaries.txt"

# ------------------------------------------------------------------------------
# 4. Export Flatpaks
# ------------------------------------------------------------------------------
if command -v flatpak &> /dev/null; then
    echo "==> Exporting Flatpak applications..."
    flatpak list --app --columns=application > "$MANIFESTS_DIR/flatpak-raw.txt" 2>/dev/null || true
    grep -v '^Ref' "$MANIFESTS_DIR/flatpak-raw.txt" | grep -v '^$' > "$MANIFESTS_DIR/flatpak.txt" || true
    echo "    Saved $(wc -l < "$MANIFESTS_DIR/flatpak.txt" 2>/dev/null || echo 0) Flatpaks to manifests/flatpak.txt"
else
    echo "# Add flatpak app IDs here if needed (e.g. com.spotify.Client)" > "$MANIFESTS_DIR/flatpak.txt"
fi

# ------------------------------------------------------------------------------
# 5. Export VSCodium / VS Code Extensions
# ------------------------------------------------------------------------------
EDITOR_CMD=""
if command -v codium &> /dev/null; then EDITOR_CMD="codium";
elif command -v code &> /dev/null; then EDITOR_CMD="code";
elif command -v vscodium &> /dev/null; then EDITOR_CMD="vscodium"; fi

if [[ -n "$EDITOR_CMD" ]]; then
    echo "==> Exporting editor extensions using $EDITOR_CMD..."
    $EDITOR_CMD --list-extensions > "$MANIFESTS_DIR/vscodium-extensions.txt" 2>/dev/null || true
    echo "    Saved $(wc -l < "$MANIFESTS_DIR/vscodium-extensions.txt") extensions to manifests/vscodium-extensions.txt"
fi

# ------------------------------------------------------------------------------
# 6. Export Omarchy Shell Plugins
# ------------------------------------------------------------------------------
echo "==> Exporting Omarchy shell plugins..."
> "$MANIFESTS_DIR/omarchy-plugins.txt"

PLUGINS_DIR="$HOME/.config/omarchy/plugins"
if [[ -d "$PLUGINS_DIR" ]]; then
    for dir in "$PLUGINS_DIR"/*; do
        if [[ -d "$dir/.git" ]]; then
            plugin_id=$(basename "$dir")
            git_url=$(git -C "$dir" config --get remote.origin.url 2>/dev/null || true)
            if [[ -n "$git_url" ]]; then
                printf "%s\t%s\n" "$plugin_id" "$git_url" >> "$MANIFESTS_DIR/omarchy-plugins.txt"
            fi
        fi
    done
fi
echo "    Saved $(wc -l < "$MANIFESTS_DIR/omarchy-plugins.txt") plugins to manifests/omarchy-plugins.txt"

# ------------------------------------------------------------------------------
# 7. Sync Key User Configurations into config/
# ------------------------------------------------------------------------------
echo "==> Syncing custom configurations into config/..."
mkdir -p "$CONFIG_DIR/hypr"

# Copy Hyprland custom keybindings if present
if [[ -f "$HOME/.config/hypr/bindings.lua" ]]; then
    cp -f "$HOME/.config/hypr/bindings.lua" "$CONFIG_DIR/hypr/bindings.lua"
    echo "    Synced ~/.config/hypr/bindings.lua"
fi

# Copy Foot terminal config if present
if [[ -f "$HOME/.config/foot/foot.ini" ]]; then
    mkdir -p "$CONFIG_DIR/foot"
    cp -f "$HOME/.config/foot/foot.ini" "$CONFIG_DIR/foot/foot.ini"
    echo "    Synced ~/.config/foot/foot.ini"
fi

# Copy Starship config if present
if [[ -f "$HOME/.config/starship.toml" ]]; then
    cp -f "$HOME/.config/starship.toml" "$CONFIG_DIR/starship.toml"
    echo "    Synced ~/.config/starship.toml"
fi

# Copy Fastfetch config if present
if [[ -d "$HOME/.config/fastfetch" ]]; then
    mkdir -p "$CONFIG_DIR/fastfetch"
    cp -rf "$HOME/.config/fastfetch/." "$CONFIG_DIR/fastfetch/"
    echo "    Synced ~/.config/fastfetch/"
fi

echo "============================================================"
echo "  Backup / Export Complete!"
echo "============================================================"
