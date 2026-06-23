#!/usr/bin/env bash
# Build the wcocr Python extension (wcocr.cpython-312-x86_64-linux-gnu.so)
# from source: https://github.com/swigger/wechat-ocr
#
# The extension wraps WeChat's MMMojo IPC to drive the `wxocr` binary.
# Re-run anytime you want to rebuild against the latest upstream source.
#
# Requirements: cmake>=3.20, g++ (C++20), make, git, and Python 3.12
# (with dev headers). `uv python install 3.12` provides a full dev dist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/build-wcocr"
SRC_DIR="${WORK_DIR}/wechat-ocr"
BUILD_DIR="${WORK_DIR}/cmake"
OUT_NAME="wcocr.cpython-312-x86_64-linux-gnu.so"

log() { printf '\033[1;34m>>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. toolchain checks ---
for cmd in cmake g++ make git; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
done

# --- 2. locate a Python 3.12 with development headers ---
PY312=""
if command -v uv >/dev/null 2>&1; then
    # uv ships a full cpython (headers + libpython), ideal for building ext modules
    PY312="$(uv python find 3.12 2>/dev/null || true)"
fi
[ -n "$PY312" ] || PY312="$(command -v python3.12 2>/dev/null || true)"
[ -n "$PY312" ] || die "Python 3.12 not found. Install it with: uv python install 3.12"

PY_ROOT="$(dirname "$(dirname "$PY312")")"
# sanity: dev headers must exist
[ -f "${PY_ROOT}/include/python3.12/Python.h" ] || die "Python.h not found under $PY_ROOT (need python3.12 dev headers)"
log "python: $PY312 (root=$PY_ROOT, $("$PY312" --version 2>&1))"

# --- 3. fetch / update upstream source ---
if [ -d "$SRC_DIR/.git" ]; then
    log "updating existing wechat-ocr checkout..."
    git -C "$SRC_DIR" fetch --quiet origin
    git -C "$SRC_DIR" reset --hard @{u} >/dev/null
else
    log "cloning wechat-ocr..."
    rm -rf "$SRC_DIR"
    git clone --depth 1 https://github.com/swigger/wechat-ocr.git "$SRC_DIR"
fi
log "source revision: $(git -C "$SRC_DIR" log -1 --format='%h %s (%ci)')"

# --- 4. configure (protobuf is pulled automatically via FetchContent) ---
log "configuring cmake..."
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPython_ROOT_DIR="$PY_ROOT" \
    -DPython_EXECUTABLE="$PY312" \
    -DPython_FIND_VIRTUALENV=FIRST \
    >/dev/null

# --- 5. build only the python module target ---
log "building pywcocr (this also builds protobuf from source, may take a while)..."
cmake --build "$BUILD_DIR" --target pywcocr -j"$(nproc)"

# --- 6. locate the produced artifact and install into the repo ---
ART="$(find "$BUILD_DIR" -type f -name 'wcocr.cpython-*.so' | head -1)"
[ -n "$ART" ] && [ -f "$ART" ] || die "build artifact wcocr.cpython-*.so not found under $BUILD_DIR"

cp -f "$ART" "${SCRIPT_DIR}/${OUT_NAME}"
log "installed: ${SCRIPT_DIR}/${OUT_NAME}"
log "  from: $ART"
log "  size: $(stat -c%s "${SCRIPT_DIR}/${OUT_NAME}") bytes"
log "done. verify with: PYTHONPATH=${SCRIPT_DIR} LD_LIBRARY_PATH=\$(dirname \$\(readlink -f $PY312\))/../lib $PY312 -c 'import wcocr; print(wcocr.init(\"./wx/opt/wechat/wxocr\",\"./wx/opt/wechat\"))'"
