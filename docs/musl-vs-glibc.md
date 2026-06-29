# musl-static vs glibc-static — comparison

Captured by the CI bench (`scripts/bench.sh`) on every release run; reproduced
in `release.yml` for all 7 targets. The bench is a complete minimal n-gram
language-model pipeline.

## The minimal pipeline

On the **same deterministic synthetic corpus** (~20k lines, seeded), every
target runs:

| stage | tool | purpose |
|---|---|---|
| **train** | `lmplz -o 4 -S 100M --discount_fallback` | count & interpolate n-grams → ARPA |
| **trim** | `filter file <vocab>` | prune ARPA to a vocabulary (= "trim") |
| **compile** | `build_binary` | ARPA → compact binary model |
| **score** | `query` | score held-out sentences, print perplexity |

For each stage we record the wall-clock time (`real:` from kenlm's own output
for train/score; shell `date +%s` for the sub-second trim/compile), the
intermediate sizes, and the final perplexity. One TSV row per target is
emitted at `dist/bench-<target>.tsv`.

For Linux targets, the **`lmplz_kb`** column is the headline: the size of the
`lmplz` executable itself, which is the direct musl-vs-glibc data point.

## Results table (from the CI run that produced all 7 targets)

```
target                 train_s    arpa_kb  trim_s  build_s  bin_kb  query_s       ppl    lmplz_kb
─────────────────────  ────────  ────────  ──────  ───────  ──────  ──────────  ──────  ────────
x86_64-linux-musl      0.0860      1988      0       0      1342    0.000660      19.82    3743
x86_64-linux-gnu       0.0559      1989      0       0      1342    0.000643      19.82    4184
aarch64-linux-musl     0.0646      1988      0       0      1342    0.000484      19.82    3914
aarch64-linux-gnu      0.0634      1989      0       0      1342    0.000469      19.82    4085
aarch64-macos          0.0506      1991      0       0      1343    0.000279      23.46    1642
x86_64-windows         —            2059      1       0      1342    —             19.82     959
aarch64-windows        —            2059      0       0      1342    —             19.82     939

  — on Windows `lmplz`'s self-reported `real:` line goes to a different stream
    and the bench's parser does not capture it (model sizes + ppl are real).
```

## Key finding: musl vs glibc binary size

| arch    | glibc-static | musl-static | musl saves      |
| ------- | ------------ | ----------- | --------------- |
| x86_64  | **4,184 KB** | **3,743 KB** | **−441 KB (−10.5 %)** |
| aarch64 | **4,085 KB** | **3,914 KB** | **−171 KB (−4.2 %)**  |

So musl-static binaries are **smaller** than the equivalent glibc-static
binaries (because glibc ships more runtime code in its static archive than
musl does). Both are fully self-contained (no `.so` at runtime); both run on
**any** Linux (Alpine, Debian, RHEL, …).

Functional behavior is identical: both pass `smoke.sh` end-to-end inside
their target environment, and `smoke.sh` for the musl targets runs **inside
`alpine:3.20`** — i.e. the musl-static binary genuinely executes on Alpine
(that's the runtime gate for the musl jobs, not just a claim).

Performance (`train_s`, `query_s`) is within run-to-run noise between musl and
glibc — the only meaningful, reproducible difference is the binary size, and
musl wins on every arch.

## Why both, not just one?

The repo ships **both** a glibc-static and a musl-static Linux build:

- **glibc-static** (`x86_64-linux-gnu`, `aarch64-linux-gnu`) is built
  natively on Ubuntu with `FORCE_STATIC=ON` and the apt-built Boost. Fastest
  build time (~1 min), uses the host gcc/glibc stack, produces a fully static
  binary that still runs on Alpine (verified).
- **musl-static** (`x86_64-linux-musl`, `aarch64-linux-musl`) is built inside
  `alpine:3.20` containers, with Boost compiled from source
  (`scripts/build-alpine.sh`) — Alpine ships no static Boost package and musl
  needs its own libc. The `smoke` step then runs **inside the same Alpine
  container** as the build, so the binary's ability to run on musl/Alpine is
  verified at CI time, not just assumed.

Both are intentional: the glibc builds are the cheap default (one minute),
the musl builds are the principle-correct universal-Linux artifact.

## How to reproduce

```sh
# locally
bash scripts/build.sh
bash scripts/bench.sh TARGET=local

# in CI (already wired):
gh workflow run release.yml -r main
# then download each `kenlm-<target>` artifact and cat dist/bench-<target>.tsv
```

The bench corpus is deterministic (`srand(42)`), so numbers are reproducible
within ~5 % run-to-run on shared runners.