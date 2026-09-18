#!/usr/bin/env bash
# Installs build dependencies and builds the 3D PDF viewer (nanoPRC's
# nano_prc_viewer) from the vendored third_party/nanoPRC submodule.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NANOPRC_DIR="$REPO_ROOT/third_party/nanoPRC"
BUILD_DIR="$NANOPRC_DIR/build"

echo "==> Installing build dependencies (apt, needs sudo)"
sudo apt-get update -qq
sudo apt-get install -y -qq cmake build-essential git pkg-config \
    libpng-dev libjpeg-dev zlib1g-dev zenity

# Try the real "libsdl3-dev" package first (best-effort: it's very new and
# isn't in the repos of most current Ubuntu releases, 22.04/24.04 LTS
# included). When it's there, nanoPRC's CMake build (patched by
# patches/0004-prefer-system-sdl3.patch) links against it directly and skips
# compiling SDL3 from source entirely -- seconds instead of minutes, and
# none of the packages below are actually needed. Always install the rest
# too, so the from-source fallback keeps working on releases without it.
sudo apt-get install -y -qq libsdl3-dev \
    || echo "    (libsdl3-dev not available on this release -- will build SDL3 from source instead, see below)"

# SDL3's own Linux *build* dependencies (per
# https://wiki.libsdl.org/SDL3/README-linux), needed to compile the
# vendored thirdparty/SDL copy when libsdl3-dev above isn't available.
sudo apt-get install -y -qq \
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

echo "==> Building nano_prc_viewer (skips SDL3 if libsdl3-dev was found above; ~15s vs ~2min from source)"
cmake --build "$BUILD_DIR" --target nano_prc_viewer -- -j"$(nproc)"

echo "==> Installing desktop entry (~/.local/share/applications)"
mkdir -p "$HOME/.local/share/applications"
sed "s#REPO_ROOT#$REPO_ROOT#" "$REPO_ROOT/desktop/3dpdf-viewer.desktop" \
    > "$HOME/.local/share/applications/3dpdf-viewer.desktop"
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$HOME/.local/share/applications" || true

echo "==> Linking 'bin/3dpdf-view' into ~/.local/bin so it works from anywhere"
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_ROOT/bin/3dpdf-view" "$HOME/.local/bin/3dpdf-view"
case ":$PATH:" in
    *":$HOME/.local/bin:"*)
        PATH_NOTE="you can now just run '3dpdf-view <file.pdf>' from anywhere."
        ;;
    *)
        PATH_NOTE="add \$HOME/.local/bin to your PATH to run '3dpdf-view <file.pdf>' from anywhere (it's not on PATH right now)."
        ;;
esac

echo "==> Done. Binary at: $BUILD_DIR/bin/nano_prc_viewer"
echo "    $PATH_NOTE"
echo "    Or run 'bin/3dpdf-view <file.pdf>' from the repo root, or find"
echo "    '3D PDF Viewer' in your applications menu."
