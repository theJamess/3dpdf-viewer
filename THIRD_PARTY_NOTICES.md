# Third-Party Notices

## nanoPRC

Vendored as a git submodule at `third_party/nanoPRC`, pinned to commit
`c6f7c9e3f6beed7560f95e7654287af629efaaa4` of upstream.

- Source: https://github.com/mvrhel/nanoPRC
- License: GNU Affero General Public License v3.0 (AGPLv3) — see
  `third_party/nanoPRC/LICENSE` for its own license file, and
  `third_party/nanoPRC/THIRD_PARTY_NOTICES.md` for the licenses of
  *its* bundled dependencies (SDL3, Dear ImGui, MatrixUtil, zlib).
- **Modifications** (all applied by `scripts/setup.sh` on top of the pinned
  commit above after fetching the submodule; the submodule itself still
  points at unmodified upstream, so these patches are the complete,
  human-readable record of every change made to nanoPRC's source, per
  AGPLv3's requirement to state changes made to covered code):
  - `patches/0001-middle-mouse-pan.patch` adds middle-mouse-drag panning to
    `demos/viewer/src/main.cpp` (see README.md's "Controls" section).
  - `patches/0002-fix-duplicate-transform.patch` fixes a placement bug in
    `src/prc_api.c`'s PRC "prototype" transform composition that could
    render some parts of a multi-part assembly detached from the rest (see
    README.md's "Fixed" section).
  - `patches/0003-ui-improvements.patch` fixes the pan direction and a
    zoom-drift bug from 0001, and adds Reset View, Save Screenshot, an
    on-screen control-hint caption, and a cross-section clipping plane
    (README.md's "Controls" section), touching
    `demos/viewer/src/main.cpp`, `scene.{h,cpp}`, `mesh.{h,cpp}`, and
    `demos/viewer/shaders/generic.frag`.
  - `patches/0004-prefer-system-sdl3.patch` makes the build try an
    already-installed SDL3 before compiling the vendored copy from source
    (README.md's "Setup" section), touching `CMakeLists.txt` and
    `thirdparty/CMakeLists.txt`.
  - `patches/0005-expose-brep-nurbs-surface-data.patch` adds a library API
    (`prc_api_get_number_brep_bodies`/`_shells`/`_faces`,
    `prc_api_get_face_surface_type`, `prc_api_get_face_nurbs_surface`,
    `prc_api_release_nurbs_surface` in `include/prc_api.h` and
    `src/prc_tri_primitives_api.c`) for reading a face's exact NURBS
    surface data (degree, control points, knot vectors), plus two new
    internal test tools under `tests/internal/`. Not wired into the
    viewer UI; see README.md's "Patches" section for its significant
    scope limitation (uncompressed B-Rep bodies only).
  - `patches/0006-measure-distance-and-angle.patch` adds a **Measure** tab
    and in-viewport overlay to `demos/viewer/src/main.cpp`: point-to-point
    distance and three-point angle, built on the existing triangle-pick
    ray-cast (see README.md's "Controls" section).
  - `patches/0007-auto-motion-turntable.patch` repurposes the previously
    dead "Enable Auto Motion" checkbox (Views tab) in
    `demos/viewer/src/main.cpp` into a real idle turntable auto-rotate
    (see README.md's "Controls" section).
  Everything else (parsing, rendering, the rest of the viewer) is unmodified
  upstream nanoPRC.
- This repository's own code (the `bin/3dpdf-view` wrapper script,
  `scripts/setup.sh`, the `.desktop` entry, and the patches above) is
  distributed under the same license (AGPLv3, see [LICENSE](LICENSE)) for
  simplicity.
