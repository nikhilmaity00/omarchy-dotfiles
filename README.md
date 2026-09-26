# Omarchy Portable Dotfiles & Automated Restoration Engine

This repository provides a portable, zero-compilation backup and restoration workflow for **Omarchy** (Arch Linux + Hyprland).

It automates capturing system state (packages, AUR binaries, flatpaks, editor extensions, shell plugins, user configs) and restoring them seamlessly on new machine installs in under 3 minutes.

---

## 🚀 Quick Start

### 1. Backing Up Your Current Setup (`export.sh`)
Whenever you install new packages, extensions, or Omarchy plugins on your primary system, update your manifests and configurations with a single command:

```bash
./export.sh
git add .
git commit -m "Update system state and manifests"
git push
```

**What `export.sh` captures:**
- **Arch Official Packages:** Explicitly installed native binary packages (`manifests/pacman-official.txt`).
- **AUR Binaries:** Pre-compiled AUR packages (`manifests/aur-binaries.txt`).
- **Flatpak Applications:** Installed Flatpaks (`manifests/flatpak.txt`).
- **Editor Extensions:** Extensions for VSCodium / VS Code (`manifests/vscodium-extensions.txt`).
- **Omarchy Plugins:** Git repositories of active third-party shell plugins & bar widgets (`manifests/omarchy-plugins.txt`).
- **User Configurations:** Key configuration files into `config/` (Hyprland keybindings, Foot terminal, Starship prompt, Fastfetch).

---

### 2. Restoring on a New Install (`install.sh`)

On your new Arch/Omarchy system:

```bash
git clone https://github.com/nikhilmaity00/omarchy-dotfiles.git ~/.local/share/omarchy-dotfiles
cd ~/.local/share/omarchy-dotfiles
chmod +x install.sh export.sh
./install.sh
```

#### Command Options
- **Preview without applying changes (Dry Run):**
  ```bash
  ./install.sh --dry-run
  ```
- **Skip systemd daemons & group configuration:**
  ```bash
  ./install.sh --no-systemd
  ```

---

## 🛠️ Restoration Features

- **Zero-Compile Fast Package Installation:** Restores official packages and AUR binaries using `--needed --noconfirm`. Includes itemized fallback if a specific package name changes.
- **Hardware Abstraction:** Auto-detects connected laptop display outputs (via `hyprctl` or `/sys/class/drm/`) and generates `~/.config/hypr/monitors.conf`.
- **Omarchy Plugin Restoration:** Automatically clones and enables all git-managed Omarchy shell plugins and widgets.
- **Systemd & Permissions Automation:** Enables essential daemons (`bluetooth`, `cups`, `docker`, `avahi`, `pipewire`) and adds your user to required system groups (`docker`, `video`, `input`).
- **Chezmoi Integration:** Applies Chezmoi dotfiles if initialized on the machine.
- **Execution Logging:** Records restoration steps and warnings to `install.log`.

---

## 📁 Repository Structure

```
├── install.sh                  # Main environment restoration engine
├── export.sh                   # System state export & backup script
├── README.md                   # Documentation
├── install.log                 # Generated execution log
├── config/                     # User configuration overrides (hypr, foot, starship, fastfetch)
└── manifests/
    ├── pacman-official.txt     # Official Arch binary packages
    ├── aur-binaries.txt        # Pre-compiled AUR binary packages
    ├── flatpak.txt             # Flatpak application IDs
    ├── vscodium-extensions.txt # VS Code / VSCodium extensions
    └── omarchy-plugins.txt     # Omarchy third-party shell plugins & URLs
```
