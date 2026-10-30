#!/bin/sh
# Builds every libFuzzer target, and the canary, into fuzz/build/. Needs a
# clang with libFuzzer (Linux, or Homebrew LLVM on macOS): CC=... to choose.
#
#   fuzz/build.sh
set -eu
cd "$(dirname "$0")/.."
. fuzz/targets.sh
CC=${CC:-clang}
mkdir -p fuzz/build
for t in $TARGETS fuzz_canary; do
    # shellcheck disable=SC2046,SC2086
    $CC $FUZZ_CFLAGS -fsanitize=fuzzer,address,undefined \
        "fuzz/$t.c" $(sources_for "$t") -lz -o "fuzz/build/$t"
    echo "built fuzz/build/$t"
done
