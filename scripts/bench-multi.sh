#!/usr/bin/env bash
# Multi-run wrapper around scripts/bench.sh. Runs the benchmark N times
# (default 5), emitting N raw TSV rows to stdout — one per run. Pass
# the captured output through scripts/bench-aggregate.sh to compute
# min/median/mean/max/stddev per column.
#
# Usage:
#   bash scripts/bench-multi.sh [TARGET] [N]
# or:
#   BENCH_ITER=10 bash scripts/bench-multi.sh TARGET=x86_64-linux-musl
#
# Each run is independent: a fresh `lmplz` process, a fresh random bench
# corpus (deterministic via srand(42) inside bench.sh), the same CPU
# governor state, etc. runs are back-to-back within one CI step so any
# machine warmup steady-state drift is captured across the N rows.
set -eu

TARGET="${1:-${TARGET:-local}}"
N="${BENCH_ITER:-${2:-5}}"

for _i in $(seq 1 "$N"); do
	bash "$(dirname "$0")/bench.sh" TARGET="$TARGET"
done
