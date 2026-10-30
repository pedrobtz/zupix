#!/bin/sh
# Writes the redistributable conformance corpora under tests/testthat/corpus/
# from pinned archives, checksums verified. Run from the package root after
# changing a pin; commit the output. Design §9, Stage 7.
#
#   pngsuite/       PngSuite 2017-07-19, every file, with its licence
#                   ("Permission to use, copy, modify and distribute these
#                   images for any purpose and without fee is hereby
#                   granted." Willem van Schaik).
#   libjpeg-turbo/  the JPEGs from libjpeg-turbo 3.2.1's testimages/ (IJG
#                   License; monkey12.jpg's embedded sRGB2014.icc under the
#                   ICC's terms), with that directory's LICENSE.txt.
#
# libwebp-test-data and the QOI test images carry no licence that allows
# redistribution, so they are not committed: hardening.yaml downloads them
# and runs the conformance tests against them (ZUPIX_CORPUS).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
. tools/vendor/common.sh
OUT=tests/testthat/corpus
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fetch() { # url sha256 dest
    curl -fsSL --retry 3 -o "$3" "$1"
    got=$(sha256_of "$3")
    [ "$got" = "$2" ] || { echo "sha256 mismatch for $1: $got" >&2; exit 1; }
}

rm -rf "$OUT/pngsuite" "$OUT/libjpeg-turbo"
mkdir -p "$OUT/pngsuite" "$OUT/libjpeg-turbo"

fetch http://www.schaik.com/pngsuite/PngSuite-2017jul19.tgz \
    0294b244c95a8342c01b00010cf34abdcabc7c6a34fd0fe1bd963917537bfdc8 \
    "$TMP/pngsuite.tgz"
tar -xzf "$TMP/pngsuite.tgz" -C "$OUT/pngsuite"
rm -f "$OUT/pngsuite/PngSuite.png" "$OUT/pngsuite/PngSuite.README"

fetch https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.1/libjpeg-turbo-3.2.1.tar.gz \
    c27ad72a68da151177929aa969ae773a2da5ac2af9ce946079314fdac8cece7f \
    "$TMP/ljt.tar.gz"
tar -xzf "$TMP/ljt.tar.gz" -C "$TMP" --strip-components=1 \
    libjpeg-turbo-3.2.1/testimages
for f in testorig.jpg testimgari.jpg testimgint.jpg monkey12.jpg LICENSE.txt; do
    cp "$TMP/testimages/$f" "$OUT/libjpeg-turbo/$f"
done
cp "$TMP/README.ijg" "$OUT/libjpeg-turbo/README.ijg" 2>/dev/null ||
    tar -xzf "$TMP/ljt.tar.gz" -C "$OUT/libjpeg-turbo" --strip-components=1 \
        libjpeg-turbo-3.2.1/README.ijg

echo "pngsuite: $(ls "$OUT/pngsuite" | wc -l | tr -d ' ') files;" \
     "libjpeg-turbo: $(ls "$OUT/libjpeg-turbo" | wc -l | tr -d ' ') files"
du -sh "$OUT"
