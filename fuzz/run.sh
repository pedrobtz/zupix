#!/bin/sh
# Fuzzes every target for SECONDS each (default 60) from its seeds, growing
# fuzz/build/corpus/<target>. First runs the canary, which must crash: a run
# that would have missed a crash is not a passing run.
#
#   fuzz/build.sh && fuzz/run.sh 600
set -eu
cd "$(dirname "$0")/.."
. fuzz/targets.sh
SECS=${1:-60}

mkdir -p fuzz/build/corpus/fuzz_canary
if ./fuzz/build/fuzz_canary -runs=1000000 -seed=1 -only_ascii=1 \
       -artifact_prefix=fuzz/build/fuzz_canary- \
       fuzz/build/corpus/fuzz_canary fuzz/corpus/seed/fuzz_canary \
       >/dev/null 2>&1; then
    echo "CANARY FAILED: the canary target did not crash" >&2
    exit 2
fi
echo "ok  canary crashed"

for t in $TARGETS; do
    mkdir -p "fuzz/build/corpus/$t" "fuzz/corpus/regressions/$t"
    ./fuzz/build/"$t" -max_total_time="$SECS" -dict=fuzz/zupix.dict \
        -artifact_prefix="fuzz/build/$t-" \
        "fuzz/build/corpus/$t" "fuzz/corpus/seed/$t" \
        "fuzz/corpus/regressions/$t"
done
