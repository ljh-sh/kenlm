#!/usr/bin/env sh
# Stage the built binaries into a self-contained dist archive. Linux + macOS.
#   TARGET   e.g. x86_64-linux-gnu | x86_64-macos | aarch64-macos
#   BUILD_DIR (default ./build)
#   DIST      (default ./dist)
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
DIST="${DIST:-$ROOT/dist}"
TARGET="${TARGET:?set TARGET, e.g. x86_64-linux-gnu}"

BIN_SRC="$BUILD_DIR/bin"
# The four core kenlm tools.
BINARIES="lmplz build_binary query filter"

STAGE="$DIST/kenlm-$TARGET"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin"

for b in $BINARIES; do
	src="$BIN_SRC/$b"
	[ -f "$src" ] || { echo "error: $src not built" >&2; exit 1; }
	cp "$src" "$STAGE/bin/$b"
done
chmod +x "$STAGE/bin/"*

# macOS: collect any non-system dylibs next to the binaries so the package is
# self-contained. If everything linked static (the goal), this is a no-op.
if [ "$(uname)" = "Darwin" ]; then
	if command -v dylibbundler >/dev/null 2>&1; then
		echo "==> dylibbundler (collect non-system dylibs, no-op if all-static)"
		args=""
		for b in $BINARIES; do args="$args -x $STAGE/bin/$b"; done
		# -od : overwrite deps dir; -b : fix @executable_path in the binaries
		dylibbundler -od -b $args -d "$STAGE/bin/libs/" 2>/dev/null || true
		rmdir "$STAGE/bin/libs" 2>/dev/null || true   # remove if empty (all-static)
	fi
fi

( cd "$DIST" && tar czf "kenlm-$TARGET.tar.gz" "kenlm-$TARGET" )
( cd "$DIST" && command -v sha256sum >/dev/null 2>&1 \
	&& sha256sum "kenlm-$TARGET.tar.gz" > "kenlm-$TARGET.tar.gz.sha256" \
	|| shasum -a 256 "kenlm-$TARGET.tar.gz" > "kenlm-$TARGET.tar.gz.sha256" )

echo "==> $DIST/kenlm-$TARGET.tar.gz"
