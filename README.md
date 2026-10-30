# Perl vs ooRexx benchmark v5

Changes from v4:

- Changed do loops from 'do i = 1 to xxxxx' to 'do i = 1 for xxxxxx' as this was
  said to perform better in old REXX


Changes from v3:

- Added `parse`: 1,000,000 parses of a pipe-delimited record.
  - Perl uses idiomatic `split`.
  - ooRexx uses idiomatic `PARSE VAR`.
- Added `regex`: 1,000,000 matches against a precompiled expression.
  - Perl uses `qr//`.
  - ooRexx uses the supplied `RegularExpression` class from `rxregexp.cls`.
- The regex programs are separate so `::requires "rxregexp.cls"` does not
  increase startup time or memory usage of the existing ooRexx workloads.
- Existing CPU, strings, Array, Table lookup and I/O tests are unchanged.

Run:

    ./benchmark.sh

Optional:

    RUNS=11 ./benchmark.sh
