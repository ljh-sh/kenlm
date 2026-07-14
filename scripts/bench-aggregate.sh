#!/usr/bin/env bash
# Read N raw TSV rows of bench output (one per run, emitted by
# bench-multi.sh) from stdin and emit a stats table — min / median /
# mean / stddev / max per numeric column.
#
# Input format (column order matches bench.sh):
#   target train_s arpa_kb trim_s build_s bin_kb query_s ppl lmplz_kb
# "NA" cells (e.g. query_s on Windows when kenlm's toolchain doesn't
# emit a `real:` line) are skipped from numeric stats.
#
# Output: TSV rows of (target, stat, train_s, arpa_kb, trim_s,
# build_s, bin_kb, query_s, ppl, lmplz_kb) where stat ∈ {min, median,
# mean, stddev, max}.

set -eu

awk -F'\t' '
BEGIN {
    OFS = "\t"
    COLS = "train_s arpa_kb trim_s build_s bin_kb query_s ppl lmplz_kb"
    n_cols = split(COLS, _c, " ")
    print "target", "stat", COLS
}

{
    n = split($0, fields, "\t")
    target = fields[1]
    if (!(target in seen)) {
        seen[target] = 1
        targets[++n_targets] = target
    }
    for (i = 1; i <= n_cols; i++) {
        key = target SUBSEP i
        vals[key] = vals[key] " " fields[i+1]
    }
}

function qsort(a, n,    i, j, t) {
    for (i = 2; i <= n; i++)
        for (j = i; j >= 2 && a[j-1] > a[j]; j--) { t = a[j-1]; a[j-1] = a[j]; a[j] = t }
}
function split_numbers(s, a,    n, i, tok) {
    n = 0; tok = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == " ") {
            if (tok != "" && tok != "NA") a[++n] = tok+0
            tok = ""
        } else tok = tok c
    }
    if (tok != "" && tok != "NA") a[++n] = tok+0
    return n
}
function median(s,    n, a) { n = split_numbers(s, a); if (n == 0) return "NA"; qsort(a, n); return (n % 2 == 1) ? a[(n+1)/2] : (a[n/2] + a[n/2+1]) / 2 }
function getmin(s,    n, a, i, m) { n = split_numbers(s, a); if (n == 0) return "NA"; m = a[1]; for (i = 2; i <= n; i++) if (a[i] < m) m = a[i]; return m }
function getmax(s,    n, a, i, m) { n = split_numbers(s, a); if (n == 0) return "NA"; m = a[1]; for (i = 2; i <= n; i++) if (a[i] > m) m = a[i]; return m }
function mean_stdev(s,    n, a, i, sum, mean, sumsq, sd) {
    n = split_numbers(s, a); if (n == 0) return "NA NA"
    sum = 0; sumsq = 0
    for (i = 1; i <= n; i++) { sum += a[i]; sumsq += a[i]*a[i] }
    mean = sum / n
    sd = (n > 1) ? sqrt((sumsq - n*mean*mean) / (n-1)) : 0
    return mean " " sd
}
function fmt(s) { return (s == "NA") ? "NA" : sprintf("%.4f", s+0) }

END {
    for (t = 1; t <= n_targets; t++) {
        target = targets[t]
        printf "%s\tmin", target
        for (i = 1; i <= n_cols; i++) printf OFS "%s", fmt(getmin(vals[target SUBSEP i]))
        printf "\n"

        printf "%s\tmedian", target
        for (i = 1; i <= n_cols; i++) printf OFS "%s", fmt(median(vals[target SUBSEP i]))
        printf "\n"

        printf "%s\tmean", target
        for (i = 1; i <= n_cols; i++) {
            split(mean_stdev(vals[target SUBSEP i]), ms, " ")
            printf OFS "%s", fmt(ms[1])
        }
        printf "\n"

        printf "%s\tstddev", target
        for (i = 1; i <= n_cols; i++) {
            split(mean_stdev(vals[target SUBSEP i]), ms, " ")
            printf OFS "%s", fmt(ms[2])
        }
        printf "\n"

        printf "%s\tmax", target
        for (i = 1; i <= n_cols; i++) printf OFS "%s", fmt(getmax(vals[target SUBSEP i]))
        printf "\n"
    }
}
'
