#!/usr/bin/env bash
# Installs build dependencies and builds the 3D PDF viewer (nanoPRC's
# nano_prc_viewer) from the vendored third_party/nanoPRC submodule.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NANOPRC_DIR="$REPO_ROOT/third_party/nanoPRC"
BUILD_DIR="$NANOPRC_DIR/build"

echo "==> Installing build dependencies (apt, needs sudo)"
sudo apt-get update -qq
sudo apt-get install -y -qq \
    cmake build-essential \
    libsdl3-dev libglu1-mesa-dev libpng-dev libjpeg-dev zlib1g-dev libxtst-dev \
    zenity

echo "==> Fetching nanoPRC submodules"
cd "$REPO_ROOT"
git submodule update --init --recursive

echo "==> Configuring (cmake)"
mkdir -p "$BUILD_DIR"
cmake -S "$NANOPRC_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release

echo "==> Building nano_prc_viewer (this compiles bundled SDL3, may take a few minutes)"
cmake --build "$BUILD_DIR" --target nano_prc_viewer -- -j"$(nproc)"

echo "==> Installing desktop entry (~/.local/share/applications)"
mkdir -p "$HOME/.local/share/applications"
sed "s#REPO_ROOT#$REPO_ROOT#" "$REPO_ROOT/desktop/3dpdf-viewer.desktop" \
    > "$HOME/.local/share/applications/3dpdf-viewer.desktop"
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$HOME/.local/share/applications" || true

echo "==> Done. Binary at: $BUILD_DIR/bin/nano_prc_viewer"
echo "    Run 'bin/3dpdf-view <file.pdf>' from the repo root to open a 3D PDF,"
echo "    or find '3D PDF Viewer' in your applications menu."
