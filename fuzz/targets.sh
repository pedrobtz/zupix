# Sourced by build.sh, run.sh and replay.sh: each target's harness and the
# core sources it links, and the flags. The decode targets need only the
# R-free decoder; the round trip adds the PNG writer and qoi.h.
DECODE_SRC="src/zpx_decode.c src/zpx_scan.c src/zpx_sniff.c src/zpx_wuffs.c fuzz/fuzz_common.c"
ENCODE_SRC="src/zpx_png_write.c src/zpx_sink.c src/zpx_qoi.c"
TARGETS="fuzz_decode_png fuzz_decode_jpeg fuzz_decode_webp fuzz_decode_qoi fuzz_probe fuzz_exif fuzz_jpeg_icc fuzz_roundtrip"
FUZZ_CFLAGS="-g -O1 -fno-omit-frame-pointer -Iinst/include -Isrc -Ifuzz"
sources_for() {
    case "$1" in
        fuzz_roundtrip) echo "$DECODE_SRC $ENCODE_SRC" ;;
        fuzz_canary) echo "fuzz/fuzz_common.c $DECODE_SRC" ;;
        *) echo "$DECODE_SRC" ;;
    esac
}
