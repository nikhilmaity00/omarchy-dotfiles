#!/usr/bin/env bash
# ==============================================================================
# Omarchy Reproducible Environment Restoration Engine (install.sh)
# Fully automated, resilient restoration of packages, plugins, configs & daemons.
# ==============================================================================
set -euo pipefail

# Prevent running script directly as root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "ERROR: Do not run this script as root or with sudo." >&2
    echo "Run it as your normal user: ./install.sh" >&2
    echo "Administrative tasks will request sudo privileges when needed." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"
CONFIG_DIR="$SCRIPT_DIR/config"
LOG_FILE="$SCRIPT_DIR/install.log"
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

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

log_info()  { echo -e "[\e[34mINFO\e[0m] $1"; }
log_warn()  { echo -e "[\e[33mWARN\e[0m] $1"; }
log_error() { echo -e "[\e[31mERROR\e[0m] $1"; }
log_step()  { echo -e "\n\e[1;36m==> $1\e[0m"; }

# Request and maintain sudo credentials upfront
if [[ "$DRY_RUN" == false ]]; then
    log_info "Verifying administrator (sudo) privileges..."
    if ! sudo -v; then
        log_error "Failed to authenticate sudo credentials."
        exit 1
    fi
    # Keep sudo timestamp fresh in background while script executes
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true' EXIT
fi

# Set up logging to both terminal and install.log
if [[ "$DRY_RUN" == false ]]; then
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

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

# Synchronize package databases to avoid 404s on rolling packages
if [[ "$DRY_RUN" == false ]]; then
    log_info "Synchronizing pacman package databases..."
    sudo pacman -Sy --noconfirm || log_warn "Failed to synchronize package databases. Continuing with existing cache..."
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
    mapfile -t pkgs < <(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true)
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    log_info "Checking ${#pkgs[@]} official Arch packages from $(basename "$file")..."

    if [[ "$DRY_RUN" == true ]]; then
        echo "    [Dry-run] Would check and install: ${pkgs[*]}"
        return 0
    fi

    # Filter out already-installed packages for fast execution
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_info "All ${#pkgs[@]} official packages are already installed."
        return 0
    fi

    log_info "Installing ${#to_install[@]} uninstalled package(s): ${to_install[*]}"

    # Attempt batch install first for speed
    if sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        log_info "Successfully installed packages in batch mode."
    else
        log_warn "Batch pacman installation encountered an error. Falling back to itemized installation..."
        for pkg in "${to_install[@]}"; do
            if pacman -Q "$pkg" &>/dev/null; then
                continue
            fi
            log_info "Installing: $pkg"
            sudo pacman -S --needed --noconfirm "$pkg" || log_warn "Failed to install pacman package: $pkg"
        done
    fi
}

install_aur_packages() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    local pkgs=()
    mapfile -t pkgs < <(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true)
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    log_info "Checking ${#pkgs[@]} AUR binary packages from $(basename "$file")..."

    if [[ "$DRY_RUN" == true ]]; then
        echo "    [Dry-run] Would check and install AUR packages: ${pkgs[*]}"
        return 0
    fi

    # Filter out already-installed packages
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_info "All ${#pkgs[@]} AUR packages are already installed."
        return 0
    fi

    log_info "Installing ${#to_install[@]} uninstalled AUR package(s): ${to_install[*]}"

    # Attempt batch install first with non-interactive flags
    if yay -S --needed --noconfirm --answerclean None --answerdiff None "${to_install[@]}"; then
        log_info "Successfully installed AUR packages in batch mode."
    else
        log_warn "Batch AUR installation encountered an error. Falling back to itemized installation..."
        for pkg in "${to_install[@]}"; do
            if pacman -Q "$pkg" &>/dev/null; then
                continue
            fi
            log_info "Installing AUR package: $pkg"
            yay -S --needed --noconfirm --answerclean None --answerdiff None "$pkg" || log_warn "Failed to install AUR package: $pkg"
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
install_flatpaks() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0
    ! command -v flatpak &>/dev/null && return 0

    local flatpaks=()
    mapfile -t flatpaks < <(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true)
    [[ ${#flatpaks[@]} -eq 0 ]] && return 0

    log_step "Restoring Flatpak Applications"
    for app in "${flatpaks[@]}"; do
        log_info "Installing Flatpak: $app"
        if [[ "$DRY_RUN" == false ]]; then
            flatpak install -y flathub "$app" || log_warn "Failed to install Flatpak $app"
        fi
    done
}

# ------------------------------------------------------------------------------
# 4. Restore Editor Extensions (VSCodium / VS Code)
# ------------------------------------------------------------------------------
install_editor_extensions() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    local editor_cmd=""
    if command -v codium &> /dev/null; then editor_cmd="codium";
    elif command -v code &> /dev/null; then editor_cmd="code";
    elif command -v vscodium &> /dev/null; then editor_cmd="vscodium"; fi

    [[ -z "$editor_cmd" ]] && return 0

    local extensions=()
    mapfile -t extensions < <(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true)
    [[ ${#extensions[@]} -eq 0 ]] && return 0

    log_step "Restoring Editor Extensions ($editor_cmd)"
    for ext in "${extensions[@]}"; do
        log_info "Installing extension: $ext"
        if [[ "$DRY_RUN" == false ]]; then
            $editor_cmd --install-extension "$ext" --force || log_warn "Failed to install extension $ext"
        fi
    done
}

# ------------------------------------------------------------------------------
# 5. Restore Omarchy Plugins
# ------------------------------------------------------------------------------
install_omarchy_plugins() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0
    ! command -v omarchy &> /dev/null && return 0

    log_step "Restoring Omarchy Shell Plugins"
    while IFS=$'\t' read -r plugin_id git_url || [[ -n "${plugin_id:-}" ]]; do
        [[ -z "${plugin_id:-}" || "$plugin_id" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${git_url:-}" ]] && continue

        if [[ -d "$HOME/.config/omarchy/plugins/$plugin_id" ]]; then
            log_info "Omarchy plugin already installed: $plugin_id"
            continue
        fi

        log_info "Installing Omarchy plugin: $plugin_id ($git_url)"
        if [[ "$DRY_RUN" == false ]]; then
            omarchy plugin add "$git_url" --enable --yes || log_warn "Failed to add plugin $plugin_id"
        fi
    done < "$file"
}

# Execute remaining restorations
install_flatpaks "$MANIFESTS_DIR/flatpak.txt"
install_editor_extensions "$MANIFESTS_DIR/vscodium-extensions.txt"
install_omarchy_plugins "$MANIFESTS_DIR/omarchy-plugins.txt"

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
        DETECTED_MONITOR=$(hyprctl monitors 2>/dev/null | grep "Monitor" | awk '{print $2}' | head -n 1 || true)
    fi

    # 2. Fallback: Check sysfs DRM connector status
    if [[ -z "$DETECTED_MONITOR" ]]; then
        for conn in /sys/class/drm/card*-*/status; do
            if [[ -f "$conn" ]] && grep -q "^connected" "$conn" 2>/dev/null; then
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

        # Reload live environment if Hyprland or Omarchy shell is active
        if command -v hyprctl &>/dev/null && hyprctl monitors &>/dev/null; then
            hyprctl reload &>/dev/null || true
            log_info "Reloaded Hyprland configuration."
        fi
        if command -v omarchy-shell &>/dev/null; then
            omarchy-shell shell rescanPlugins &>/dev/null || true
        fi
    else
        echo "    [Dry-run] Would copy contents of $CONFIG_DIR to $HOME/.config/"
    fi
fi

# Apply Chezmoi dotfiles if present
if command -v chezmoi &> /dev/null && [[ -d "$HOME/.local/share/chezmoi" ]]; then
    log_info "Applying Chezmoi dotfiles..."
    if [[ "$DRY_RUN" == false ]]; then
        chezmoi apply --force || log_warn "Chezmoi apply encountered warnings."
    else
        echo "    [Dry-run] Would apply Chezmoi dotfiles"
    fi
fi

# ------------------------------------------------------------------------------
# 8. Systemd Daemons & User Group Automation
# ------------------------------------------------------------------------------
if [[ "$ENABLE_SYSTEMD" == true ]]; then
    log_step "Configuring Systemd Services and User Groups"
    if [[ "$DRY_RUN" == false ]]; then
        # System daemons
        command -v bluetoothd &>/dev/null && sudo systemctl enable --now bluetooth.service 2>/dev/null || true
        command -v cupsd &>/dev/null      && sudo systemctl enable --now cups.service 2>/dev/null || true
        command -v dockerd &>/dev/null    && sudo systemctl enable --now docker.socket 2>/dev/null || true
        command -v avahi-daemon &>/dev/null && sudo systemctl enable --now avahi-daemon.service 2>/dev/null || true

        # User daemons
        systemctl --user enable --now pipewire.service wireplumber.service 2>/dev/null || true
        if [[ -f "$HOME/.config/systemd/user/omarchy-dotfiles-backup.timer" ]]; then
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable --now omarchy-dotfiles-backup.timer 2>/dev/null || true
            log_info "Enabled automated dotfiles backup timer."
        fi

        # User Groups
        if command -v dockerd &>/dev/null; then
            sudo usermod -aG docker "$TARGET_USER" 2>/dev/null || true
        fi
        sudo usermod -aG video,input "$TARGET_USER" 2>/dev/null || true
        log_info "System services and group permissions updated for user $TARGET_USER."
    else
        echo "    [Dry-run] Would enable bluetooth, cups, docker services, dotfiles backup timer and set user groups for $TARGET_USER"
    fi
fi

# ------------------------------------------------------------------------------
# 9. Shell Environment Verification
# ------------------------------------------------------------------------------
log_step "Verifying Default Shell"
if command -v zsh &> /dev/null && [[ "${SHELL:-}" != *"zsh"* ]]; then
    log_info "Zsh is installed. To switch default shell run: chsh -s \$(which zsh)"
fi

echo "============================================================"
log_info "Restoration Complete! Reboot or log out to finish setup."
echo "============================================================"
