#!/usr/bin/env sh
# Minimal end-to-end kenlm pipeline benchmark.
#   train (lmplz) -> prune/trim (filter) -> compile (build_binary) -> score (query)
#
# Emits ONE TSV row to stdout:
#   target  train_s  arpa_kb  trim_s  build_s  bin_kb  query_s  ppl  lmplz_kb
#
# train_s / query_s come from kenlm's self-reported `real:X` (precise).
# trim_s / build_s are shell-level `date +%s` (integer seconds: sub-second on
# fast steps shows as 0, which is fine — the meaningful musl-vs-glibc delta
# lives in train_s, query_s and the binary sizes).
# lmplz_kb is the size of the `lmplz` executable itself — the headline
# glibc-static vs musl-static comparison.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
TARGET="${TARGET:-unknown}"

pick() { [ -f "$1.exe" ] && printf '%s.exe\n' "$1" || printf '%s\n' "$1"; }
B="$BUILD_DIR/bin"
[ -d "$B/Release" ] && B="$B/Release"   # MSVC multi-config
LMPLZ=$(pick "$B/lmplz")
BUILDBIN=$(pick "$B/build_binary")
QUERY=$(pick "$B/query")
FILTER=$(pick "$B/filter")
for f in "$LMPLZ" "$BUILDBIN" "$QUERY" "$FILTER"; do
	[ -x "$f" ] || [ -f "$f" ] || { echo "bench: missing $f" >&2; exit 1; }
done

real_of() { # $1=logfile; print first 'real:' value in seconds, or empty
	grep -oE 'real:[0-9.]+' "$1" 2>/dev/null | head -1 | sed 's/real://'
}
sec_of() { # $1=logfile; print first wall-clock second from `time` output
	awk '/real/{print $NF}' "$1" 2>/dev/null | head -1 | sed 's/0m//;s/s//'
}
kb() { awk -v n="$(wc -c < "$1")" 'BEGIN{printf "%d", (n+511)/1024}'; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Deterministic synthetic corpus (~20k lines) — same on every host.
awk 'BEGIN{
	srand(42)
	n=split("the a an cat dog sat ran on mat small fast far down by door and of to in with from",w," ")
	for(i=0;i<20000;i++){
		l=""; m=int(rand()*8)+2
		for(j=0;j<m;j++) l=l" "w[int(rand()*n)+1]
		print l
	}
}' > "$TMP/corpus.txt"

# Held-out query sentences.
printf 'the cat sat on the mat\na small dog ran far\nthe dog sat down by the door\n' > "$TMP/q.txt"

# Vocabulary file for the trim step.
tr ' ' '\n' < "$TMP/corpus.txt" | sort -u > "$TMP/vocab.txt"

# 1) train  (ARPA -> stdout, progress + final `real:` -> stderr)
"$LMPLZ" -o 4 -S 100M --discount_fallback < "$TMP/corpus.txt" \
	> "$TMP/m.arpa" 2> "$TMP/lmplz.log" || { cat "$TMP/lmplz.log" >&2; exit 1; }
TRAIN_S=$(real_of "$TMP/lmplz.log")
ARPA_KB=$(kb "$TMP/m.arpa")

# 2) trim/prune: filter ARPA down to the vocabulary (best-effort: on any
#    unexpected syntax, fall back to the untrimmed ARPA so the rest still runs).
T0=$(date +%s)
"$FILTER" file "$TMP/vocab.txt" < "$TMP/m.arpa" \
	> "$TMP/p.arpa" 2> "$TMP/filter.log" || cp "$TMP/m.arpa" "$TMP/p.arpa"
TRIM_S=$(( $(date +%s) - T0 ))

# 3) compile to binary model (binary -> path arg; progress to stdout/stderr)
T0=$(date +%s)
"$BUILDBIN" "$TMP/p.arpa" "$TMP/m.bin" \
	> "$TMP/build.log" 2>&1 || { cat "$TMP/build.log" >&2; exit 1; }
BUILD_S=$(( $(date +%s) - T0 ))
BIN_KB=$(kb "$TMP/m.bin")

# 4) score: query prints perplexity + its own `real:` to stdout
Q_OUT=$("$QUERY" "$TMP/m.bin" < "$TMP/q.txt" 2>&1) || true
PPL=$(printf '%s\n' "$Q_OUT" | awk '/Perplexity including OOVs/{print $NF; found=1} END{if(!found)print "NA"}')
QUERY_S=$(printf '%s\n' "$Q_OUT" | grep -oE 'real:[0-9.]+' | head -1 | sed 's/real://')
[ -n "$QUERY_S" ] || QUERY_S="NA"

LMPLZ_KB=$(kb "$LMPLZ")

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
	"$TARGET" "${TRAIN_S:-NA}" "$ARPA_KB" "$TRIM_S" "${BUILD_S:-NA}" "$BIN_KB" "$QUERY_S" "$PPL" "$LMPLZ_KB"