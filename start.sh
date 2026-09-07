#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "   CC Desktop Switch v1.0.26"
echo "   正在启动管理后台..."
echo "========================================"

# Select Python environment: local .venv, venv, or system python3
if [ -d "$SCRIPT_DIR/.venv" ] && [ -x "$SCRIPT_DIR/.venv/bin/python3" ]; then
    PYTHON="$SCRIPT_DIR/.venv/bin/python3"
elif [ -d "$SCRIPT_DIR/venv" ] && [ -x "$SCRIPT_DIR/venv/bin/python3" ]; then
    PYTHON="$SCRIPT_DIR/venv/bin/python3"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON="python"
else
    echo "[错误] 未检测到 Python，请先安装 Python 3.11+" >&2
    exit 1
fi

exec "$PYTHON" main.py "$@"
