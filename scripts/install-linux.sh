#!/usr/bin/env bash
set -euo pipefail

REPO="${CCDS_REPO:-idreesmuhammadqazi-create/cc-desktop-switch}"
TAG="${CCDS_TAG:-v1.0.26}"
INSTALL_DIR="${HOME}/.local/opt/cc-desktop-switch"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"

ARCH="$(uname -m)"
if [[ "$ARCH" == "x86_64" ]]; then
  PKG_ARCH="x64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  PKG_ARCH="arm64"
else
  PKG_ARCH="$ARCH"
fi

echo "===================================================="
echo " Installing CC Desktop Switch (${PKG_ARCH})"
echo " Source: GitHub Release ${REPO} (${TAG})"
echo "===================================================="

TMP_DIR="$(mktemp -d -t ccds-install-XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

LOCAL_TARBALL=""
if [[ $# -gt 0 && -f "$1" ]]; then
  LOCAL_TARBALL="$1"
  echo "Using provided local package: $LOCAL_TARBALL"
fi

if [[ -z "$LOCAL_TARBALL" ]]; then
  echo "Downloading release assets from GitHub..."
  TARBALL_NAME="CC-Desktop-Switch-${TAG}-linux-${PKG_ARCH}.tar.gz"
  CHECKSUM_NAME="${TARBALL_NAME}.sha256"
  
  if command -v gh >/dev/null 2>&1; then
    echo "Using gh CLI to download release..."
    gh release download "$TAG" --repo "$REPO" --pattern "$TARBALL_NAME" --pattern "$CHECKSUM_NAME" --dir "$TMP_DIR"
  else
    echo "Using curl to download release..."
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${TARBALL_NAME}"
    CHECKSUM_URL="https://github.com/${REPO}/releases/download/${TAG}/${CHECKSUM_NAME}"
    curl -fsSL -o "$TMP_DIR/$TARBALL_NAME" "$DOWNLOAD_URL"
    curl -fsSL -o "$TMP_DIR/$CHECKSUM_NAME" "$CHECKSUM_URL" || true
  fi

  LOCAL_TARBALL="$TMP_DIR/$TARBALL_NAME"
  
  # Verify checksum if present
  if [[ -f "$TMP_DIR/$CHECKSUM_NAME" ]]; then
    echo "Verifying SHA256 checksum..."
    (cd "$TMP_DIR" && sha256sum -c "$CHECKSUM_NAME")
    echo "✓ Checksum verification passed."
  fi
fi

# Prepare target directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"

echo "Extracting package to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"/*
tar -xzf "$LOCAL_TARBALL" -C "$TMP_DIR"

if [[ -d "$TMP_DIR/CC-Desktop-Switch" ]]; then
  cp -r "$TMP_DIR/CC-Desktop-Switch"/* "$INSTALL_DIR/"
else
  cp -r "$TMP_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
fi

APP_EXE="$INSTALL_DIR/CC-Desktop-Switch"
if [[ ! -f "$APP_EXE" ]]; then
  echo "Error: Application executable not found at $APP_EXE" >&2
  exit 1
fi
chmod +x "$APP_EXE"

echo "Creating launcher symlink in $BIN_DIR..."
ln -sf "$APP_EXE" "$BIN_DIR/cc-desktop-switch"

echo "Installing desktop icon..."
if [[ -f "$INSTALL_DIR/app-icon.png" ]]; then
  cp "$INSTALL_DIR/app-icon.png" "$ICON_DIR/cc-desktop-switch.png"
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../frontend/assets/app-icon.png" ]]; then
  cp "$(dirname "${BASH_SOURCE[0]}")/../frontend/assets/app-icon.png" "$ICON_DIR/cc-desktop-switch.png"
fi

echo "Registering FreeDesktop entry..."
cat << DESKTOPEOF > "$DESKTOP_DIR/cc-desktop-switch.desktop"
[Desktop Entry]
Name=CC Desktop Switch
Comment=Switch third-party API providers and models for Claude Desktop
Exec=${BIN_DIR}/cc-desktop-switch %u
Icon=cc-desktop-switch
Terminal=false
Type=Application
Categories=Utility;Development;
StartupNotify=true
Keywords=Claude;AI;LLM;Desktop;Switch;
DESKTOPEOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "===================================================="
echo " ✓ Installation complete!"
echo " Binary:  $BIN_DIR/cc-desktop-switch"
echo " Desktop: $DESKTOP_DIR/cc-desktop-switch.desktop"
echo "===================================================="

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Note: $BIN_DIR is not in your PATH."
  echo "Add the following line to your ~/.bashrc or ~/.profile:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
fi
