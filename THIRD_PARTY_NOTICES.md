# Third-Party Notices

## nanoPRC

Vendored as a git submodule at `third_party/nanoPRC`, pinned to commit
`c6f7c9e3f6beed7560f95e7654287af629efaaa4`, unmodified.

- Source: https://github.com/mvrhel/nanoPRC
- License: GNU Affero General Public License v3.0 (AGPLv3) — see
  `third_party/nanoPRC/LICENSE` for its own license file, and
  `third_party/nanoPRC/THIRD_PARTY_NOTICES.md` for the licenses of
  *its* bundled dependencies (SDL3, Dear ImGui, MatrixUtil, zlib).
- We did not modify nanoPRC's source. This repository's own code (the
  `bin/3dpdf-view` wrapper script, `scripts/setup.sh`, and the `.desktop`
  entry) is a separate, thin layer that builds and launches nanoPRC's
  `nano_prc_viewer` unmodified, and is distributed under the same license
  (AGPLv3, see [LICENSE](LICENSE)) for simplicity.
