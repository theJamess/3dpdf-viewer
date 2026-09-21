#!/usr/bin/env bash
# Installs build dependencies and builds the 3D PDF viewer (nanoPRC's
# nano_prc_viewer) from the vendored third_party/nanoPRC submodule.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NANOPRC_DIR="$REPO_ROOT/third_party/nanoPRC"
BUILD_DIR="$NANOPRC_DIR/build"

# This script only knows how to drive apt (Debian/Ubuntu and derivatives).
# Fail with a clear, specific message on anything else rather than let the
# first `sudo apt-get ...` below produce a bare "command not found" that
# doesn't say what's actually wrong or what to do about it.
if ! command -v apt-get >/dev/null 2>&1; then
    echo "3dpdf-view setup: this script only supports Debian/Ubuntu (apt-based) systems." >&2
    echo "" >&2
    if command -v dnf >/dev/null 2>&1; then
        echo "Detected dnf (Fedora/RHEL-family) -- not supported by this script." >&2
    elif command -v pacman >/dev/null 2>&1; then
        echo "Detected pacman (Arch-family) -- not supported by this script." >&2
    elif command -v zypper >/dev/null 2>&1; then
        echo "Detected zypper (openSUSE) -- not supported by this script." >&2
    elif command -v apk >/dev/null 2>&1; then
        echo "Detected apk (Alpine) -- not supported by this script." >&2
    else
        echo "Could not detect a known package manager on this system." >&2
    fi
    echo "" >&2
    echo "There is no automated setup for your distro yet. You can still build" >&2
    echo "manually: nanoPRC just needs CMake + a C/C++ toolchain + SDL3's own" >&2
    echo "build dependencies (see https://wiki.libsdl.org/SDL3/README-linux for" >&2
    echo "the equivalent package names on your distro), then:" >&2
    echo "  git submodule update --init --recursive" >&2
    echo "  for p in patches/*.patch; do git -C third_party/nanoPRC am \"\$p\"; done" >&2
    echo "  cmake -S third_party/nanoPRC -B third_party/nanoPRC/build -DCMAKE_BUILD_TYPE=Release" >&2
    echo "  cmake --build third_party/nanoPRC/build --target nano_prc_viewer" >&2
    exit 1
fi

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

echo "==> Installing app icon (~/.local/share/icons/hicolor)"
for size in 16 32 48 64 128 256; do
    icon_dir="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    cp "$REPO_ROOT/desktop/icons/3dpdf-viewer-${size}.png" "$icon_dir/3dpdf-viewer.png"
done
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

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
