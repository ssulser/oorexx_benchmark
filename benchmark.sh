#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-7}"
STARTUP_RUNS="${STARTUP_RUNS:-200}"
PERL="${PERL:-perl}"
REXX="${REXX:-rexx}"

HERE="$(cd "$(dirname "$0")" && pwd)"
PERL_BENCH="$HERE/bench.pl"
REXX_BENCH="$HERE/bench.rexx"
PERL_REGEX="$HERE/bench_regex.pl"
REXX_REGEX="$HERE/bench_regex.rexx"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This runner expects macOS /usr/bin/time -lp." >&2
    exit 1
fi

command -v "$PERL" >/dev/null || { echo "Perl not found: $PERL" >&2; exit 1; }
command -v "$REXX" >/dev/null || { echo "ooRexx not found: $REXX" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/perl-rexx-bench.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

median() {
    sort -n "$1" | awk '
        { a[NR]=$1 }
        END {
            if (NR == 0) exit 1
            if (NR % 2) print a[(NR+1)/2]
            else print (a[NR/2] + a[NR/2+1]) / 2
        }'
}

measure() {
    local lang="$1"
    local test="$2"
    shift 2
    local -a cmd=( "$@" )

    local realf="$TMP/${lang}-${test}.real"
    local userf="$TMP/${lang}-${test}.user"
    local rssf="$TMP/${lang}-${test}.rss"
    : >"$realf"; : >"$userf"; : >"$rssf"

    rm -f "$TMP/io.data"
    "${cmd[@]}" >/dev/null

    for ((run=1; run<=RUNS; run++)); do
        rm -f "$TMP/io.data"
        local t="$TMP/time.out"
        /usr/bin/time -lp "${cmd[@]}" >/dev/null 2>"$t"
        awk '$1=="real" {print $2}' "$t" >>"$realf"
        awk '$1=="user" {print $2}' "$t" >>"$userf"
        awk '/maximum resident set size/ {print $1}' "$t" >>"$rssf"
    done

    local real user rss rss_mb
    real="$(median "$realf")"
    user="$(median "$userf")"
    rss="$(median "$rssf")"
    rss_mb="$(awk -v b="$rss" 'BEGIN { printf "%.1f", b / 1048576 }')"

    printf "%-8s %-10s %10.3f %10.3f %12.1f\n" \
        "$lang" "$test" "$real" "$user" "$rss_mb"
}

startup() {
    local lang="$1"
    local command_string="$2"
    local f="$TMP/startup-${lang}.real"
    : >"$f"

    for ((run=1; run<=RUNS; run++)); do
        local t="$TMP/startup-time.out"
        /usr/bin/time -p /bin/bash -c \
            "for ((i=0; i<$STARTUP_RUNS; i++)); do $command_string >/dev/null; done" \
            >/dev/null 2>"$t"
        awk '$1=="real" {print $2}' "$t" >>"$f"
    done

    local total per_start
    total="$(median "$f")"
    per_start="$(awk -v t="$total" -v n="$STARTUP_RUNS" \
        'BEGIN { printf "%.3f", (t * 1000) / n }')"

    printf "%-8s %10.3f %12.3f\n" "$lang" "$total" "$per_start"
}

echo "Perl   : $($PERL -e 'printf "%vd\n", $^V' 2>/dev/null || true)"
echo "ooRexx : $($REXX -v 2>&1 | head -1)"
echo "Runs   : $RUNS measured runs + 1 warm-up"
echo

echo "STARTUP OVERHEAD"
echo "($STARTUP_RUNS separate interpreter starts; median of $RUNS measurements)"
printf "%-8s %10s %12s\n" "Language" "total[s]" "ms/start"
printf "%-8s %10s %12s\n" "--------" "--------" "--------"
startup "Perl" "\"$PERL\" -e 1"
startup "ooRexx" "\"$REXX\" \"$REXX_BENCH\" noop"
echo

echo "WORKLOADS"
echo "(median; RSS is peak resident memory of the process)"
printf "%-8s %-10s %10s %10s %12s\n" "Language" "Test" "real[s]" "user[s]" "maxRSS[MB]"
printf "%-8s %-10s %10s %10s %12s\n" "--------" "----------" "----------" "----------" "------------"

for test in cpu strings array lookup parse io; do
    measure "Perl" "$test" "$PERL" "$PERL_BENCH" "$test" "$TMP/io.data"
    measure "ooRexx" "$test" "$REXX" "$REXX_BENCH" "$test" "$TMP/io.data"
done

# Regex is kept in separate programs so loading rxregexp.cls does not affect
# the other ooRexx workload measurements.
measure "Perl" "regex" "$PERL" "$PERL_REGEX"
measure "ooRexx" "regex" "$REXX" "$REXX_REGEX"

echo
echo "Tests:"
echo "  cpu      5,000,000 integer remainder/add operations"
echo "  strings  1,000,000 uppercase + substring + length operations"
echo "  array    allocate and scan 200,000 string records (native arrays)"
echo "  lookup   100,000 keyed entries + 2,000,000 lookups (Perl hash / ooRexx Table)"
echo "  parse    parse 1,000,000 pipe-delimited records (split / PARSE VAR)"
echo "  regex    1,000,000 matches with one precompiled regular expression"
echo "  io       write and read 200,000 text records"
echo
echo "Tip: run on an otherwise idle Mac, on AC power, and repeat the whole"
echo "benchmark a few times. Compare workloads separately rather than"
echo "combining them into one synthetic score."
