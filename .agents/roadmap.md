# zupix: roadmap

Status: draft 2026-10-30. Implements [design.md](design.md).
Target: v0.1.0, the first CRAN release.
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
| 0 | [Package identity](#stage-0--package-identity) | quick | [#2](https://github.com/pedrobtz/zupix/issues/2) | | |
| 1 | [Vendored codecs and the Wuffs gate](#stage-1--vendored-codecs-and-the-wuffs-gate) | full | [#3](https://github.com/pedrobtz/zupix/issues/3) | | |
| 2 | [Decoding PNG and QOI](#stage-2--decoding-png-and-qoi) | full | [#4](https://github.com/pedrobtz/zupix/issues/4) | | |
| 3 | [JPEG, WebP and metadata](#stage-3--jpeg-webp-and-metadata) | full | [#5](https://github.com/pedrobtz/zupix/issues/5) | | |
| 4 | [Lossless encoders](#stage-4--lossless-encoders) | quick | [#6](https://github.com/pedrobtz/zupix/issues/6) | | |
| 5 | [Lossy encoders and metadata embedding](#stage-5--lossy-encoders-and-metadata-embedding) | quick | [#7](https://github.com/pedrobtz/zupix/issues/7) | | |
| 6 | [C table](#stage-6--c-table) | full | [#8](https://github.com/pedrobtz/zupix/issues/8) | | |
| 7 | [Conformance, hostile input and fuzzing](#stage-7--conformance-hostile-input-and-fuzzing) | quick | [#9](https://github.com/pedrobtz/zupix/issues/9) | | |
| 8 | [Documentation and benchmarks](#stage-8--documentation-and-benchmarks) | quick | [#10](https://github.com/pedrobtz/zupix/issues/10) | | |
| 9 | [Full CI](#stage-9--full-ci) | full | [#11](https://github.com/pedrobtz/zupix/issues/11) | | |
| 10 | [v0.1.0 readiness](#stage-10--v010-readiness) | full | [#12](https://github.com/pedrobtz/zupix/issues/12) | | |

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

**Exit criteria.**

- A full-profile run is green on the pull request and on the merge
  commit.

**Design.** §12.

## Stage 10 — v0.1.0 readiness

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
