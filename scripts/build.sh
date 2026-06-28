#!/usr/bin/env sh
# Build kenlm as static, self-contained binaries. Linux + macOS.
# Platform-specific knobs come from the environment:
#   FORCE_STATIC                 (default ON)
#   CMAKE_PREFIX_PATH            (macOS: ";"-joined brew keg prefixes)
#   CMAKE_OSX_DEPLOYMENT_TARGET  (macOS: e.g. 11.0)
#   CMAKE_EXTRA_ARGS             (escape hatch for anything else)
# Binaries are emitted to $BUILD_DIR/bin/.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
KENLM_SRC="${KENLM_SRC:-$ROOT/upstream/kenlm}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
FORCE_STATIC="${FORCE_STATIC:-ON}"

if [ ! -f "$KENLM_SRC/CMakeLists.txt" ]; then
	echo "error: kenlm source not found at $KENLM_SRC" >&2
	exit 1
fi
command -v cmake >/dev/null 2>&1 || { echo "error: cmake not found in PATH" >&2; exit 1; }

CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release"
CMAKE_ARGS="$CMAKE_ARGS -DFORCE_STATIC=$FORCE_STATIC"
CMAKE_ARGS="$CMAKE_ARGS -DBoost_USE_STATIC_LIBS=ON"
# Eigen is intentionally NOT provided -> kenlm auto-disables `interpolate`
# (smaller binaries, fewer deps; the core train/query tools don't need it).

# Always inject the header-only boost_system shim (cmake/lib/cmake/boost_system/).
# Modern Boost (>=1.69) ships boost_system as header-only, so neither FindBoost
# nor BoostConfig can resolve a `system` component; the shim provides it.
SHIM="$ROOT/cmake"
case ":${CMAKE_PREFIX_PATH:-}:" in
	*":$SHIM:"*) ;;
	*) CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:+$CMAKE_PREFIX_PATH;}$SHIM" ;;
esac
CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH"
[ -n "${CMAKE_OSX_DEPLOYMENT_TARGET:-}" ]  && CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$CMAKE_OSX_DEPLOYMENT_TARGET"
[ -n "${CMAKE_EXTRA_ARGS:-}" ]             && CMAKE_ARGS="$CMAKE_ARGS $CMAKE_EXTRA_ARGS"

echo "==> cmake configure"
echo "    src  : $KENLM_SRC"
echo "    build: $BUILD_DIR"
cmake -S "$KENLM_SRC" -B "$BUILD_DIR" $CMAKE_ARGS

JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
echo "==> cmake --build -j$JOBS"
cmake --build "$BUILD_DIR" -j"$JOBS"

echo "==> built binaries:"
ls -1 "$BUILD_DIR/bin/" 2>/dev/null || true
