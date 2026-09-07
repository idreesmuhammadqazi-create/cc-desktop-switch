#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/opt/cc-desktop-switch"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"

echo "Uninstalling CC Desktop Switch from $HOME..."

rm -f "$BIN_DIR/cc-desktop-switch"
rm -f "$DESKTOP_DIR/cc-desktop-switch.desktop"
rm -f "$ICON_DIR/cc-desktop-switch.png"
rm -rf "$INSTALL_DIR"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "✓ Uninstallation complete."
