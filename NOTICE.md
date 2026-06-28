# NOTICE

This repository (`ljh-sh/kenlm`) provides self-contained, statically-linked
builds of **kenlm** and the packaging layer around it.

## Vendored upstream

`upstream/kenlm/` is an unmodified copy of [kpu/kenlm](https://github.com/kpu/kenlm),
vendored via `git subtree` at commit `4cb443e` (2025-03-30).

kenlm is licensed under the **GNU LGPL** (see `upstream/kenlm/COPYING`,
`upstream/kenlm/COPYING.LESSER.3`, `upstream/kenlm/LICENSE`, retained verbatim).

LGPL permits a combined work to be offered under the GPL. Accordingly, the
combined binaries and the distribution layer in this repository
(`scripts/`, CI, packaging) are distributed under **GPLv3** (see top-level `LICENSE`).

## Relinkability

LGPL requires that recipients can relink against a modified version of the
library. This is satisfied by shipping the **exact kenlm source** under
`upstream/kenlm/` together with the build scripts in `scripts/` (see
`scripts/build.sh` / `scripts/build.ps1`), which reproduce these binaries with
`-DFORCE_STATIC=ON`.

## Third-party dependencies (statically linked into the binaries)

- **Boost** (program_options, system, thread, iostreams) — Boost Software License
- **zlib** — zlib License
- **bzip2** — BSD-style
- **liblzma / xz** — public domain
- **Eigen** — only needed for `interpolate`, which is **not** included in these builds

These are resolved from system packages (Linux/macOS) or vcpkg (Windows) at
build time and statically linked, so end users need none of them installed.
