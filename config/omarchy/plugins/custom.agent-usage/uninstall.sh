#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$HOME/.config/omarchy/plugins/custom.agent-usage"

echo "Uninstalling Agent Multi-Usage Plugin..."

if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin disable custom.agent-usage || true
fi

rm -rf "$PLUGIN_DIR"
echo "Uninstalled successfully."
