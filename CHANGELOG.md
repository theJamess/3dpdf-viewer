# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **File > Import from STEP** menu item (`patches/0008`): converts a STEP
  (ISO 10303) file to a 3D PDF and opens it, via a new OpenCASCADE bridge
  into nanoPRC's existing PRC write API. Geometry only — does not carry
  over STEP assembly names/hierarchy, colors, or PMI (see the README's
  "Controls" section for the full scope note). Best-effort dependency:
  `scripts/setup.sh` and `scripts/build-deb.sh` both install OpenCASCADE
  when available and degrade to a clear "not available" dialog (instead
  of failing the whole build) when it isn't.

## [0.1.0] - 2026-09-21

First tagged release.

### Added
- Desktop viewer for PDFs with an embedded PRC 3D model (the kind produced
  by Tetra4D, 3D-Tool, SolidWorks' 3D-PDF export, CAD Exchanger, etc.),
  built on [nanoPRC](https://github.com/mvrhel/nanoPRC).
- Mouse controls: left-drag rotate, middle-drag pan, scroll to zoom,
  Ctrl+left-click to pick a triangle.
- **Section** tab: cross-section clipping plane for looking inside an
  enclosure without hiding parts.
- **Measure** tab: point-to-point distance and three-point angle
  measurement, built on the triangle-pick system, with both a panel
  readout and an in-viewport overlay. Reports in file units (see the
  README's "Controls" section for why millimeters aren't used).
- **Auto-rotate**: idle turntable spin, on by default, pauses during
  manual rotate/pan.
- Reset View, Save Screenshot (F12), on-screen control-hint caption (F1).
- `scripts/setup.sh`: one-command dependency install + build for
  Debian/Ubuntu, with a fast path when `libsdl3-dev` is available and a
  from-source SDL3 fallback when it isn't. Now fails with a clear,
  specific message on non-apt distros instead of a bare command-not-found.
- `scripts/build-deb.sh`: builds a self-contained `.deb` package (static
  SDL3, no `libsdl3-0` runtime dependency) for one-command install via
  `dpkg -i` without a compiler or the multi-minute source build.
- Desktop entry + application icon (`~/.local/share/icons/hicolor`, or
  system-wide via the `.deb`), with a friendly error dialog (via zenity)
  when a PDF has no embedded 3D content, instead of a silent failure when
  launched from a file manager's "Open With".
- A library-level API addition in nanoPRC (`patches/0005`) for reading a
  face's exact NURBS surface data (degree, control points, knot vectors)
  from *uncompressed* B-Rep bodies — not wired into the viewer UI; see
  the README's "Patches" section for its real, documented scope limits.
- CI (`.github/workflows/build.yml`): builds and smoke-tests both the
  source-build flow and the `.deb` packaging flow on every push.

### Fixed
- Multi-part assemblies rendering with some parts detached from the rest
  (a transform-deduplication bug in nanoPRC's prototype-chain resolution).
- Duplicate-transform detection using exact equality, which missed a real
  duplicate that decoded ~1 ULP apart in near-zero matrix entries.
- `bin/3dpdf-view` resolving the wrong install directory when invoked via
  its `~/.local/bin` symlink.

### Known limitations
- No U3D support (PRC only) — see the README's "Scope" section.
- Some files whose only geometry is *compressed* B-Rep with no baked
  tessellation render as a blank scene (a pre-existing, documented
  nanoPRC limitation — see the README's "Known limitation" section).
- The "Enable Auto Motion" checkbox does not (and cannot, without new
  format support) animate real per-file CAD motion data — it drives a
  generic turntable spin instead.
