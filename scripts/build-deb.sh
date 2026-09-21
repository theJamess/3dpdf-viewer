#!/usr/bin/env bash
# Copyright (C) 2026 theJamess
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
# General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Builds a self-contained .deb package of the 3D PDF Viewer.
#
# This is a SEPARATE build from scripts/setup.sh's dev build: it forces
# nanoPRC to compile its OWN static SDL3 from source (-DNANOPRC_USE_SYSTEM_
# SDL=OFF -DSDL_SHARED=OFF -DSDL_STATIC=ON) instead of preferring whatever
# SDL3 package the build machine happens to have (patches/0004's normal,
# faster default). A .deb built against the local machine's system SDL3
# would need a matching `libsdl3-0` runtime package on every machine that
# installs it -- and per patches/0004's own comment, most current Ubuntu
# releases don't package SDL3 at all yet, which would make the .deb
# uninstallable on exactly the systems it's meant to reach. Statically
# linking it instead means the package brings its own copy and has no such
# dependency at all -- verified with `ldd` (see this script's own checks
# below) to carry no libSDL3.so requirement.
#
# Usage: scripts/build-deb.sh
# Output: dist/3dpdf-viewer_<version>_amd64.deb
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NANOPRC_DIR="$REPO_ROOT/third_party/nanoPRC"
BUILD_DIR="$NANOPRC_DIR/build-deb"
DIST_DIR="$REPO_ROOT/dist"
VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
PKG_NAME="3dpdf-viewer"
STAGING="$DIST_DIR/staging"

for tool in dpkg-deb patchelf; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "build-deb.sh: '$tool' is required (sudo apt-get install -y $tool) and wasn't found." >&2
        exit 1
    fi
done

echo "==> Installing build dependencies (same as scripts/setup.sh, minus libsdl3-dev on purpose)"
sudo apt-get update -qq
sudo apt-get install -y -qq cmake build-essential git pkg-config \
    libpng-dev libjpeg-dev zlib1g-dev
sudo apt-get install -y -qq \
    libasound2-dev libpulse-dev libjack-dev libsndio-dev \
    libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev \
    libxi-dev libxss-dev libxtst-dev libxkbcommon-dev \
    libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev libglu1-mesa-dev \
    libdbus-1-dev libudev-dev libusb-1.0-0-dev
sudo apt-get install -y -qq \
    libpipewire-0.3-dev libwayland-dev libdecor-0-dev liburing-dev \
    || echo "    (skipped one or more optional Wayland/pipewire packages -- not fatal)"
sudo apt-get install -y -qq \
    libocct-data-exchange-dev libocct-modeling-algorithms-dev libocct-visualization-dev \
    libfontconfig-dev libtbb-dev \
    || echo "    (OpenCASCADE not available on this build machine -- packaged binary will have STEP import compiled out)"

echo "==> Fetching nanoPRC submodule + applying patches"
cd "$REPO_ROOT"
git submodule update --init --recursive
# Identity passed explicitly for the same reason as in scripts/setup.sh: `git am` commits,
# and a machine that has never configured git has no committer identity to commit as.
for patch in "$REPO_ROOT"/patches/*.patch; do
    [ -e "$patch" ] || continue
    if git -C "$NANOPRC_DIR" apply --check "$patch" 2>/dev/null; then
        git -C "$NANOPRC_DIR" \
            -c user.name="3dpdf-viewer setup" -c user.email="setup@localhost" \
            am --keep-non-patch "$patch"
    elif git -C "$NANOPRC_DIR" apply --reverse --check "$patch" 2>/dev/null; then
        : # already applied
    else
        echo "build-deb.sh: WARNING: $(basename "$patch") does not apply cleanly -- skipping." >&2
    fi
done

echo "==> Configuring (forcing a static, self-contained SDL3 build)"
mkdir -p "$BUILD_DIR"
cmake -S "$NANOPRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DNANOPRC_USE_SYSTEM_SDL=OFF \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON

echo "==> Building nano_prc_viewer"
cmake --build "$BUILD_DIR" --target nano_prc_viewer -- -j"$(nproc)"

VIEWER_BIN="$BUILD_DIR/bin/nano_prc_viewer"
NANO_PRC_LIB="$BUILD_DIR/lib/libnano_prc.so"
[ -x "$VIEWER_BIN" ] || { echo "build-deb.sh: build did not produce $VIEWER_BIN" >&2; exit 1; }
[ -f "$NANO_PRC_LIB" ] || { echo "build-deb.sh: build did not produce $NANO_PRC_LIB" >&2; exit 1; }

echo "==> Staging package tree"
rm -rf "$STAGING"
mkdir -p "$STAGING/DEBIAN" \
    "$STAGING/usr/lib/3dpdf-viewer" \
    "$STAGING/usr/bin" \
    "$STAGING/usr/share/applications" \
    "$STAGING/usr/share/doc/3dpdf-viewer"

install -m755 "$VIEWER_BIN" "$STAGING/usr/lib/3dpdf-viewer/nano_prc_viewer"
install -m755 "$NANO_PRC_LIB" "$STAGING/usr/lib/3dpdf-viewer/libnano_prc.so"

# The binary's build-time RPATH points at $BUILD_DIR (an absolute path that
# won't exist on the machine that installs this package) -- point it at its
# own install directory instead so it finds the bundled libnano_prc.so
# wherever the package actually lands.
patchelf --set-rpath '$ORIGIN' "$STAGING/usr/lib/3dpdf-viewer/nano_prc_viewer"

# OpenCASCADE (STEP import), unlike SDL3, isn't statically linked -- OCCT's
# shared libraries are the normal way to consume it, and there's no quick
# static-build equivalent of -DSDL_STATIC=ON to reach for. Instead, derive
# the extra runtime Depends: directly from what the built binary actually
# links (via ldd + dpkg -S, so this adapts to whatever OCCT ABI version is
# on THIS build machine rather than a hardcoded version string that would
# go stale the moment a newer OCCT lands in the repos) -- and only if
# OpenCASCADE was actually found and linked in the first place, so a build
# machine without it still produces a working .deb with one less feature,
# never a package that claims a dependency it doesn't need.
EXTRA_DEPENDS=""
# Either spelling: the STEP library is libTKDESTEP on OCCT >= 7.8 and libTKSTEP before it (see the
# resolution in nanoPRC's top-level CMakeLists.txt, patches/0008). Matching only the newer name here
# would silently ship a .deb that HAS STEP import linked in but declares none of its OCCT runtime
# dependencies -- which installs cleanly and then fails to start on the user's machine.
if ldd "$STAGING/usr/lib/3dpdf-viewer/nano_prc_viewer" 2>/dev/null | grep -qiE "libTKDESTEP|libTKSTEP"; then
    echo "==> STEP import is linked in -- resolving its extra runtime packages"
    EXTRA_LIBS="$(ldd "$STAGING/usr/lib/3dpdf-viewer/nano_prc_viewer" | awk '{print $3}' | grep -E '/libTK|/libfontconfig|/libtbb' || true)"
    EXTRA_PKGS=""
    for lib in $EXTRA_LIBS; do
        # realpath: ldd reports /lib/... (the merged-usr symlink path), but
        # dpkg's own recorded file lists use the real /usr/lib/... path --
        # `dpkg -S` matches literally, not through symlinks, so without
        # this every lookup below silently comes back empty.
        # `|| true`: dpkg -S exits nonzero for a library not owned by any
        # package (rare here, but possible for something resolved via a
        # non-dpkg-managed path) -- under this script's `set -e -o
        # pipefail`, that would otherwise abort the whole build over one
        # unresolvable dependency instead of just skipping it.
        reallib="$(realpath "$lib" 2>/dev/null || echo "$lib")"
        pkg="$( (dpkg -S "$reallib" 2>/dev/null || true) | head -1 | cut -d: -f1)"
        if [ -n "$pkg" ]; then
            case " $EXTRA_PKGS " in
                *" $pkg "*) ;; # already have it
                *) EXTRA_PKGS="$EXTRA_PKGS $pkg" ;;
            esac
        fi
    done
    EXTRA_DEPENDS="$(echo "$EXTRA_PKGS" | xargs -n1 | paste -sd, - | sed 's/,/, /g')"
    echo "    resolved: $EXTRA_DEPENDS"
fi

install -m755 "$REPO_ROOT/bin/3dpdf-view" "$STAGING/usr/bin/3dpdf-view"

sed "s#REPO_ROOT/bin/3dpdf-view#/usr/bin/3dpdf-view#" \
    "$REPO_ROOT/desktop/3dpdf-viewer.desktop" \
    > "$STAGING/usr/share/applications/3dpdf-viewer.desktop"

for size in 16 32 48 64 128 256; do
    icon_dir="$STAGING/usr/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    install -m644 "$REPO_ROOT/desktop/icons/3dpdf-viewer-${size}.png" "$icon_dir/3dpdf-viewer.png"
done

cat > "$STAGING/usr/share/doc/3dpdf-viewer/copyright" <<'EOF'
This package (3dpdf-viewer) wraps nanoPRC (https://github.com/mvrhel/nanoPRC),
vendored as a git submodule and modified by the patches/ directory of the
source repository this package was built from.

This project's own files (bin/3dpdf-view, scripts/setup.sh,
scripts/build-deb.sh, and this package's own build/packaging logic):
Copyright (C) 2026 theJamess.

Both this package's own code and nanoPRC are licensed under the GNU
Affero General Public License v3.0 (AGPLv3). The full license text and a
detailed account of every modification made to nanoPRC are included in the
source repository as LICENSE and THIRD_PARTY_NOTICES.md -- see the
project's README for where to find it.

nanoPRC itself bundles SDL3, Dear ImGui, MatrixUtil, and zlib; see
nanoPRC's own THIRD_PARTY_NOTICES.md in that repository for their licenses.
EOF
gzip -9 -n -c "$REPO_ROOT/README.md" > "$STAGING/usr/share/doc/3dpdf-viewer/README.md.gz" 2>/dev/null || \
    cp "$REPO_ROOT/README.md" "$STAGING/usr/share/doc/3dpdf-viewer/README.md"

INSTALLED_SIZE_KB="$(du -sk "$STAGING/usr" | cut -f1)"

cat > "$STAGING/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE_KB
Depends: libc6, libstdc++6, libx11-6, libgl1${EXTRA_DEPENDS:+, $EXTRA_DEPENDS}
Recommends: zenity
Maintainer: 3D PDF Viewer project
Description: View and rotate 3D models embedded in PDF files
 A desktop viewer for PDFs that contain an embedded PRC 3D model (the
 kind produced by CAD/engineering tools such as Tetra4D, 3D-Tool,
 SolidWorks' 3D-PDF export, and CAD Exchanger). Supports rotate, pan,
 zoom, cross-sections, and point-to-point measurement.
 .
 Wraps nanoPRC (AGPLv3, https://github.com/mvrhel/nanoPRC) -- see
 /usr/share/doc/3dpdf-viewer/copyright.
EOF

cat > "$STAGING/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database -q /usr/share/applications || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
exit 0
EOF
chmod 755 "$STAGING/DEBIAN/postinst"

echo "==> Verifying the packaged binary carries no libSDL3.so runtime dependency"
if ldd "$STAGING/usr/lib/3dpdf-viewer/nano_prc_viewer" 2>/dev/null | grep -qi sdl3; then
    echo "build-deb.sh: packaged binary still links libSDL3.so -- static SDL3 build did not take effect as expected." >&2
    exit 1
fi

if [ -n "$EXTRA_DEPENDS" ]; then
    echo "==> STEP import: enabled (OpenCASCADE found and linked)"
else
    echo "==> STEP import: NOT enabled in this package (OpenCASCADE wasn't found on this build machine) -- File > Import from STEP will report unavailable"
fi

echo "==> Building the .deb"
mkdir -p "$DIST_DIR"
DEB_PATH="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGING" "$DEB_PATH"
rm -rf "$STAGING"

echo "==> Done: $DEB_PATH"
dpkg-deb --info "$DEB_PATH"
