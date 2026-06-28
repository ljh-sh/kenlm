# kenlm — self-contained multi-platform builds

[Vendored](upstream/kenlm/) [kenlm](https://github.com/kpu/kenlm) with a native
per-OS packaging layer that produces **statically-linked, self-contained**
binaries — no Boost / zlib / bzip2 / lzma / libstdc++ to install on the target
machine. Just download, extract, and run.

This is a **distribution repo** (kenlm source + build/packaging scripts + CI).
It is independent of zhhz. The x-cmd install module is handled separately.

## Binaries

Built into each release archive under `bin/`:

| binary | purpose |
|---|---|
| `lmplz` | train an N-gram model from a corpus → ARPA |
| `build_binary` | ARPA → compact binary model |
| `query` | score / query a binary model |
| `filter` | filter/vocab-constrain a model |

(`interpolate` is not built — it needs Eigen, intentionally skipped.)

## Platform matrix

Every release builds 6 targets via GitHub Actions on **native runners**
(reliable for a Boost C++ project):

| target | runner | linkage |
|---|---|---|
| `x86_64-linux-gnu` | `ubuntu-latest` | fully static |
| `aarch64-linux-gnu` | `ubuntu-24.04-arm` | fully static |
| `x86_64-macos` | `macos-13` | static Boost+compression, system libc++/libSystem |
| `aarch64-macos` | `macos-14` | same |
| `x86_64-windows` | `windows-latest` | static CRT + static vcpkg libs |
| `aarch64-windows` | `windows-11-arm` | best-effort |

## Self-containedness

- **Linux**: `-DFORCE_STATIC=ON` → `-static` → `ldd` reports *not a dynamic executable*.
- **macOS**: static Boost + compression via Homebrew `.a`; any residual non-system
  dylib is bundled next to the binary (`@executable_path/lib/…`) by `dylibbundler`.
  `otool -L` shows only `/usr/lib/…`.
- **Windows**: `/MT` static CRT + vcpkg `*-windows-static` triplets.

## Build locally

```sh
# Linux  (Debian/Ubuntu)
sudo apt-get install -y cmake build-essential \
  libboost-program-options-dev libboost-system-dev \
  libboost-thread-dev libboost-iostreams-dev \
  zlib1g-dev libbz2-dev liblzma-dev

# macOS
brew install cmake boost zlib bzip2 xz dylibbundler
export CMAKE_PREFIX_PATH="$(brew --prefix zlib);$(brew --prefix bzip2);$(brew --prefix xz)"

# both
./scripts/build.sh
./scripts/smoke.sh        # tiny train → build_binary → query round-trip
```

Binaries appear in `build/bin/`.

> **Note:** `scripts/build.sh` auto-injects `cmake/lib/cmake/boost_system/`, a
> header-only shim for `boost_system`. Since Boost ≥1.69, `boost_system` is
> header-only and ships no compiled library or per-component CMake config, so
> neither FindBoost nor BoostConfig can resolve a `system` *component*. The shim
> provides it so the vendored upstream CMake is left untouched.


## Update the vendored upstream

```sh
git subtree pull --prefix=upstream/kenlm https://github.com/kpu/kenlm.git master --squash
```

Pinned at upstream commit `4cb443e`. See [`NOTICE.md`](NOTICE.md) for license
attribution (vendored LGPL upstream; combined work + binaries under GPLv3).

## Release

Tag-driven. Push `vX.Y.Z` → CI builds all targets and publishes a GitHub
Release with the archives + `SHA256SUMS`. No manual asset building.
