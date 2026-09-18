# Third-Party Notices

## nanoPRC

Vendored as a git submodule at `third_party/nanoPRC`, pinned to commit
`c6f7c9e3f6beed7560f95e7654287af629efaaa4` of upstream.

- Source: https://github.com/mvrhel/nanoPRC
- License: GNU Affero General Public License v3.0 (AGPLv3) — see
  `third_party/nanoPRC/LICENSE` for its own license file, and
  `third_party/nanoPRC/THIRD_PARTY_NOTICES.md` for the licenses of
  *its* bundled dependencies (SDL3, Dear ImGui, MatrixUtil, zlib).
- **Modification**: `patches/0001-middle-mouse-pan.patch` adds middle-mouse-
  drag panning to `demos/viewer/src/main.cpp` (see README.md's "Controls"
  section for what it does). `scripts/setup.sh` applies it on top of the
  pinned commit above after fetching the submodule — the submodule itself
  still points at unmodified upstream, so the patch is the complete,
  human-readable record of the only change made to nanoPRC's source, per
  AGPLv3's requirement to state changes made to covered code. Everything
  else (parsing, rendering, the rest of the viewer) is unmodified upstream
  nanoPRC.
- This repository's own code (the `bin/3dpdf-view` wrapper script,
  `scripts/setup.sh`, the `.desktop` entry, and the patch above) is
  distributed under the same license (AGPLv3, see [LICENSE](LICENSE)) for
  simplicity.
