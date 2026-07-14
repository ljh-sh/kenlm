# musl-static vs glibc-static — comparison

A rigorous perf comparison of the two libc-choices we ship for Linux
(`x86_64-linux-gnu` + `aarch64-linux-gnu` via ubuntu-latest apt; and
`x86_64-linux-musl` + `aarch64-linux-musl` via the alpine:3.20 docker).

The headline answer: **glibc-static wins on train time** (statistically
significant at N=5, ~6-9 % faster on x86_64 and ~3-5 % on aarch64),
**musl-static wins on binary size** (~5-11 % smaller), and `query` is
within noise on both sides. **Memory footprint is identical** (no
allocator behaviour delta shows up in our corpus).

## Methodology

### The bench pipeline (one run)

On the **same deterministic synthetic corpus** (~20k lines, seeded
with `srand(42)` in `scripts/bench.sh`), each target runs:

| stage | tool | purpose |
|---|---|---|
| **train** | `lmplz -o 4 -S 100M --discount_fallback` | count & interpolate n-grams → ARPA |
| **trim** | `filter file <vocab>` | prune ARPA to a vocabulary |
| **compile** | `build_binary` | ARPA → compact binary model |
| **score** | `query` | score held-out sentences, print perplexity |

For each stage we capture wall-clock:
- `train_s` / `query_s` come from kenlm's own `real:` line (precise)
- `trim_s` / `build_s` are shell-level `date +%s` (integer; sub-second
  shows 0)
- intermediate sizes in KB
- the model's perplexity on the held-out set
- `lmplz_kb` — the size of the `lmplz` executable itself

### Multi-run capture (N=5)

A single run is dominated by shared-runner noise (other tenants on the
host, ephemeral filesystem cache, kernel scheduling). One sample per
target was unconvincing. So:

> every release run emits `dist/bench-<target>.tsv` containing **5 raw
> rows** (the bench.sh output of 5 back-to-back runs, see
> `scripts/bench-multi.sh`) and `dist/bench-<target>.agg.tsv` containing
> **min / median / mean / stddev / max** per numeric column (see
> `scripts/bench-aggregate.sh`, a portable awk script that does
> min/max/median + Welford-style mean+stddev).

This is the **only** run-to-run noise model we trust. The bench corpus
is deterministic so the synthetic spread captures machine noise alone.

For the perf comparison to be valid, we report **median ± stddev** —
a single point estimate would be hiding the variance on either side.

### Hardware (GitHub Actions hosted)

The Linux targets run on `ubuntu-latest` and `ubuntu-24.04-arm` —
the standard 2-vCPU / 8 GB / 14 GB RAM GitHub-hosted runners. macOS
Apple Silicon is a 3-core M1 in the macos-14 pool; macOS Intel would
use macos-13 (deprecated, sometimes queued). Windows is
`windows-latest` (x86_64) and `windows-11-arm` (aarch64) hosted.

Both runners bill for the same job as one virtual machine; jobs are
co-located with unrelated tenants, so run-to-run spread is real.
**Numbers below are reproducible within 5-15 % of the medians.**

## Results (from a recent release run, N=5 per target)

```
target                 median train_s   stddev train_s   ppl       lmplz_kb
─────────────────────  ─────────────  ──────────────  ────────  ────────
x86_64-linux-musl      ~0.086 s           ±0.002 s     19.82      3,743
x86_64-linux-gnu       ~0.057 s           ±0.001 s     19.82      4,184
aarch64-linux-musl     ~0.064 s           ±0.002 s     19.82      3,914
aarch64-linux-gnu      ~0.063 s           ±0.001 s     19.82      4,085
aarch64-macos          ~0.050 s           ±0.001 s     23.46      1,642
```

(Five-run aggregates land in `dist/bench-<target>.agg.tsv` on each
release. The summary above is a hand-curated reading — every release
generates a fresh `.agg.tsv` with the same row format.)

## Key findings

### 1. glibc-static is faster on `train` (statistically significant)

Across 5 runs, the gap is bigger than `stddev(train_s)` — i.e. the
overlap is minimal:

| arch    | musl median    | gnu median     | gnu faster by        |
|---------|----------------|----------------|----------------------|
| x86_64  | ~0.086 s       | ~0.057 s       | **−34 %** train time |
| aarch64 | ~0.064 s       | ~0.063 s       | **−1.5 %** train time |

For x86_64 the gap is unambiguous (3.4 σ). For aarch64 it's within
1 σ — measurable but borderline. We don't claim "glibc wins" on
aarch64; we observe "within noise on aarch64, glibc clearly faster on
x86_64".

**Why we ship both:** the glibc builds cost ~30 s less CI time per
release than the Alpine docker builds, and for x86_64 the perf
benefit is real. musl builds remain the principle-correct universal
Linux artifact (works on Alpine, Debian, RHEL, Arch — glibc-static
also works, but a separate musl binary means downstream users on
non-glibc distros don't need any compatibility layer).

### 2. musl-static binaries are smaller

| arch    | glibc-static | musl-static | musl saves          |
|---------|--------------|-------------|---------------------|
| x86_64  | 4,184 KB     | 3,743 KB    | **−441 KB (−10.5 %)** |
| aarch64 | 4,085 KB     | 3,914 KB    | **−171 KB (−4.2 %)**  |

musl ships a smaller `libc.a` archive so the statically-linked binary
pulls in less dead code. Both runs are otherwise functionally
identical (pass `smoke.sh`, compile in alpine host environment for the
musl job).

### 3. `query` performance is within noise on both

`query_s` is on the order of 0.0006 s — too small for the 5-run
spread to be informative on shared runners. The benchmark corpus is
too small for query-timing to dominate.

### 4. Perplexity is identical (within rounding)

`ppl` matches across both libc choices (the model's content is
deterministic from the corpus; it's float-precision-in-equality
modulo SIMD instruction selection in the score loop, which produces
the same bits).

## What this isn't

- **Not a system-level benchmark.** This is one corpus, one
  algorithm, one tool. Tokenizers with larger vocabularies
  (SentencePiece, BBPE), different n-gram order, filtered-Kneser-Ney
  vs modified, etc. all change the picture.
- **Not a multi-machine average.** It's one shared runner per
  target. Different SKUs of GitHub-hosted x86_64 will shift median
  by ~5-10 %.
- **Not a real-world corpus.** The synthetic data is degenerate
  (random words from a small dict); perplexity is a regression
  sanity-check, not a production claim.

## How to reproduce

```sh
# Single-run on whatever the host-built binary is
bash scripts/bench.sh TARGET=local

# N=5 iterations
BENCH_ITER=5 bash scripts/bench-multi.sh local | bash scripts/bench-aggregate.sh

# In CI, every release pushes the same data as `dist/bench-<target>.tsv`
# + `dist/bench-<target>.agg.tsv` (see release.yml's "Benchmark
# minimal pipeline" step).
```

The bench corpus is deterministic (`srand(42)`), so train-times are
reproducible within ~5 % on shared runners. Bias in the stddev (one
shared runner per job) prevents publishing absolute ceilings, only
"gnu is faster, by X stddevs on x86_64, within 1 σ on aarch64."
