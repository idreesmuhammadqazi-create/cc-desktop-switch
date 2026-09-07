#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -d "$ROOT/.venv" ] && [ -x "$ROOT/.venv/bin/python3" ]; then
    PYTHON_BIN="${PYTHON_BIN:-$ROOT/.venv/bin/python3}"
else
    PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

detect_version() {
  "$PYTHON_BIN" - "$ROOT/main.py" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r'^APP_VERSION\s*=\s*["\']([^"\']+)["\']', text, re.MULTILINE)
if not match:
    raise SystemExit("APP_VERSION not found in main.py")
print(match.group(1))
PY
}

VERSION="${CCDS_VERSION:-$(detect_version)}"
ARCH="$(uname -m)"
if [[ "$ARCH" == "x86_64" ]]; then
  RELEASE_ARCH="x64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  RELEASE_ARCH="arm64"
else
  RELEASE_ARCH="$ARCH"
fi

LINUX_DIST="$ROOT/dist/linux"
APP_DIR="$LINUX_DIST/CC-Desktop-Switch"
TARBALL="$LINUX_DIST/CC-Desktop-Switch-v${VERSION}-linux-${RELEASE_ARCH}.tar.gz"

echo "========================================"
echo " Building CC Desktop Switch v${VERSION} (${RELEASE_ARCH})"
echo "========================================"

mkdir -p "$LINUX_DIST"
rm -rf "$APP_DIR" "$TARBALL"

echo "Running PyInstaller..."
"$PYTHON_BIN" -m PyInstaller --noconfirm --clean --distpath "$LINUX_DIST" "$ROOT/build.spec"

if [[ ! -d "$APP_DIR" && ! -f "$LINUX_DIST/CC-Desktop-Switch" ]]; then
  echo "Build output not found in $LINUX_DIST" >&2
  exit 1
fi

echo "Packaging portable tarball..."
if [[ -d "$APP_DIR" ]]; then
  cp "$ROOT/frontend/assets/app-icon.png" "$APP_DIR/" 2>/dev/null || true
  cp "$ROOT/cc-desktop-switch.desktop" "$APP_DIR/" 2>/dev/null || true
  tar -czf "$TARBALL" -C "$LINUX_DIST" "CC-Desktop-Switch"
fi

echo "========================================"
echo " Build successful!"
echo " Dist folder: $LINUX_DIST"
if [[ -f "$TARBALL" ]]; then
  echo " Package:     $TARBALL"
fi
echo "========================================"
