# zupix: roadmap

Status: draft 2026-10-30. Implements [design.md](design.md).
Target: v0.1.0, the first CRAN release.
Re-planned 2026-10-31: Stage 10, QOI through qoi.h, inserted after Full CI
by maintainer decision (Wuffs decodes QOI wrongly; D1 amended), and v0.1.0
readiness renumbered to Stage 11. Stage 10 is `full` and waits for a green
full run on its merge commit, as Full CI does, so Full CI's result carries
over to the code readiness starts from.
Tracking: [v0.1.0 (#1)](https://github.com/pedrobtz/zupix/issues/1), with one
sub-issue per stage;
[CRAN-submission (#13)](https://github.com/pedrobtz/zupix/issues/13).

The design's stages (§11) are renumbered here. Its Stage 0 splits into
Stage 0 (identity) and Stage 1 (all four upstreams vendored and gated
together, so every CRAN compiled-code risk surfaces first). Its Stages 1
to 6 become 2 to 7. Its Stage 7 splits into Stage 8 (documentation) and
Stage 10 (readiness), around a new Stage 9, Full CI.

## Stages

| Stage | Title | CI | Issue | Pull request | Done |
| --- | --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | quick | [#2](https://github.com/pedrobtz/zupix/issues/2) | [#15](https://github.com/pedrobtz/zupix/pull/15) | 2026-10-30 |
| 1 | [Vendored codecs and the Wuffs gate](#stage-1--vendored-codecs-and-the-wuffs-gate) | full | [#3](https://github.com/pedrobtz/zupix/issues/3) | [#16](https://github.com/pedrobtz/zupix/pull/16) | 2026-10-30 |
| 2 | [Decoding PNG and QOI](#stage-2--decoding-png-and-qoi) | full | [#4](https://github.com/pedrobtz/zupix/issues/4) | [#17](https://github.com/pedrobtz/zupix/pull/17) | 2026-10-30 |
| 3 | [JPEG, WebP and metadata](#stage-3--jpeg-webp-and-metadata) | full | [#5](https://github.com/pedrobtz/zupix/issues/5) | [#18](https://github.com/pedrobtz/zupix/pull/18) | 2026-10-30 |
| 4 | [Lossless encoders](#stage-4--lossless-encoders) | quick | [#6](https://github.com/pedrobtz/zupix/issues/6) | [#19](https://github.com/pedrobtz/zupix/pull/19) | 2026-10-30 |
| 5 | [Lossy encoders and metadata embedding](#stage-5--lossy-encoders-and-metadata-embedding) | quick | [#7](https://github.com/pedrobtz/zupix/issues/7) | [#20](https://github.com/pedrobtz/zupix/pull/20) | 2026-10-30 |
| 6 | [C table](#stage-6--c-table) | full | [#8](https://github.com/pedrobtz/zupix/issues/8) | [#21](https://github.com/pedrobtz/zupix/pull/21) | 2026-10-30 |
| 7 | [Conformance, hostile input and fuzzing](#stage-7--conformance-hostile-input-and-fuzzing) | quick | [#9](https://github.com/pedrobtz/zupix/issues/9) | [#22](https://github.com/pedrobtz/zupix/pull/22) | 2026-10-30 |
| 8 | [Documentation and benchmarks](#stage-8--documentation-and-benchmarks) | quick | [#10](https://github.com/pedrobtz/zupix/issues/10) | [#23](https://github.com/pedrobtz/zupix/pull/23) | 2026-10-31 |
| 9 | [Full CI](#stage-9--full-ci) | full | [#11](https://github.com/pedrobtz/zupix/issues/11) | [#24](https://github.com/pedrobtz/zupix/pull/24) | 2026-10-31 |
| 10 | [QOI through qoi.h](#stage-10--qoi-through-qoih) | full | [#25](https://github.com/pedrobtz/zupix/issues/25) | [#26](https://github.com/pedrobtz/zupix/pull/26) | 2026-10-31 |
| 11 | [v0.1.0 readiness](#stage-11--v010-readiness) | full | [#12](https://github.com/pedrobtz/zupix/issues/12) | [#62](https://github.com/pedrobtz/zupix/pull/62) | 2026-10-31 |

## Stage 0 — Package identity

**Issue.** [#2](https://github.com/pedrobtz/zupix/issues/2), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `quick`.

**Goal.** The package says what it is, and CI runs on every pull request
in under five minutes.

**Work.**

- `DESCRIPTION`: real `Title` and `Description` from design §1;
  `Authors@R` with `cre`, `aut` and `cph`; `Depends: R (>= 4.1)`;
  `Language: en-GB` (design §3). Vendored copyright holders come in
  Stage 1.
- `.Rbuildignore` with every entry `CLAUDE.md`'s "Working with skills"
  lists (already done by `pkg-init`; confirm).
- `R-CMD-check.yaml`: add the `runners` input with the default four rows
  plus `{"os": "windows-latest", "r": "devel"}`.
- `coverage.yaml`: pin `coverage.yml` to the commit `v1` points at, with
  the tag in a comment (it holds a write token).
- `CLAUDE.md` (written by `pkg-init` on 2026-10-30; commit it).

**Exit criteria.**

- `R CMD check` passes on the quick r-actions profile with no NOTE other
  than "New submission".
- Every quick-profile job on the pull request finishes in under five
  minutes.
- `DESCRIPTION` has no scaffold placeholder text.

**Design.** §3.

## Stage 1 — Vendored codecs and the Wuffs gate

**Issue.** [#3](https://github.com/pedrobtz/zupix/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — first compiled code and four vendored libraries; the gate
needs every r-devel container, rchk and the sanitizers`.

**Goal.** All four upstreams compile into `zupix.so` on every CRAN-like leg
with no warning, no pragma and no forbidden symbol, or the roadmap is
re-planned onto the reference decoders (design §4.1, D1).

**Work.**

- `tools/vendor` and `tools/verify-vendor`, following zuhtml: fetch,
  checksum and patch Wuffs (a `v0.4.0-alpha` tag, chosen here: Q1),
  libjpeg-turbo 3.2.x's compression half, the libwebp 1.6.0 encoder
  subset and `qoi.h` at `ffb2d2c` into `src/vendor/`.
- `src/vendor/PROVENANCE` recording tag, commit, sha256 and every patch;
  patches in `tools/patches/`: Wuffs's diagnostic pragmas removed,
  `stderr` writes out of `jerror.c`, `jmemmgr.c` and the libwebp files
  §4.2 names, `NO_GETENV`.
- `WUFFS_CONFIG__MODULES` limited to the modules §4.1 lists; hand-written
  `jconfig.h`, `jconfigint.h` and `jversion.h`; `src/Makevars` and
  `Makevars.win` linking `-lz`; symbol visibility hidden, only
  `R_init_zupix` exported.
- Licences: upstream texts installed under `inst/licenses/` (both of
  Wuffs's, libwebp's `PATENTS`); `inst/COPYRIGHTS`, `LICENSE.note`, `cph`
  entries in `DESCRIPTION` (Q2 settles the wording).
- Workflows: `vendor.yml`, and `native-checks.yml` from r-actions'
  example (sanitizers with ASan, valgrind, lto, gctorture, rchk,
  analyzers, cran-special), with the `full-ci` profile switch.
- `zupix_info()` reporting vendored versions, commits, patches, zlib's
  version and whether Wuffs's SIMD is compiled.
- A CI step running `nm` on the built objects that fails on `stdout`,
  `stderr`, `printf`, `fprintf`, `abort`, `exit`, `rand` and `getenv`.
- Recorded in this roadmap: tarball size, Wuffs's compile time on the
  slowest leg, and the baseline of `png`, `jpeg`, `webp` and `qoi` from
  `tools/run-benchmarks` into `.agents/benchmarks.md` (design §10).

**Recorded 2026-10-30.** Source tarball 1.06 MB. `src/zpx_wuffs.c`
compiles in about 8 s at `-O2` on clang (macOS x86_64); the slowest CI leg
is read from the pull request's run. Baseline in `.agents/benchmarks.md`
for `png`, `jpeg` and `webp`. Deviation: `qoi` is not in the baseline,
because qoi 0.1.0's `writeQOI()` overflows the C stack on a 12-megapixel
image and design §10 sets no QOI target. Further deviations: Wuffs needed a
second patch (an unused function the pragmas had hidden), and libwebp
needs `-DWEBP_EXTERN=extern` so its API is not exported. GCC 16 then
flagged `-Woverflow` in libwebp's `rescaler_sse2.c`, fixed upstream after
1.6.0 (commit 220e3d31), so libwebp carries that commit as a backport
patch. Wuffs itself passed every leg, GCC 16 included: D1's gate holds. The forbidden-symbol
step is `tools/check-symbols` in `hardening.yaml`, with a canary.

**Exit criteria.**

- A full-profile r-actions run is green on the pull request: every runner
  and container leg with 0 warnings and no pragma or compiled-code NOTE,
  rchk and the sanitizers clean.
- `tools/verify-vendor` passes and `vendor.yml` is green.
- The symbol check finds no forbidden symbol and only `R_init_zupix`
  exported.
- `zupix_info()` reports all four upstreams.
- The source tarball is under 3 MB.
- If Wuffs fails the gate and a small recorded patch cannot fix it: this
  roadmap is revised to vendor the reference decoders in Stage 2 before
  the stage closes (design §11, D1).

**Design.** §4, §4.1–4.3, D1–D5, D15, D16.

## Stage 2 — Decoding PNG and QOI

**Issue.** [#4](https://github.com/pedrobtz/zupix/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — the first .Call glue that protects R objects, and the first
decoding of untrusted input: gctorture at step 20, valgrind, ASan`.

**Goal.** `pix_read()` decodes PNG and QOI into the three shapes, with
every limit checked before allocation.

**Work.**

- The R-free core (`zpx_*.c`) returning `zpx_status`; the `.Call` glue in
  `zpx_r.c`, the only R-aware C.
- Sniffing (§6.1); Wuffs PNG and QOI decoding; `pix_read()` with `as`,
  `bits`, `channels` and `format` (§6.2); 16-bit reordering.
- `pix_limits()` and the `zupix.max_*` options; the four checks of §6.5
  in overflow-checked arithmetic, before allocation.
- The condition classes of §8, with a constructor helper.
- `pix_format()`. Input from a path, a raw vector or a connection read
  whole (D18).

**Recorded 2026-10-30.** Deviations, none changing the API: (1) PNG's
channel count needs IHDR's colour type and whether `tRNS` precedes `IDAT`,
which Wuffs's reported pixel format cannot give for 16-bit images, so a
minimal bounded header walk (`src/zpx_png.c`) lands here rather than with
Stage 3's scanners; it also does the IHDR-versus-Wuffs size check of §6.4.
(2) Array outputs go through a row-major RGBA intermediate (R must
transpose to column-major anyway), which §6.6 does not mention; it is
counted in `max_bytes`, and an 8-bit `nativeRaster` still decodes in
place. (3) JPEG and WebP are sniffed but raise `zupix_unsupported_error`
until Stage 3. (4) Q5 is settled by D8: no warning for QOI's `linear`
colourspace. (5) The `qoi` differential test reads from a file, because
qoi 0.1.0's `readQOI()` crashes R on a raw vector, and it leaks the buffer
it decodes into: `tools/valgrind.supp` suppresses exactly that call path
for the valgrind job. (6) The first full run's UBSan leg flagged Wuffs's
generic `wuffs_base__image_decoder` interface (`-fsanitize=function`: it
calls each decoder through a `void *`-self pointer), so zupix calls the
PNG and QOI decoders' functions directly. `x` also accepts URLs,
through the family's shared `R/zu_source.R`, copied verbatim from zuxml.

**Exit criteria.**

- Tests cover every shape, depth and channel rule in §6.2 for PNG and
  QOI, and each `zupix_limit_error` of §6.5, asserted by class.
- A 60-byte PNG declaring 10⁶ × 10⁶ fails with `zupix_limit_error`
  before any pixel buffer is allocated.
- `png::readPNG()` and `qoi::readQOI()` agree exactly with `pix_read()` on
  the stage's test files.
- A full-profile run is green on the pull request.

**Design.** §5, §6.1, §6.2, §6.5, §8, D7, D10, D18.

## Stage 3 — JPEG, WebP and metadata

**Issue.** [#5](https://github.com/pedrobtz/zupix/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — zupix's own container scanners are the package's only
hand-written parsers of untrusted input: ASan, valgrind`.

**Goal.** All four formats decode, and their metadata reads without a
pixel decode.

**Work.**

- Wuffs JPEG and WebP decoding into §6.2's shapes; CMYK and YCCK JPEG to
  RGB (Q3); animated files' first frame with `attr(, "animated")` (D13).
- The bounded scanners of §6.4 for PNG chunks, JPEG markers, RIFF chunks,
  the QOI header and EXIF IFD0; `APP2` ICC reassembly; `iCCP` inflated
  under `max_metadata`.
- `pix_info()` (vectorised over paths, one row per file), `pix_icc()`,
  `pix_exif()`; the scanner-versus-Wuffs size agreement check.
- `orient = TRUE` and `pix_orient()` (§6.3).
- `zupix_unsupported_error` for 12-bit, arithmetic, hierarchical and
  lossless JPEG.

**Recorded 2026-10-30.** Deviations: (1) `jpeg::readJPEG()` does not agree
within 2 levels on colour JPEG; grey is exact. *Corrected 2026-10-30 in
Stage 7:* the cause is not Wuffs. The jpeg package bundles IJG libjpeg 9e,
whose chroma upsampling differs from libjpeg-turbo's; Wuffs matches
libjpeg-turbo's `djpeg` bit for bit on libjpeg-turbo's own test images
and on zupix-written baseline and progressive files. The per-file
tolerance against the jpeg package stays in `test-jpeg-webp.R`, and an
exact test against `djpeg` runs wherever it is installed. (2) Wuffs
decodes still WebP only, so an animated WebP's first frame is rebuilt as
a still file and decoded when it covers the canvas; a smaller first frame
is
`zupix_unsupported_error`, since compositing is not implemented. (3) An
EXIF block that cannot be read gives orientation `NA` rather than an
error, so a damaged EXIF never blocks the pixels; `pix_exif()` still
returns its bytes. (4) `src/zpx_scan.c` replaces Stage 2's minimal PNG
walk. (5) No progressive, CMYK or YCCK JPEG fixture exists yet (neither
the jpeg nor the webp package writes one); Stage 7's corpora cover them.
(6) `pix_info()` applies only `max_metadata` and the input cap, so it can
report an image `pix_read()` would refuse. Beyond the tests, a local
harness ran 20,369 truncations and corruptions of 13 files through the C
core under ASan and UBSan with no finding; Stage 7 turns that into `fuzz/`.

**Exit criteria.**

- Tests cover §6.3 and §6.4 field by field, including `APP2` sequences
  with gaps, repeats and a count of zero, and EXIF offsets outside the
  block or pointing at themselves.
- A header whose scanner and Wuffs sizes disagree fails with
  `zupix_decode_error`.
- `jpeg::readJPEG()` agrees within 2 levels per sample and
  `webp::read_webp()` exactly on lossless files, for the stage's test
  files.
- A full-profile run is green on the pull request.

**Design.** §6.3, §6.4, §6.6, D8, D9, D12, D13.

## Stage 4 — Lossless encoders

**Issue.** [#6](https://github.com/pedrobtz/zupix/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `quick`.

**Goal.** PNG and QOI encode from every shape and round-trip exactly.

**Work.**

- zupix's PNG writer over zlib's `deflate()` and `crc32()`, with the
  minimum-sum-of-absolute-differences filter heuristic, at 8 and 16
  bits, 1 to 4 channels, with `iCCP`, `eXIf`, `sRGB` or `gAMA`.
- The QOI encoder through `qoi.h` with zupix's allocator.
- `pix_write()`, `pix_write_png()`, `pix_write_qoi()`; `file = NULL`
  returns a raw vector; the encoder input rules of §6.2.

**Recorded 2026-10-30.** No deviation in scope. Notes: QOI stores only RGB
or RGBA, so grey and grey-with-alpha widen losslessly and 16-bit input is a
`zupix_input_error`; `pix_write()` recognises `.jpg`, `.jpeg` and `.webp`
and raises `zupix_unsupported_error` for them until Stage 5. PNG `gAMA` is
not written (design §5 gives the writer no gamma argument). As a quick
stage it has no sanitizer CI; locally, 896 encode-and-decode runs over
every size class, depth, channel count and level passed under ASan and
UBSan.

**Exit criteria.**

- PNG and QOI round trips are identical at 8 and 16 bits and every
  channel count, on random images.
- `png::readPNG()` and `qoi::readQOI()` read every file the tests write.
- ICC and EXIF bytes survive a PNG round trip unchanged.
- `R CMD check` passes on the quick r-actions profile.

**Design.** §4.2, §5, D4.

## Stage 5 — Lossy encoders and metadata embedding

**Issue.** [#7](https://github.com/pedrobtz/zupix/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `quick`. libjpeg-turbo's `error_exit` longjmp stays inside
zupix's own encode frame; Stage 9's ASan and valgrind legs confirm it.

**Goal.** JPEG and WebP encode with metadata, and WebP lossless
round-trips.

**Work.**

- `pix_write_jpeg()` through libjpeg-turbo's compressor: quality,
  subsampling, progressive, `APP1` and `APP2` embedding; `error_exit` and
  `output_message` replaced.
- `pix_write_webp()` through the libwebp encoder, lossy and lossless,
  threads off; zupix's own `VP8X`, `ICCP` and `EXIF` chunks (D14).
- Format limits on encode (§6.5) as `zupix_encode_error`.
- PSNR floors per quality recorded for JPEG and lossy WebP.

**Recorded 2026-10-30.** PSNR floors on a smooth 120 x 160 image, 3 dB
under what was measured: JPEG quality 50/75/90/100 at 38/41/44/47 dB, WebP
quality 25/50/75/95 at 34/35/37/43 dB (`test-write-lossy.R`). Decisions
made here, none changing the API: JPEG drops an alpha channel only when
every pixel is opaque and otherwise raises `zupix_input_error`, since
flattening is a colour decision (D10); JPEG and WebP round 16-bit samples
to 8 bits; JPEG always writes optimised Huffman tables. Found: Wuffs
v0.4.0-alpha.12 cannot decode VP8L inside a VP8X container (which zupix's
own lossless WebP with ICC or EXIF is, and which libwebpmux writes), so the
decoder rebuilds such files as simple VP8L (`zpx_meta.webp_rebuild`); this
also fixes reading such files, which Stage 3 could not. Not filed upstream
yet. Locally, 960 JPEG and WebP encode-then-decode runs passed under ASan
and UBSan with libjpeg-turbo and libwebp instrumented, and the hostile
harness passed 36,647 inputs including zupix-written files.

**Exit criteria.**

- Lossless WebP round trips are identical; JPEG and lossy WebP stay above
  their recorded PSNR floor.
- ICC and EXIF bytes survive every encoder unchanged.
- `jpeg::readJPEG()` and `webp::read_webp()` read every file the tests
  write.
- `R CMD check` passes on the quick r-actions profile.

**Design.** §4.2, §5, §9 (round trips), D2, D14.

## Stage 6 — C table

**Issue.** [#8](https://github.com/pedrobtz/zupix/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — the table is called across two shared objects, and only the
sanitizer legs show that no core function longjmps or raises (design §11)`.

**Goal.** Sibling packages can sniff, probe, decode, read metadata and
encode from C.

**Work.**

- `inst/include/zupix.h` (pure C99) and `zupix-r.h` (lazy
  `R_GetCCallable("zupix", "zupix_get_api")`, cached, `NULL` on a version
  mismatch), with `zupix_api_v1` as §7 defines it.
- The table registered in `R_init_zupix`; encoding through the
  `zpx_write_fn` sink.
- `tools/zupixtest`, the fixture package, built and tested in CI on all
  three OSes.
- `test-abi.R`: the full symbol table exports `R_init_zupix` only and no
  `wuffs_`, `jpeg_`, `jinit`, `WebP` or `qoi_` symbol.

**Recorded 2026-10-30.** Decided here, where design §16 left it open: the
per-format option structs (`zpx_png_opts`, `zpx_jpeg_opts`,
`zpx_webp_opts`, `zpx_qoi_opts`, each starting with `struct_size`, `NULL`
for the defaults); `metadata()` selects with `ZPX_META_ICC` and
`ZPX_META_EXIF`; `NULL` limits mean zupix's defaults; `decode()` adds
channels and depth but refuses grey from colour or dropped alpha, as the R
API does. The core now takes its public types from `zupix.h`, so the two
cannot drift. Found and fixed: the JPEG encoder kept its sink-failure flag
in an automatic variable changed between `setjmp()` and `longjmp()`
(indeterminate in C), which the fixture's failing-sink test caught as
`ZPX_ERR_ENCODE` instead of `ZPX_ERR_SINK`; the libjpeg-turbo context now
lives in one heap block. Locally, the table ran 1,056 encode and decode
calls across every format and pixel layout under ASan and UBSan, and
`tools/zupixtest` passed 46 tests on macOS.

**Exit criteria.**

- `zupixtest` resolves the table, decodes, encodes, and gets `NULL` for a
  future ABI version, on Linux, macOS and Windows.
- `zupix.h` compiles standalone as C99.
- `test-abi.R` passes.
- A full-profile run is green on the pull request.

**Design.** §7, D11, D17.

## Stage 7 — Conformance, hostile input and fuzzing

**Issue.** [#9](https://github.com/pedrobtz/zupix/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `quick`. The suites run under ASan and UBSan in Stage 9; the fuzz
targets have their own workflow.

**Goal.** The external corpora, the differential oracles and the fuzzers
cover every decoder and scanner.

**Work.**

- Corpus licences read first (Q6); redistributable files under
  `tests/testthat/`, the rest downloaded in CI only and skipped
  otherwise.
- Conformance: PngSuite, libjpeg-turbo's `testimages`, libwebp's test
  files, the QOI test images.
- Differential: `png`, `jpeg`, `webp`, `qoi` on every file they read,
  with per-file tolerances recorded for JPEG.
- Hostile: a file per limit; every corpus file truncated at each of its
  first 4,096 offsets and 64 random later ones.
- `fuzz/` in zukomp's layout: `build.sh`, `run.sh`, `replay.sh`,
  `corpus/seed/`, `corpus/regressions/`; the targets §9 lists and a
  canary; `fuzz.yml` calling r-actions.
- Lossless round trips on 10⁴ random images per format and depth, gated
  behind an environment variable so CRAN runs a small sample.

**Recorded 2026-10-30.** Q6 answered (design §15): PngSuite and
libjpeg-turbo's test images are committed (`tools/make-corpus.sh`);
libwebp-test-data (pinned commit) and the QOI test images (pinned sha256)
are downloaded in CI only. Results: all 161 valid PngSuite files decode
exactly as `png::readPNG()` does, after a fix found here (a `tRNS` key's
pixels now keep the key colour the file holds, where Wuffs wrote
transparent black), and all 14 corrupt ones fail with the class their
names predict. Wuffs matches libjpeg-turbo's `djpeg` exactly, which
corrects Stage 3's account of the jpeg package's differences (the jpeg
package bundles IJG libjpeg 9e). All 131 libwebp-test-data files decode;
123 match libwebp exactly, alpha is exact everywhere, and 8 lossy files
differ in colour by up to 32 levels although VP8 is specified bit-exactly:
a Wuffs v0.4.0-alpha.12 VP8 bug. The QOI `edgecase` image decodes with
10,272 transparent pixels the reference decoder makes opaque: a Wuffs QOI
bug (a run's pixel is not entered into the colour index). Both are pinned
in `test-conformance.R` and left for the maintainer (open questions
below). Hostile: the full design §9 truncation set and 256 byte flips per
file run clean in about 2 minutes (`ZUPIX_HOSTILE=full`); CRAN runs a
sample. `fuzz/` has eight targets, a canary and a replay driver; fuzz.yaml
runs each for 60 s on a pull request and 10 minutes nightly or with the
`fuzz-long` label. Deviation: the hostile suite runs in full in
`hardening.yaml`, not under ASan in the full profile; under ASan it is the
fuzz targets (libFuzzer, ASan, UBSan) and `fuzz/replay.sh` that cover
truncated and corrupt input.

**Exit criteria.**

- Every PngSuite file decodes as `png` does or fails with the class its
  name predicts.
- Every hostile file and every truncation fails with its class or
  succeeds; none crashes.
- Each fuzz target has run 10 minutes under ASan and UBSan with nothing
  open, and the canary fails.
- `R CMD check` passes on the quick r-actions profile, and the suite
  stays inside the CRAN time budget.

**Design.** §9, §12.

## Stage 8 — Documentation and benchmarks

**Issue.** [#10](https://github.com/pedrobtz/zupix/issues/10), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `quick`.

**Goal.** A user can learn the package from its README and article, and
§10's targets are measured.

**Work.**

- `README.Rmd` (the `pkg-readme` skill), carrying the IJG licence's
  acknowledgement of the Independent JPEG Group's work.
- One article on shapes, metadata, limits and calling the C table.
- `tools/run-benchmarks` against `png`, `jpeg`, `webp` and `qoi` into
  `.agents/benchmarks.md`.
- pkgdown reference index grouped by decoding, metadata and encoding.

**Recorded 2026-10-31.** Every design §10 target is met but one, PNG
decode at 1.15× `png::readPNG()` against "at least as fast"; it is
rewritten in design §10 to within 1.2×, with the reason (Wuffs's decode
matches libpng; the rest is reading the file into memory first).
Measuring found three real costs, now fixed: the PNG writer used zlib's
default strategy rather than libpng's `Z_FILTERED` (2.7× slower, now
1.26×); encoder input was validated and converted by whole-array passes
in R (about 1 s and 800 MB on 12 megapixels), now done in the C pass that
interleaves; and `pix_read()` copied its result when setting `dim`, and
read files in chunks. The first measurements were also wrong for a reason
worth keeping: `R CMD INSTALL .` reused `-O0` objects `load_all()` had left
in `src/`, so `tools/run-benchmarks` now installs from a built tarball.
The README (`README.Rmd`) carries the Independent JPEG Group
acknowledgement; the article is `vignettes/articles/zupix.Rmd`, a pkgdown
article, not an installed vignette. It states the Wuffs differences
Stage 7 found.

**Exit criteria.**

- Every §10 target is recorded; a missed target is met or rewritten in
  design.md with its reason.
- The pkgdown site builds.
- `R CMD check` passes on the quick r-actions profile.

**Design.** §10, §12.

## Stage 9 — Full CI

**Issue.** [#11](https://github.com/pedrobtz/zupix/issues/11), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — always`.

**Goal.** No new features. The full r-actions profile is green on the
default branch's code.

**Work.**

- Run the full profile (`full-ci` label) and fix everything it finds:
  gctorture at step 20, valgrind, ASan, every platform leg, `nosuggests`,
  `nold`, cran-special.
- Fix the failures collected as comments on this stage's issue.

**Recorded 2026-10-31.** The full run on the last feature merge (`124cb88`)
was green on every job it ran: all seven platform legs and three CRAN-like
containers at 0/0/0 or Status OK, ASan and UBSan (gcc, clang), valgrind,
gctorture at step 20, rchk, LTO, the analyzers, cran-special, abi, fuzz
and hardening. No failures had been collected on this stage's issue: every
full-only failure was fixed inside its full-tier stage. What it did not
run: `nosuggests` and `nold`, which r-cmd-check.yml runs only when the
caller turns them on. They are on now, and `tests/testthat.R` stands down
when testthat is absent, as CRAN's no-Suggests check requires.

**Exit criteria.**

- A full-profile run is green on the pull request and on the merge
  commit.

**Design.** §12.

## Stage 10 — QOI through qoi.h

**Issue.** [#25](https://github.com/pedrobtz/zupix/issues/25), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — a decoder of untrusted input changes: ASan, valgrind, and
the fuzz targets; inserted after Full CI, so it also waits for a green full
run on its merge commit`.

**Goal.** QOI decodes exactly as the format's reference decoder does.

**Work.**

- Decode QOI through `qoi.h`'s `qoi_decode()` (already vendored for
  encoding), after a bounded pass that checks the chunk stream yields every
  pixel before the end marker, since `qoi_decode()` repeats the last pixel
  of a short stream rather than failing.
- Count `qoi_decode()`'s own output buffer against `max_bytes`.
- Drop Wuffs's QOI module from the build.
- Design D1 amended; `zupix_info()`, `CLAUDE.md`, the README and the
  article updated; the fuzz targets link `zpx_qoi.c`.

**Exit criteria.**

- Every QOI test image decodes as `qoi::readQOI()` does, alpha included
  (`edgecase.qoi` too), and as its PNG twin.
- A truncated QOI is a `zupix_decode_error`, never a partial image.
- A full-profile run is green on the pull request and on the merge commit.

**Design.** D1 (amended), §6.5.

**Recorded 2026-10-31.** Locally: the suite passes with both
download-only corpora, `edgecase.qoi` exact in every channel; 18,474
truncations and corruptions of QOI files ran clean through the new path
under ASan and UBSan; `fuzz/replay.sh` is clean.

## Stage 11 — v0.1.0 readiness

**Issue.** [#12](https://github.com/pedrobtz/zupix/issues/12), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zupix/issues/1).

**CI.** `full — always`.

**Goal.** Only the submission itself is left.

**Work.**

- `Version: 0.1.0` and the matching `NEWS.md` heading.
- `cran-comments.md` listing the r-actions CI legs as test environments.
- The `pkg-critical-review` skill, with its blocking and required
  findings fixed; then the `pkg-cran-review` skill, with every finding
  resolved.
- `urlchecker::url_check()` and `spelling::spell_check_package()` clean.

**Exit criteria.**

- Every §12 acceptance criterion holds, including no `SystemRequirements`,
  no `Imports`, no pragma NOTE and a tarball under 3 MB.
- A full-profile r-actions run is green on the release commit.

**Design.** §12.

## After 0.1.0

From design §14, in the expected order:

- TIFF in v0.2.0 (D6): libtiff, `as = "values"`, `pix_decode_ccitt()`.
  It waits so that libtiff, the one hand-written decoder, is fuzzed and
  limit-checked before it ships.
- Decode-only formats Wuffs already has: GIF (first frame), BMP, PNM,
  TGA.
- Every frame of APNG, animated WebP and GIF.
- Streaming PNG decode and connections as output.
- 12-bit JPEG; lossless JPEG rotation.
- AVIF and JPEG XL, more likely as satellite packages.

## Open questions

- **D1 to D18 are all (C).** The maintainer confirms or overturns them,
  D1 above all, before Stage 1 starts.
- **Q1** (Stage 1): which Wuffs `v0.4.0-alpha` tag, and does it pass the
  gate?
- **Q2** (Stage 1): the `License:` and `LICENSE.note` wording for Wuffs's
  MIT-and-Apache-2.0 terms.
- **Q3** (Stage 3): is RGB enough for CMYK JPEG, or does zupix need a
  raw-sample path?
- **Q4** (Stage 2): are the default limits right?
- **Q5** (Stage 2): should `pix_read()` warn on QOI's `linear`
  colourspace?
- **Q6** (Stage 7): the corpus licences.
- **Q7** (Stage 10): is v0.1.0 a CRAN submission? This roadmap assumes
  `CRAN intent: Planned`.
- **Wuffs decoding bugs** (Stages 5 and 7). *Decided 2026-10-31 by the
  maintainer:* QOI moves to `qoi.h` (Stage 10); lossy WebP stays on Wuffs
  for v0.1.0, its differences documented and pinned; the VP8X/VP8L failure
  stays worked around. Filed 2026-10-31: google/wuffs
  [#209](https://github.com/google/wuffs/issues/209) (QOI run index),
  [#210](https://github.com/google/wuffs/issues/210) (VP8L in VP8X) and
  [#211](https://github.com/google/wuffs/issues/211) (lossy VP8), and the
  qoi package's crashes as JohannesFriedrich/qoi4R
  [#10](https://github.com/JohannesFriedrich/qoi4R/issues/10).
