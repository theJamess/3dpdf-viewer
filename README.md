# 3D PDF Viewer

A simple desktop viewer for Ubuntu that opens PDF files containing an
embedded 3D model (a "3D PDF", the kind produced by CAD/engineering tools —
Tetra4D, 3D-Tool, SolidWorks' 3D-PDF export, CAD Exchanger, etc.) and lets
you rotate the model interactively.

## Scope

3D content in PDF is embedded via the ISO 32000 `/3D` annotation using one
of two binary formats:

- **PRC** (Product Representation Compact) — **supported**. This is what
  most modern 3D-PDF authoring tools produce.
- **U3D** (Universal 3D) — **not supported**. U3D was the original/legacy
  format (older Acrobat 3D Toolkit / SolidWorks exports). There is no
  actively maintained open-source decoder for it, so this viewer cannot
  open U3D-only 3D PDFs. If you open one, the viewer will fail to load
  the model.

If you're not sure which one a given PDF uses, just try opening it — PRC
files work, U3D files report a load failure.

## How it works

This does not implement PRC parsing from scratch — decoding the compressed
tessellation/geometry data is a large undertaking. It builds on
[nanoPRC](https://github.com/mvrhel/nanoPRC) (vendored as a git submodule
under `third_party/nanoPRC`, pinned to a tested commit), an open-source
PRC parser with a bundled interactive OpenGL/SDL3 viewer
(`nano_prc_viewer`) that can open a `.pdf` directly, extract its embedded
PRC stream, and render it. `bin/3dpdf-view` is a thin wrapper around that
viewer: it resolves the built binary, offers a file picker when no path is
given, and launches it.

nanoPRC is licensed under AGPLv3 — see [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Setup (Ubuntu)

```bash
git clone --recurse-submodules <this repo>
cd <this repo>
./scripts/setup.sh
```

This installs build dependencies via `apt`, builds `nano_prc_viewer` from
the vendored submodule, installs a "3D PDF Viewer" entry into your
applications menu, and symlinks `bin/3dpdf-view` into `~/.local/bin` so
the `3dpdf-view` command works from any directory (add `~/.local/bin` to
your `PATH` if it isn't already — the script tells you whether it is).

If you already cloned without `--recurse-submodules`, run
`git submodule update --init --recursive` first, or just run
`scripts/setup.sh` — it does this for you.

Takes well under a minute on a system that has `libsdl3-dev` available
(most current Debian/Ubuntu releases as of late 2026); a few minutes on
older releases that don't, since it falls back to compiling SDL3 from
source. Either way, this exact flow is checked on every push by
`.github/workflows/build.yml` against both cases (see "Patches" below).

## Usage

```bash
3dpdf-view path/to/model.pdf
```

(after running `scripts/setup.sh` — see "Setup" above). Or run
`3dpdf-view` with no arguments to pick a file graphically, or launch
"3D PDF Viewer" from your applications menu. If you haven't run
`scripts/setup.sh` yet, `bin/3dpdf-view path/to/model.pdf` from the repo
root works the same way.

**Mouse:**
- **Left-click drag** — rotate/orbit the model (arcball/trackball rotation)
- **Middle-click drag** — pan the model (follows the cursor directly, like
  grabbing it)
- **Scroll wheel** — zoom in/out, centered on wherever the model currently is
- **Ctrl + left-click** — pick a triangle (prints its vertices/normals to
  the terminal)

**Keyboard:**
- **W/A/S/D**, **Q/E** — fly the camera (forward/left/back/right, down/up);
  hold **Shift** to move faster
- **Arrow keys** — turn the camera (pitch/yaw)
- **Home** — reset the view (undoes rotate/pan/zoom/fly, back to how the
  file first opened)
- **F12** — save a screenshot (timestamped PNG, next to the working directory)
- **F1** — toggle the on-screen control-hint caption
- **Escape** — quit

A "Debug" panel in the corner exposes camera/lighting/render settings
inherited from the upstream demo viewer (click its title bar to collapse
it), plus a **Section** tab (see below) and a per-part visibility tree
under **Scene**. "Reset View" and "Save Screenshot" are also available as
buttons there (Camera and Main tabs) for anyone who'd rather click than
memorize keys.

**Cross-section**: the **Section** tab cuts the model away on one side of a
plane (pick an axis, slide the offset, optionally flip which side is kept)
— useful for looking inside an enclosure without hiding parts one at a time.

Three sample 3D PDFs to try are included at
`third_party/nanoPRC/examples/` (`cube.pdf`, `cylinder.pdf`, `triangle.pdf`).

## Patches

`scripts/setup.sh` applies these on top of the pinned upstream nanoPRC commit
after fetching the submodule — they're not part of nanoPRC upstream. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for what this means for
licensing.

- `patches/0001-middle-mouse-pan.patch` — adds middle-mouse-drag panning.
- `patches/0002-fix-duplicate-transform.patch` — fixes multi-part assemblies
  rendering with some parts detached from the rest (see below).
- `patches/0003-ui-improvements.patch` — fixes pan direction (0001 shipped
  it inverted) and a zoom-drift bug (scaling around world origin instead of
  the model's own position, only visible once panning existed to move the
  model away from the origin); adds Reset View, Save Screenshot, an
  on-screen control-hint caption, and the Section (clipping plane) tab.
- `patches/0004-prefer-system-sdl3.patch` — tries an already-installed
  SDL3 (`find_package`) before compiling the vendored copy from source,
  cutting a from-scratch `scripts/setup.sh` run from a couple of minutes
  to well under one on systems that have `libsdl3-dev`. See "Setup" above.

## Fixed: some assemblies used to render with parts in the wrong place

If a PDF's 3D model is a multi-part assembly (as opposed to a single part or a
handful of siblings), some parts could render offset from where they belong —
correctly shaped individually, but floating away from the rest of the
assembly. This was reproducible against unmodified upstream nanoPRC and traced
to how it resolves per-occurrence placement transforms for PRC's "prototype"
(shared part definition) mechanism: when following occurrence -> prototype
references, at least one affected part's final placement was composed from
two chained transforms that were really the same placement stored twice, so
the part ended up translated by exactly 2x what a single application would
give.

`patches/0002-fix-duplicate-transform.patch` fixes this by skipping a hop's
transform when it matches the one just applied one hop back in the same
chain — a legitimate multi-level chain where each hop's transform genuinely
differs is unaffected. Getting the *comparison* right took two attempts: an
initial version used exact equality (`memcmp`, then field-by-field `==`), which
worked for the file it was first written against but missed a real duplicate
in a second, independently-authored test file — two "identical" transforms
can each decode a few near-zero matrix entries to representations about 1 ULP
apart while every entry that actually matters is bit-for-bit identical, so
exact equality doesn't reliably catch this. The shipped version compares with
a 1e-9 tolerance instead (see the patch's own commit message for the full
detail — including the memcmp/struct-padding pitfall, which is worth reading
if you're touching this code).

Verified across 7 files from three different authoring tools: the 3 bundled
trivial examples (no regression), a hobbyist/AI-CAD enclosure assembly (2
PCBs + an interposer connector — the file this fix was first written
for), and 3 official [Tetra4D sample assemblies](https://tetra4d.com/pdf-samples/)
fetched fresh to cross-check against an independent source (carburetor, gear
box, disc brake). Carburetor and disc brake were already correctly assembled
and remain so; the gear box's "Lagerstuetz" (bearing support) component,
previously detached and floating well outside the housing, is now correctly
seated with the rest of the assembly. If you hit a case where a part still
looks detached after this fix, please say which part and roughly where it
should be vs. where it renders — that's exactly the kind of report that led
to catching the gap in the first version of this fix.

## Screenshots

`screenshots/01-cube.png`, `screenshots/02-rotated-cylinder.png` (mid-rotation,
via mouse drag), `screenshots/03-triangle.png`, `screenshots/04-panned-cylinder.png`
(mid-pan, via middle-mouse drag), `screenshots/05-cross-section.png` (the
Section tab's clipping plane cutting into the cube) — all rendered from this
repo's own build against the bundled example PDFs.
