#!/bin/sh
# Replays every target's seeds and regressions once, without libFuzzer,
# under ASan and UBSan: fuzz/replay_main.c supplies main(). Runs anywhere a
# clang with the sanitizers does, macOS included. A crash, a sanitizer
# report or a trap fails it.
#
#   fuzz/replay.sh
set -eu
cd "$(dirname "$0")/.."
. fuzz/targets.sh
CC=${CC:-clang}
OUT=${TMPDIR:-/tmp}/zupix-replay
mkdir -p "$OUT"
for t in $TARGETS; do
    # shellcheck disable=SC2046,SC2086
    $CC $FUZZ_CFLAGS -fsanitize=address,undefined -fno-sanitize-recover=all \
        "fuzz/$t.c" fuzz/replay_main.c $(sources_for "$t") -lz -o "$OUT/$t"
    printf '%-18s ' "$t"
    "$OUT/$t" "fuzz/corpus/seed/$t" "fuzz/corpus/regressions/$t"
done
