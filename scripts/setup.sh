#!/usr/bin/env bash
# Installs build dependencies and builds the 3D PDF viewer (nanoPRC's
# nano_prc_viewer) from the vendored third_party/nanoPRC submodule.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NANOPRC_DIR="$REPO_ROOT/third_party/nanoPRC"
BUILD_DIR="$NANOPRC_DIR/build"

echo "==> Installing build dependencies (apt, needs sudo)"
# NOTE: we do NOT depend on the "libsdl3-dev" apt package -- it's very new
# and isn't in the repos of most current Ubuntu releases (22.04/24.04 LTS
# included). nanoPRC's CMake build compiles SDL3 itself from the vendored
# thirdparty/SDL submodule, so what we actually need are SDL3's own Linux
# *build* dependencies (per https://wiki.libsdl.org/SDL3/README-linux),
# not a prebuilt SDL3 package.
sudo apt-get update -qq
sudo apt-get install -y -qq \
    cmake build-essential git pkg-config \
    libpng-dev libjpeg-dev zlib1g-dev zenity \
    libasound2-dev libpulse-dev libjack-dev libsndio-dev \
    libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev \
    libxi-dev libxss-dev libxtst-dev libxkbcommon-dev \
    libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev libglu1-mesa-dev \
    libdbus-1-dev libudev-dev libusb-1.0-0-dev
# Newer, Ubuntu-22.04+-only additions (Wayland/pipewire/io_uring support) --
# best-effort, since package names/availability vary more across releases.
sudo apt-get install -y -qq \
    libpipewire-0.3-dev libwayland-dev libdecor-0-dev liburing-dev \
    || echo "    (skipped one or more optional Wayland/pipewire packages -- not fatal)"

echo "==> Fetching nanoPRC submodules"
cd "$REPO_ROOT"
git submodule update --init --recursive

echo "==> Applying vendored patches to nanoPRC"
for patch in "$REPO_ROOT"/patches/*.patch; do
    [ -e "$patch" ] || continue
    if git -C "$NANOPRC_DIR" apply --check "$patch" 2>/dev/null; then
        git -C "$NANOPRC_DIR" am --keep-non-patch "$patch"
        echo "    applied $(basename "$patch")"
    elif git -C "$NANOPRC_DIR" apply --reverse --check "$patch" 2>/dev/null; then
        echo "    $(basename "$patch") already applied, skipping"
    else
        echo "    WARNING: $(basename "$patch") does not apply cleanly against the pinned nanoPRC commit -- skipping. The build will proceed without it; see README.md's 'Patches' section." >&2
    fi
done

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
