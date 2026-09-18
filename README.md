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

This installs build dependencies via `apt` (cmake, SDL3 dev headers,
libpng/libjpeg/zlib dev headers, `zenity` for the file picker), builds
`nano_prc_viewer` from the vendored submodule, and installs a "3D PDF
Viewer" entry into your applications menu.

If you already cloned without `--recurse-submodules`, run
`git submodule update --init --recursive` first, or just run
`scripts/setup.sh` — it does this for you.

## Usage

```bash
bin/3dpdf-view path/to/model.pdf
```

Or run `bin/3dpdf-view` with no arguments to pick a file graphically, or
launch "3D PDF Viewer" from your applications menu.

**Controls:**
- **Left-click drag** — rotate/orbit the model (arcball/trackball rotation)
- **Middle-click drag** — pan the model (added on top of nanoPRC upstream; see
  `patches/`)
- **Scroll wheel** — zoom
- A "Debug" panel is shown in the corner (camera/lighting/render options
  inherited from the upstream demo viewer); click its title bar to
  collapse it out of the way.

Three sample 3D PDFs to try are included at
`third_party/nanoPRC/examples/` (`cube.pdf`, `cylinder.pdf`, `triangle.pdf`).

## Patches

`scripts/setup.sh` applies these on top of the pinned upstream nanoPRC commit
after fetching the submodule — they're not part of nanoPRC upstream. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for what this means for
licensing.

- `patches/0001-middle-mouse-pan.patch` — middle-mouse pan, see "Controls"
  above.
- `patches/0002-fix-duplicate-transform.patch` — fixes multi-part assemblies
  rendering with some parts detached from the rest (see below).

## Fixed: some assemblies used to render with parts in the wrong place

If a PDF's 3D model is a multi-part assembly (as opposed to a single part or a
handful of siblings), some parts could render offset from where they belong —
correctly shaped individually, but floating away from the rest of the
assembly. This was reproducible against unmodified upstream nanoPRC and traced
to how it resolves per-occurrence placement transforms for PRC's "prototype"
(shared part definition) mechanism: when following occurrence -> prototype
references, at least one affected part's final placement was composed from
two chained transforms that happened to be byte-identical, so the part ended
up translated by exactly 2x what a single application would give (verified
numerically on two independent axes).

`patches/0002-fix-duplicate-transform.patch` fixes this by skipping a hop's
transform when it exactly matches the one just applied one hop back in the
same chain — a legitimate multi-level chain where each hop's transform
genuinely differs is unaffected. Verified against a real 4-part assembly PDF
(enclosure + 2 PCBs + an interposer connector): isolating each top-level part
against the enclosure individually now shows the larger PCB seated near the
top parallel to the floor, the smaller PCB seated against the bottom, and the
interposer connector near the larger board's header — matching the assembly's
known-correct layout. One smaller residual offset remains in a sub-feature of
the interposer part (unclear cause, much smaller magnitude, not visually
obvious in practice) — if you hit a case where a part still looks
detached after this fix, that's likely the same class of bug in a different
shape; file it with as much detail as you can (which part, roughly where it
should be vs. where it renders).

## Screenshots

`screenshots/01-cube.png`, `screenshots/02-rotated-cylinder.png` (mid-rotation,
via mouse drag), `screenshots/03-triangle.png`, `screenshots/04-panned-cylinder.png`
(mid-pan, via middle-mouse drag) — all rendered from this repo's own build
against the bundled example PDFs.
