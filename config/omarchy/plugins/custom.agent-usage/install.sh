#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$HOME/.config/omarchy/plugins/custom.agent-usage"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Agent Multi-Usage Plugin..."
mkdir -p "$HOME/.config/omarchy/plugins"

# Remove existing directory if present
rm -rf "$PLUGIN_DIR"

# Copy source directory to avoid symlink restrictions in Omarchy plugin validator
cp -r "$SRC_DIR" "$PLUGIN_DIR"

echo "Plugin installed at $PLUGIN_DIR"

# Validate and enable plugin
if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "$PLUGIN_DIR"
    echo "Enabling plugin custom.agent-usage..."
    omarchy plugin enable custom.agent-usage || true
    echo "Installation complete! The top bar will now show icons and percentages for all active in-use agents."
fi
