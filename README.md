# Perl vs ooRexx benchmark

Run on macOS with Perl and ooRexx (including `rxregexp.cls`):

```sh
./benchmark.sh
```

The default is 11 measured runs plus one warm-up per language and workload.
Measured runs alternate which language executes first. Every workload result
is checked against an expected value. Failures stop the benchmark.

```sh
RUNS=3 STARTUP_RUNS=20 MEMORY_SIZES='10000 100000' ./benchmark.sh
```

`PERL` and `REXX` can select interpreter executables. The runner reports versions,
architecture and macOS version. Use an idle machine on AC power. Compare individual
workloads; do not combine them into a language score.

## Timing

Each workload reports the median and interquartile range (IQR, interpolated 25th
and 75th percentiles) of elapsed, user CPU and system CPU time. Timing includes
interpreter startup, loading the script, processing and teardown. The warm-up
warms system caches; each measurement still uses a fresh interpreter.

The separate startup measurement executes minimal scripts printing `ok` in both
languages. It includes shell/process creation overhead and uses batches of 200
starts by default. It is not subtracted from workload times. macOS `time -p` reports times at
centisecond resolution; three printed decimal places do not imply millisecond
accuracy, and `0.000` for tiny workloads means below that reporting resolution.

Workloads:

- `cpu`: 5 million remainder/add iterations. ooRexx uses 15 decimal digits,
  enough for the exact integer results here; Perl uses its native numbers.
  This compares their different numeric models, not identical arithmetic engines.
- `strings`: 1 million uppercase/substring/length operations on one short string.
- `array`: construct and scan 200,000 strings of 48 bytes each. ooRexx reserves
  array capacity in advance; Perl grows its array. Formatting is included.
- `lookup`: construct 100,000 keyed entries and perform 2 million lookups.
  Key generation and arithmetic are included.
- `parse`: 1 million parses of a fixed pipe-delimited record, using idiomatic
  Perl `split` and ooRexx `PARSE VAR`.
- `io`: write and immediately read 200,000 lines (12,000,000 bytes). This includes
  formatting, stream handling and filesystem caching; it is not a disk benchmark.
- `regex`: 1 million matches with a precompiled expression and two fixed inputs.
  Separate programs keep regex loading out of the other workloads. The result
  check covers these inputs, not general equivalence of the regex engines.

## Memory

RSS is the median of each process's **peak resident memory**, in MiB (2^20 bytes),
with IQR. It includes interpreter, data, allocator reserves and temporary objects.
The `noop` workload provides a baseline using the same workload dispatcher.

The memory section repeats array construction/scanning and table construction
at 10,000, 100,000 and 1,000,000 entries. Objects remain referenced through the
validation output. Compare growth across sizes to estimate additional memory
per entry; subtracting the baseline alone is only an approximation.

These are process peaks, not heap snapshots or measurements of memory returned
after freeing objects. Short-lived string tests mostly indicate runtime baseline
and transient allocation rather than retained data size. The array's 48-byte
record expectation applies up to 100,000,000 entries (eight-digit record IDs).

## Remaining extensions

For a deeper comparison, add varied input lengths and regex cases, missing-key
lookups, and repeated allocation/freeing in a long-running process. A representative application workload should complement
these microbenchmarks.

## Internal phase measurements

The runner also executes `bench_phases.pl` and `bench_phases.rexx`. To run only
this section (no privileged `time -l` system queries needed):

```sh
PHASES_ONLY=1 ./benchmark.sh
```

Each process measures six sequential phases using Perl `Time::HiRes::time`
and ooRexx `TIME('R')` / `TIME('E')`. The timer surrounds the processing only;
output and result validation happen after the timer is read. Each language gets
one discarded process run, followed by the configured measured process runs in
alternating order. Phase results report median and IQR to six decimal places;
printed precision does not guarantee timer accuracy. These are elapsed times,
not CPU times. Timer calls and loop overhead are included; no overhead is
subtracted.

| Phase | Work inside the timer | Checked result |
| --- | --- | --- |
| `records` | Format 200,000 strings into a source array | 200,000 records |
| `array_build` | Allocate and populate a second array from existing strings | 200,000 entries |
| `array_scan` | Traverse that array 20 times and sum string lengths | 192,000,000 |
| `keys` | Generate and retain 100,000 keys `K1` through `K100000` | 100,000 keys |
| `table_build` | Allocate a hash/Table and insert the prepared keys and integer values | 100,000 entries |
| `lookup` | Traverse the prepared keys 20 times, look up values and sum them | 100,001,000,000 |

Array construction assigns existing strings; it does not create new independent
copies of their contents. ooRexx preallocates array capacity, while Perl grows
its arrays. Both scan loops use native iteration. Lookup includes iteration and
addition but excludes string formatting and modulo. It measures successful
lookups with repeatedly reused keys; it does not measure missing keys or fresh
keys on each access. Later phases inherit the state and memory-management history
of earlier phases, including any collection work triggered inside a timer.

All phase programs retain their source data. Their memory footprint therefore
must not be compared with the isolated array/table memory tests. The phase
section deliberately reports no per-phase RSS; the existing separate processes
remain the memory measurements.


## Separate writing and reading

The runner additionally executes isolated internal I/O timers in `bench_io.pl`
and `bench_io.rexx`. Run just these measurements with:

```sh
IO_ONLY=1 ./benchmark.sh
```

Both phases process the same 200,000 ASCII records, totalling 12,000,000 bytes
including LF line endings. Each language and phase gets a discarded warm-up,
then the measured runs alternate language order in fresh processes.

- `io_write`: all records are formatted and held in memory before timing.
  The timer includes opening a new file, writing each line and closing/flushing
  the stream. Perl records contain the LF passed to `print`; ooRexx `LINEOUT`
  supplies it. Return values are checked. After timing, the runner compares
  every byte against the reference, checking contents and size. The reported
  byte/line counts for writing are declarations verified by that comparison.
- `io_read`: the runner creates a reference file before any measured reads.
  Each process opens it, reads lines, counts lines and bytes, and closes it.
  The runner checks 200,000 lines and 12,000,000 bytes. ooRexx `LINEIN` removes
  the line ending, so its byte count adds one byte per line for this LF fixture.
  The reference is reused and warmed by preparation/validation; this is a
  cached sequential-read workload, not a cold-storage throughput measurement.

Formatting, process startup, output and full-file validation are outside the
internal timers. Looping and API return checks remain inside. No `fsync` or
cache eviction is requested: write completion does not promise durable storage.
The write and read timers are independent; the read phase uses the reference,
not a file produced by a timed writer. The old combined `io` test remains for
comparison. Internal I/O results report elapsed seconds and IQR to six decimal
places, without per-phase RSS because preformatted buffers affect process peaks.
