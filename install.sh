#!/usr/bin/env bash
# ==============================================================================
# Omarchy Reproducible Environment Restoration Engine (install.sh)
# Fully automated, resilient restoration of packages, plugins, configs & daemons.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"
CONFIG_DIR="$SCRIPT_DIR/config"
LOG_FILE="$SCRIPT_DIR/install.log"

DRY_RUN=false
ENABLE_SYSTEMD=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-systemd)
            ENABLE_SYSTEMD=false
            shift
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run     Preview restoration steps without performing actions."
            echo "  --no-systemd  Skip enabling systemd services and group additions."
            echo "  -h, --help    Show this help message."
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Logging setup
exec 3>&1 4>&2
if [[ "$DRY_RUN" == false ]]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_info()  { echo -e "[\e[34mINFO\e[0m] $1"; }
log_warn()  { echo -e "[\e[33mWARN\e[0m] $1"; }
log_error() { echo -e "[\e[31mERROR\e[0m] $1"; }
log_step()  { echo -e "\n\e[1;36m==> $1\e[0m"; }

echo "============================================================"
echo "  Omarchy Reproducible Restoration Engine"
echo "  Started at: $(date)"
if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY RUN MODE ENABLED - No changes will be applied]"
fi
echo "============================================================"

# ------------------------------------------------------------------------------
# 1. Environment & Package Manager Verification
# ------------------------------------------------------------------------------
log_step "Verifying Environment"
if ! command -v pacman &> /dev/null; then
    log_error "Pacman not found. This script must be run on Arch/Omarchy Linux."
    exit 1
fi

# Ensure AUR Helper (yay)
if ! command -v yay &> /dev/null; then
    log_info "Installing yay AUR helper..."
    if [[ "$DRY_RUN" == false ]]; then
        sudo pacman -S --needed --noconfirm base-devel git
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    fi
else
    log_info "AUR helper (yay) verified."
fi

# ------------------------------------------------------------------------------
# 2. Resilient Package Installation Helper Functions
# ------------------------------------------------------------------------------
install_pacman_packages() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    local pkgs=()
    mapfile -t pkgs < <(grep -v '^#' "$file" | grep -v '^$')
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    log_info "Restoring ${#pkgs[@]} official Arch packages..."
    if [[ "$DRY_RUN" == true ]]; then
        echo "    [Dry-run] Would install: ${pkgs[*]}"
        return 0
    fi

    # Attempt batch install first for speed
    if sudo pacman -S --needed --noconfirm "${pkgs[@]}" &>/dev/null; then
        log_info "Successfully installed official packages in batch mode."
    else
        log_warn "Batch pacman installation encountered an error. Falling back to itemized installation..."
        for pkg in "${pkgs[@]}"; do
            sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null || log_warn "Failed to install pacman package: $pkg"
        done
    fi
}

install_aur_packages() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    local pkgs=()
    mapfile -t pkgs < <(grep -v '^#' "$file" | grep -v '^$')
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    log_info "Restoring ${#pkgs[@]} AUR binary packages..."
    if [[ "$DRY_RUN" == true ]]; then
        echo "    [Dry-run] Would install AUR packages: ${pkgs[*]}"
        return 0
    fi

    # Attempt batch install first
    if yay -S --needed --noconfirm "${pkgs[@]}" &>/dev/null; then
        log_info "Successfully installed AUR packages in batch mode."
    else
        log_warn "Batch AUR installation encountered an error. Falling back to itemized installation..."
        for pkg in "${pkgs[@]}"; do
            yay -S --needed --noconfirm "$pkg" &>/dev/null || log_warn "Failed to install AUR package: $pkg"
        done
    fi
}

# Execute Package Restoration
log_step "Restoring Official Arch Packages"
install_pacman_packages "$MANIFESTS_DIR/pacman-official.txt"

log_step "Restoring AUR Packages"
install_aur_packages "$MANIFESTS_DIR/aur-binaries.txt"

# ------------------------------------------------------------------------------
# 3. Restore Flatpak Applications
# ------------------------------------------------------------------------------
if [[ -f "$MANIFESTS_DIR/flatpak.txt" ]] && command -v flatpak &> /dev/null; then
    log_step "Restoring Flatpak Applications"
    grep -v '^#' "$MANIFESTS_DIR/flatpak.txt" | grep -v '^$' | while read -r app; do
        if [[ -n "$app" ]]; then
            log_info "Installing Flatpak: $app"
            if [[ "$DRY_RUN" == false ]]; then
                flatpak install -y flathub "$app" || log_warn "Failed to install Flatpak $app"
            fi
        fi
    done
fi

# ------------------------------------------------------------------------------
# 4. Restore Editor Extensions (VSCodium / VS Code)
# ------------------------------------------------------------------------------
if [[ -f "$MANIFESTS_DIR/vscodium-extensions.txt" ]]; then
    EDITOR_CMD=""
    if command -v codium &> /dev/null; then EDITOR_CMD="codium";
    elif command -v code &> /dev/null; then EDITOR_CMD="code";
    elif command -v vscodium &> /dev/null; then EDITOR_CMD="vscodium"; fi

    if [[ -n "$EDITOR_CMD" ]]; then
        log_step "Restoring Editor Extensions ($EDITOR_CMD)"
        grep -v '^#' "$MANIFESTS_DIR/vscodium-extensions.txt" | grep -v '^$' | while read -r ext; do
            if [[ -n "$ext" ]]; then
                log_info "Installing extension: $ext"
                if [[ "$DRY_RUN" == false ]]; then
                    $EDITOR_CMD --install-extension "$ext" --force || log_warn "Failed to install extension $ext"
                fi
            fi
        done
    fi
fi

# ------------------------------------------------------------------------------
# 5. Restore Omarchy Plugins
# ------------------------------------------------------------------------------
if [[ -f "$MANIFESTS_DIR/omarchy-plugins.txt" ]] && command -v omarchy &> /dev/null; then
    log_step "Restoring Omarchy Shell Plugins"
    while IFS=$'\t' read -r plugin_id git_url; do
        if [[ -n "$git_url" && "$git_url" != "#"* ]]; then
            log_info "Installing Omarchy plugin: $plugin_id ($git_url)"
            if [[ "$DRY_RUN" == false ]]; then
                omarchy plugin add "$git_url" --enable --yes || log_warn "Failed to add plugin $plugin_id"
            fi
        fi
    done < "$MANIFESTS_DIR/omarchy-plugins.txt"
fi

# ------------------------------------------------------------------------------
# 6. Hardware Abstraction: Auto-configure Display Outputs
# ------------------------------------------------------------------------------
log_step "Configuring Display Output (monitors.conf)"
MONITOR_CONF="$HOME/.config/hypr/monitors.conf"

if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$HOME/.config/hypr"
    DETECTED_MONITOR=""

    # 1. Try hyprctl if Hyprland active
    if command -v hyprctl &> /dev/null && hyprctl monitors &> /dev/null; then
        DETECTED_MONITOR=$(hyprctl monitors | grep "Monitor" | awk '{print $2}' | head -n 1)
    fi

    # 2. Fallback: Check sysfs DRM connector status
    if [[ -z "$DETECTED_MONITOR" ]]; then
        for conn in /sys/class/drm/card*-*/status; do
            if [[ -f "$conn" ]] && grep -q "^connected" "$conn"; then
                DETECTED_MONITOR=$(echo "$conn" | cut -d/ -f5 | sed 's/card[0-9]*-//')
                break
            fi
        done
    fi

    if [[ -n "$DETECTED_MONITOR" ]]; then
        echo "monitor=$DETECTED_MONITOR,preferred,auto,1" > "$MONITOR_CONF"
        log_info "Configured monitor output: $DETECTED_MONITOR -> $MONITOR_CONF"
    else
        echo "monitor=,preferred,auto,1" > "$MONITOR_CONF"
        log_info "Fallback monitor output configured -> $MONITOR_CONF"
    fi
else
    echo "    [Dry-run] Would detect display connector and update $MONITOR_CONF"
fi

# ------------------------------------------------------------------------------
# 7. Deploy Custom Configuration Files
# ------------------------------------------------------------------------------
log_step "Deploying User Configurations"
if [[ -d "$CONFIG_DIR" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$HOME/.config"
        cp -rf "$CONFIG_DIR/." "$HOME/.config/"
        log_info "Deployed configs from $CONFIG_DIR to $HOME/.config/"
    else
        echo "    [Dry-run] Would copy contents of $CONFIG_DIR to $HOME/.config/"
    fi
fi

# Apply Chezmoi dotfiles if present
if command -v chezmoi &> /dev/null && [[ -d "$HOME/.local/share/chezmoi" ]]; then
    log_info "Applying Chezmoi dotfiles..."
    if [[ "$DRY_RUN" == false ]]; then
        chezmoi apply
    fi
fi

# ------------------------------------------------------------------------------
# 8. Systemd Daemons & User Group Automation
# ------------------------------------------------------------------------------
if [[ "$ENABLE_SYSTEMD" == true ]]; then
    log_step "Configuring Systemd Services and User Groups"
    if [[ "$DRY_RUN" == false ]]; then
        # System daemons
        command -v bluetoothd &>/dev/null && sudo systemctl enable --now bluetooth.service || true
        command -v cupsd &>/dev/null      && sudo systemctl enable --now cups.service || true
        command -v dockerd &>/dev/null    && sudo systemctl enable --now docker.socket || true
        command -v avahi-daemon &>/dev/null && sudo systemctl enable --now avahi-daemon.service || true

        # User daemons
        systemctl --user enable --now pipewire.service wireplumber.service || true

        # User Groups
        command -v dockerd &>/dev/null && sudo usermod -aG docker "$USER" 2>/dev/null || true
        sudo usermod -aG video,input "$USER" 2>/dev/null || true
        log_info "System services and group permissions updated."
    else
        echo "    [Dry-run] Would enable bluetooth, cups, docker services and set user groups"
    fi
fi

# ------------------------------------------------------------------------------
# 9. Shell Environment Verification
# ------------------------------------------------------------------------------
log_step "Verifying Default Shell"
if command -v zsh &> /dev/null && [[ "$SHELL" != *"zsh"* ]]; then
    log_info "Zsh is installed. To switch default shell run: chsh -s \$(which zsh)"
fi

echo "============================================================"
log_info "Restoration Complete! Reboot or log out to finish setup."
echo "============================================================"
