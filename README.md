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
  the terminal); also feeds the **Measure** tab (see below)

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

**Auto-rotate**: the **Views** tab's "Enable Auto Motion" checkbox (on by
default) spins the model slowly around its own vertical axis when idle —
useful for a hands-off turntable view, or just leaving something to look
at on screen. It pauses automatically while you're actively rotating
(left-drag) or panning (middle-drag) so it doesn't fight manual control.
This checkbox is upstream nanoPRC UI, but upstream never wired it to
anything — nanoPRC's PRC parser has no animation/kinematic data model at
all (nothing in the format's parsed structures represents motion), so
there was never any real per-file content it could have driven. This
project repurposed it into the one thing "motion" can honestly mean here.

**Cross-section**: the **Section** tab cuts the model away on one side of a
plane (pick an axis, slide the offset, optionally flip which side is kept)
— useful for looking inside an enclosure without hiding parts one at a time.

**Measure**: the **Measure** tab turns picked points (Ctrl+left-click, same
as Triangle Pick above) into a distance and angle tool — click "Set Point
A/B/C from last pick" after picking each point; A-B gives a distance, and
A-B-C gives the angle at B. Picked points, the line(s) between them, and
the live distance/angle are also drawn directly in the viewport, not just
the panel. Values are reported in **file units, not millimeters** — PRC
carries a per-file CAD-unit scale field, but this project could not
independently confirm which direction it converts (no bundled copy of the
ISO 14739-1 spec to check against), so rather than risk a confidently-wrong
millimeter figure, it's left as file units; see the Measure tab's own text
and this feature's patch for detail.

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
- `patches/0005-expose-brep-nurbs-surface-data.patch` — adds a *library*
  API (`prc_api_get_number_brep_bodies`/`_shells`/`_faces`,
  `prc_api_get_face_surface_type`, `prc_api_get_face_nurbs_surface`) that
  lets code built on nanoPRC read a face's exact NURBS surface (degree,
  control points, knot vectors) instead of only its tessellated triangles.
  This is not wired into `nano_prc_viewer`'s UI — nothing changes for the
  viewer as shipped here. **Known, significant limitation:** it only works
  for PRC's *uncompressed* B-Rep body encoding, which is the minority
  encoding in real-world CAD-authored 3D PDFs (most use the *compressed*
  encoding, which stores geometry in a form this patch doesn't decode —
  see the patch's own commit message and the doc comments in
  `prc_api_get_face_surface_type` for the full detail). Concretely: of
  this project's own 7 test files (the 3 bundled examples plus 4 real
  assemblies), none exposes an addressable NURBS face through this API —
  one file's only uncompressed body is an analytic Cylinder surface (a
  different, non-NURBS case this API also reports correctly), and the
  rest have no addressable uncompressed bodies at all. The extraction
  logic itself is verified correct (`tests/internal/check_nurbs_surface_api_unit.c`,
  a hand-built in-memory test against known input, since no available
  sample file exercises it), but if you're hoping this unlocks exact
  measurement on your own 3D PDFs, check with
  `tests/internal/brep_entity_census` first — it reports BrepData vs.
  BrepDataCompress per file so you know ahead of time whether a given file
  is in scope.
- `patches/0006-measure-distance-and-angle.patch` — adds the **Measure**
  tab and its in-viewport overlay (see "Controls" above): a mesh-based
  distance/angle tool built on the existing triangle-pick infrastructure.
  Approximate in the sense that it measures the *tessellated* mesh (the
  same triangles you see rendered), not the exact underlying CAD surface —
  for the handful of files in scope for patches/0005 above, that's a real
  but normally tiny difference from the true analytic distance.
- `patches/0007-auto-motion-turntable.patch` — repurposes the previously
  dead "Enable Auto Motion" checkbox into a real idle turntable auto-
  rotate (see "Controls" above and "Auto-rotate" for why it was dead and
  what "correcting" it could honestly mean given PRC has no per-file
  motion data). Also fixes a bug caught while building it: an early
  version rotated around the model matrix's own translation column, which
  turned out to be wherever the file's coordinate origin sits (not the
  model's visual center) — the cube visibly swung through an arc instead
  of spinning in place. Fixed to rotate around the model's actual
  world-space bounding-box center instead; see the patch's own commit
  message for how this was caught and verified (two Xvfb screenshots a
  few seconds apart, before and after the fix).

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

## Known limitation: some files with only compressed exact geometry render blank

While looking for a sample 3D PDF with PMI (dimensions/GD&T annotations) to
verify this viewer's existing-but-until-now-never-exercised PMI/markup
rendering code, we found a real commercial file — Tetra4D's own "Landing
Gear Main Shaft – PMI" sample — that renders as a **completely empty
scene** in `nano_prc_viewer`: no error, just nothing drawn, with an
"invalid scene bounding box" warning in the log.

Root cause, confirmed with this project's own diagnostic tools: the file's
geometry consists of one `PRC_TYPE_TOPO_BrepDataCompress` body (confirmed
via `tests/internal/brep_entity_census`) and no part in its tree has a
regular tessellation of its own (`biased_tess_index=0` for every part, via
`tests/internal/dump_tree_fields`) — this is exactly the "tessellation-free
file" case nanoPRC's exact-geometry fallback (`prc_api_get_number_exact_geom_
objects` and friends) exists for. But that fallback also reports zero
objects for this file (confirmed directly), so the fallback never fires and
nothing renders. This is a pre-existing nanoPRC limitation, not something
introduced by this project's patches — it reproduces against unmodified
upstream. We did not attempt a fix: root-causing *why* this file's
representation items don't carry the back-reference the fallback needs
would mean digging into the RI-to-exact-geometry linkage nanoPRC's tree
parser expects, which is a separate, larger investigation from what this
was found while doing (verifying PMI rendering — which remains unverified,
since this was the only readily-available sample with real PMI content and
it doesn't render at all).

If you hit a 3D PDF that opens to a blank scene, this is a plausible cause
— check it with `tests/internal/scan_prc yourfile.pdf`: `tess=0` alongside
a non-empty `geometry` section (visible via `brep_entity_census`) matches
this pattern.

## Screenshots

`screenshots/01-cube.png`, `screenshots/02-rotated-cylinder.png` (mid-rotation,
via mouse drag), `screenshots/03-triangle.png`, `screenshots/04-panned-cylinder.png`
(mid-pan, via middle-mouse drag), `screenshots/05-cross-section.png` (the
Section tab's clipping plane cutting into the cube), `screenshots/06-measure-
distance-angle.png` (the Measure tab with three points picked on the cube,
showing both the panel readout and the in-viewport distance/angle overlay)
— all rendered from this repo's own build against the bundled example PDFs.
