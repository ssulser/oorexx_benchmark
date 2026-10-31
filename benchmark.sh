#!/bin/bash
set -euo pipefail
export LC_ALL=C

RUNS="${RUNS:-11}"
STARTUP_RUNS="${STARTUP_RUNS:-200}"
MEMORY_SIZES="${MEMORY_SIZES:-10000 100000 1000000}"
PERL="${PERL:-perl}"
REXX="${REXX:-rexx}"
HERE="$(cd "$(dirname "$0")" && pwd)"
for value in "$RUNS" "$STARTUP_RUNS"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo 'Run counts must be positive integers' >&2; exit 1; }
done
for size in $MEMORY_SIZES; do
    [[ "$size" =~ ^[1-9][0-9]*$ ]] || { echo 'Memory sizes must be positive integers' >&2; exit 1; }
    (( ${#size} <= 9 )) && (( size <= 100000000 )) || { echo 'Memory sizes must not exceed 100000000' >&2; exit 1; }
done
[[ "$(uname -s)" == Darwin ]] || { echo 'Requires macOS /usr/bin/time -lp' >&2; exit 1; }
command -v "$PERL" >/dev/null
command -v "$REXX" >/dev/null
TMP="$(mktemp -d "${TMPDIR:-/tmp}/perl-rexx-bench.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Median and interquartile range (linear interpolation of sample quantiles).
stats() {
    sort -n "$1" | awk -v digits="${2:-3}" '
        {a[NR]=$1}
        function q(p, x, lo) {
            x=1+(NR-1)*p; lo=int(x)
            return a[lo]+(x-lo)*(a[lo+1]-a[lo])
        }
        END {if (!NR) exit 1; printf "%.*f %.*f", digits, q(.5), digits, q(.75)-q(.25)}'
}

command_for() {
    local lang="$1" test="$2" size="$3"
    local exe="$PERL" script="$HERE/bench.pl"
    if [[ "$lang" == ooRexx ]]; then exe="$REXX"; script="$HERE/bench.rexx"; fi
    if [[ "$test" == regex ]]; then
        script="$HERE/bench_regex.pl"
        [[ "$lang" != ooRexx ]] || script="$HERE/bench_regex.rexx"
        CMD=("$exe" "$script")
    else
        CMD=("$exe" "$script" "$test" "$TMP/io.data" "$size")
    fi
}

sample() {
    local lang="$1" test="$2" size="$3" expected="$4" record="$5"
    command_for "$lang" "$test" "$size"
    rm -f "$TMP/io.data"
    if ! /usr/bin/time -lp "${CMD[@]}" >"$TMP/output" 2>"$TMP/time"; then
        cat "$TMP/time" >&2
        exit 1
    fi
    local actual
    actual="$(cat "$TMP/output")"
    if [[ "$actual" != "$expected" ]]; then
        echo "$lang $test: expected '$expected', got '$actual'" >&2
        exit 1
    fi
    if [[ "$record" == yes ]]; then
        awk '$1=="real" {print $2}' "$TMP/time" >>"$TMP/$lang.real"
        awk '$1=="user" {print $2}' "$TMP/time" >>"$TMP/$lang.user"
        awk '$1=="sys" {print $2}' "$TMP/time" >>"$TMP/$lang.sys"
        awk '/maximum resident set size/ {print $1 / 1048576}' "$TMP/time" >>"$TMP/$lang.rss"
    fi
}

pair() {
    local test="$1" size="$2" expected="$3" lang run metric
    for lang in Perl ooRexx; do
        for metric in real user sys rss; do : >"$TMP/$lang.$metric"; done
        sample "$lang" "$test" "$size" "$expected" no
    done
    for ((run=1; run<=RUNS; run++)); do
        if ((run % 2)); then order='Perl ooRexx'; else order='ooRexx Perl'; fi
        for lang in $order; do sample "$lang" "$test" "$size" "$expected" yes; done
    done
    for lang in Perl ooRexx; do
        printf '%-7s %-8s %8s' "$lang" "$test" "$size"
        for metric in real user sys rss; do
            read -r med iqr <<<"$(stats "$TMP/$lang.$metric")"
            printf ' %10s %10s' "$med" "$iqr"
        done
        printf '\n'
    done
}

startup_sample() {
    local lang="$1" record="$2" i
    command_for "$lang" noop 1
    # Both languages execute the same minimal output workload, without loading
    # the workload dispatcher. The shell loop overhead is included in both.
    if [[ "$lang" == Perl ]]; then CMD=("$PERL" "$TMP/noop.pl");
    else CMD=("$REXX" "$TMP/noop.rexx"); fi
    /usr/bin/time -p /bin/bash -c \
        'n="$1"; shift; for ((i=0; i<n; i++)); do "$@" >/dev/null || exit; done' \
        bash "$STARTUP_RUNS" "${CMD[@]}" >/dev/null 2>"$TMP/startup.time"
    if [[ "$record" == yes ]]; then
        awk -v n="$STARTUP_RUNS" '$1=="real" {print $2*1000/n}' "$TMP/startup.time" >>"$TMP/$lang.startup"
    fi
}

phase_sample() {
    local lang="$1" record="$2" exe="$PERL" script="$HERE/bench_phases.pl"
    if [[ "$lang" == ooRexx ]]; then exe="$REXX"; script="$HERE/bench_phases.rexx"; fi
    "$exe" "$script" >"$TMP/phases.out"
    # Check names, order, nonnegative timings and known results before recording.
    awk '
        BEGIN {
            split("records array_build array_scan keys table_build lookup", names)
            split("200000 200000 192000000 100000 100000 100001000000", results)
        }
        NF != 3 || NR > 6 {bad=1; next}
        $1 != names[NR] || $3 != results[NR] {bad=1}
        $2 !~ /^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/ {bad=1}
        END {exit (bad || NR != 6)}
    ' "$TMP/phases.out" || {
        echo "$lang: invalid phase results" >&2
        cat "$TMP/phases.out" >&2
        exit 1
    }
    if [[ "$record" == yes ]]; then
        while read -r phase seconds result; do
            printf '%s\n' "$seconds" >>"$TMP/$lang.phase.$phase"
        done <"$TMP/phases.out"
    fi
}

phases() {
    local lang phase run order
    echo
    echo 'Internal phases: elapsed seconds, excluding startup; median and IQR.'
    echo 'Inputs are prepared before array_build/table_build; scan and lookup use 20 passes.'
    echo 'RSS belongs to the whole process and is not assigned to individual phases.'
    for lang in Perl ooRexx; do
        for phase in records array_build array_scan keys table_build lookup; do
            : >"$TMP/$lang.phase.$phase"
        done
        phase_sample "$lang" no
    done
    for ((run=1; run<=RUNS; run++)); do
        if ((run % 2)); then order='Perl ooRexx'; else order='ooRexx Perl'; fi
        for lang in $order; do phase_sample "$lang" yes; done
    done
    printf '%-7s %-12s %12s %12s\n' Language Phase elapsed_s IQR_s
    for phase in records array_build array_scan keys table_build lookup; do
        for lang in Perl ooRexx; do
            read -r med iqr <<<"$(stats "$TMP/$lang.phase.$phase" 6)"
            printf '%-7s %-12s %12s %12s\n' "$lang" "$phase" "$med" "$iqr"
        done
    done
}

io_sample() {
    local lang="$1" mode="$2" record="$3" exe="$PERL" script="$HERE/bench_io.pl"
    local path="$TMP/io-reference.data"
    if [[ "$lang" == ooRexx ]]; then exe="$REXX"; script="$HERE/bench_io.rexx"; fi
    if [[ "$mode" == write ]]; then
        path="$TMP/io-written.data"
        rm -f "$path"
    fi
    "$exe" "$script" "$mode" "$path" >"$TMP/io-phase.out"
    awk -v phase="io_$mode" '
        NF != 4 || $1 != phase || $3 != 12000000 || $4 != 200000 {bad=1}
        $2 !~ /^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/ {bad=1}
        END {exit (bad || NR != 1)}
    ' "$TMP/io-phase.out" || {
        echo "$lang $mode: invalid I/O result" >&2
        cat "$TMP/io-phase.out" >&2
        exit 1
    }
    if [[ "$mode" == write ]]; then
        # Full byte comparison also verifies size, every record and newlines.
        cmp "$TMP/io-reference.data" "$path" || {
            echo "$lang: written file differs from reference" >&2; exit 1;
        }
    fi
    if [[ "$record" == yes ]]; then
        awk '{print $2}' "$TMP/io-phase.out" >>"$TMP/$lang.io.$mode"
    fi
}

io_phases() {
    local lang mode run order
    echo
    echo 'I/O phases: 200,000 lines / 12,000,000 bytes; internal elapsed seconds.'
    echo 'Write: preformatted records, open/write/close; no fsync durability guarantee.'
    echo 'Read: prepared cached input, open/read/count/close; includes line processing.'
    "$PERL" "$HERE/bench_io.pl" prepare "$TMP/io-reference.data"
    [[ "$(wc -c <"$TMP/io-reference.data" | tr -d ' ')" == 12000000 ]] || exit 1
    for mode in write read; do
        for lang in Perl ooRexx; do
            : >"$TMP/$lang.io.$mode"
            io_sample "$lang" "$mode" no
        done
        for ((run=1; run<=RUNS; run++)); do
            if ((run % 2)); then order='Perl ooRexx'; else order='ooRexx Perl'; fi
            for lang in $order; do io_sample "$lang" "$mode" yes; done
        done
    done
    printf '%-7s %-12s %12s %12s\n' Language Phase elapsed_s IQR_s
    for mode in write read; do
        for lang in Perl ooRexx; do
            read -r med iqr <<<"$(stats "$TMP/$lang.io.$mode" 6)"
            printf '%-7s %-12s %12s %12s\n' "$lang" "io_$mode" "$med" "$iqr"
        done
    done
}

printf 'print "ok\\n";\n' >"$TMP/noop.pl"
printf "say 'ok'\n" >"$TMP/noop.rexx"
echo "Perl: $("$PERL" -e 'printf "%vd", $^V')"
echo "ooRexx: $("$REXX" -v 2>&1 | sed -n '1p')"
echo "Machine: $(uname -sm); macOS: $(sw_vers -productVersion)"
echo "Runs: $RUNS + 1 warm-up per language; alternating measured order"
if [[ "${IO_ONLY:-0}" == 1 ]]; then io_phases; exit 0; fi
if [[ "${PHASES_ONLY:-0}" == 1 ]]; then phases; exit 0; fi
echo 'Startup: minimal scripts; median and IQR in ms/start (includes shell overhead)'
for lang in Perl ooRexx; do
    : >"$TMP/$lang.startup"
    startup_sample "$lang" no
done
for ((run=1; run<=RUNS; run++)); do
    if ((run % 2)); then order='Perl ooRexx'; else order='ooRexx Perl'; fi
    for lang in $order; do startup_sample "$lang" yes; done
done
for lang in Perl ooRexx; do echo "$lang $(stats "$TMP/$lang.startup")"; done

echo
echo 'Workloads: whole-process time; RSS includes interpreter and transient allocations.'
echo 'Each metric shows median and IQR. RSS unit: MiB. noop is dispatcher baseline.'
printf '%-7s %-8s %8s %10s %10s %10s %10s %10s %10s %10s %10s\n' \
    Language Test Size real_s IQR user_s IQR sys_s IQR RSS_MiB IQR
pair noop 1 ok
pair cpu 1 239998917
pair strings 1 20000000
pair array 200000 9600000
pair lookup 100000 100001000000
pair parse 1 37000000
pair io 200000 12000000
pair regex 1 500000

echo
echo 'Memory scaling: retained arrays/tables; time includes construction and validation.'
for size in $MEMORY_SIZES; do
    pair array "$size" "$((size * 48))"
    pair table "$size" "$size"
done

phases

io_phases
