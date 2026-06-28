#!/usr/bin/env sh
# Smoke test: lmplz -> build_binary -> query on a tiny corpus.
# POSIX; runs on Linux, macOS, and the Windows runner (via git-bash).
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
BIN="$BUILD_DIR/bin"
# Windows MSVC is multi-config -> binaries land in bin/Release
[ -d "$BIN/Release" ] && BIN="$BIN/Release"

ext_for() { [ -f "$1.exe" ] && printf '%s.exe' "$1" || printf '%s' "$1"; }
LMPLZ=$(ext_for "$BIN/lmplz")
BUILD_BINARY=$(ext_for "$BIN/build_binary")
QUERY=$(ext_for "$BIN/query")

for b in "$LMPLZ" "$BUILD_BINARY" "$QUERY"; do
	[ -x "$b" ] || { echo "error: missing executable $b" >&2; exit 1; }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Enough variety for Kneser-Ney to have something to discount; --discount_fallback
# keeps the smoke test robust on tiny corpora.
cat > "$TMP/corpus.txt" <<'EOF'
the cat sat on the mat
the cat ran fast and far
the dog sat down by the door
a small cat and a small dog
the cat and the dog sat together
EOF

echo "==> lmplz (train 3-gram)"
"$LMPLZ" -o 3 -S 50M --discount_fallback < "$TMP/corpus.txt" > "$TMP/model.arpa"

echo "==> build_binary"
"$BUILD_BINARY" "$TMP/model.arpa" "$TMP/model.binary"

echo "==> query"
printf 'the cat sat\n' | "$QUERY" "$TMP/model.binary" > "$TMP/out.txt"
[ -s "$TMP/out.txt" ] || { echo "error: query produced no output" >&2; exit 1; }

echo "smoke OK: trained 3-gram, built binary model, queried successfully"
