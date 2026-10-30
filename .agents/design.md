# RFC 0055: `zupix`, PNG, JPEG, WebP and QOI with no system library

Adopted from [RFC 0055](https://github.com/pedrobtz/packages/blob/main/rfcs/started/0055-zupix-image-codecs.md)
on 2026-10-30. From here on this file is authoritative; the RFC is history.

- **Status:** Proposed. Merging this file adopts the design as the starting
  point for the package's own `.agents/design.md`; each decision in section
  13 stays the maintainer's until the package repository records it. The
  maintainer has made none yet, so every decision is marked **(C)**. D1,
  decoding all four formats with Wuffs from its `v0.4` alpha series, is
  the one most worth a second look. Revised the same day to follow
  [`imaging-stack-2026-10-30.md`](https://github.com/pedrobtz/packages/blob/main/imaging-stack-2026-10-30.md):
  §6.2's shapes are the stack's pixel contract, and TIFF moves from "not
  planned" to v0.2.0 (D6).
- **Date:** 2026-10-30.
- **Packages:** `zupix` (not yet created; crandb returns `not_found` and
  there is no `pedrobtz/zupix` repository; both checked on 2026-10-30).
  No `Imports`. No `LinkingTo`. `Suggests: testthat, withr, png, jpeg,
  webp, qoi`. No `SystemRequirements`: zlib comes from R's own toolchain
  (§4.3). MIT for `zupix`'s own code. Vendored: Wuffs (MIT and
  Apache-2.0), the compression half of libjpeg-turbo (IJG licence and
  BSD-3-Clause), the libwebp encoder (BSD-3-Clause, with Google's patent
  grant) and `qoi.h` (MIT).
- **Source:** the request of 2026-10-30 for a vendored image codec
  package; RFC 0021 (`zuraster`) §12, RFC 0013 (`zuvips`), RFC 0019
  (`zuocr`) §15, RFC 0058 (`zucolor`) §3 and Q3; the design documents of
  `zusvg` (§7, §9), `zupdf` (§9, D6) and `zukomp` (§2, §15, §20, §26),
  read on 2026-10-30. Upstreams checked on 2026-10-30: `google/wuffs` at
  `v0.4.0-alpha.12` (commit `7f70dda`, 2026-10-20), its
  `release/c/wuffs-v0.4.c` (98,676 lines) and `doc/std/`;
  `libjpeg-turbo` 3.2.0 (2026-06-30) and 3.2.1 (2026-10-27), its
  `LICENSE.md`, `CMakeLists.txt` and `src/`; `libwebp` v1.6.0
  (2025-06-30); `phoboslab/qoi` at `ffb2d2c` (2026-09-27; no tags);
  `libspng` v0.7.4 (2023-05-08); `nothings/stb` (`README.md`,
  `stb_image.h` 2.30); crandb for `png`, `jpeg`, `webp`, `qoi`, `magick`,
  `imager`, `tiff` and `readbitmap`. Nothing has been built.

## 1. What zupix is

`zupix` reads and writes the four raster formats R users meet most: PNG,
JPEG, WebP and QOI. It decodes to a `nativeRaster` or to an integer or
double array, at 8 or 16 bits, and encodes from the same shapes. It
reads an image's header and metadata (dimensions, bit depth, colour
type, ICC profile bytes, EXIF orientation) without decoding pixels, and
offers the same codecs to siblings' C code through a registered table.

Every codec is compiled into the package; installing it needs a C
compiler and the zlib R is built with. Images arrive from the network,
PDFs, spreadsheets and users, so decoding is treated as parsing hostile
input: the decoders are Wuffs's, memory-safe by construction, and every
size an image declares is checked before anything is allocated.

The one-line statement that governs every decision below:

> **The pixels the file holds, decoded safely, with nothing done to them
> that the caller did not ask for.**

### 1.1 What zupix is not

- **Not colour management.** ICC profiles and the PNG colour chunks are
  returned as data and never applied; `zucolor` (RFC 0058) applies them.
- **Not image processing.** No resizing, cropping or compositing;
  `zuvips` (RFC 0013) and `magick` do that. The one pixel operation is
  the lossless rotation or flip EXIF orientation names, when asked.
- **Not GIF, AVIF or JPEG XL** in v0.1.0, and **not TIFF until
  v0.2.0** (D6, §14).
- **Not a pyramid or slide reader.** Tiled, pyramidal and whole-slide
  images stay with `zuvips`, TIFF included.
- **Not a graphics device.** `zuraster` (RFC 0021) draws; `zupix` can
  encode what it draws.

### 1.2 Where it sits among existing CRAN packages

Every format here is already readable from R. From crandb on 2026-10-30:

- **`png`** 0.1-9 (2026-03-15, Simon Urbanek, GPL-2 or GPL-3,
  `SystemRequirements: libpng`). PNG to a double array or a
  `nativeRaster`, 16-bit kept, and writing. Small, fast, and what most R
  code uses. CRAN's Windows and macOS binaries carry libpng; a Linux
  source install needs `libpng-dev`. `info = TRUE` reports the header
  after decoding; no ICC profile.
- **`jpeg`** 0.1-11 (2025-03-21, Urbanek, GPL-2 or GPL-3,
  `SystemRequirements: libjpeg`). The same for JPEG, 8-bit, no ICC or
  EXIF.
- **`webp`** 1.3.0 (2024-12-16, Jeroen Ooms, MIT, `SystemRequirements:
  libwebp`). WebP both ways through the system libwebp.
- **`qoi`** 0.1.0 (2024-04-17, Johannes Friedrich, MIT, compiled, no
  `SystemRequirements`). QOI both ways, files and raw vectors: the one
  competitor that already needs no system library.
- **`magick`** 2.9.1 (2026-02-28, Ooms, MIT, `SystemRequirements:
  ImageMagick++`). Everything, through a large system dependency that
  itself links libpng, libjpeg and libwebp.
- **`imager`** 1.0.8 (LGPL-3; fftw3, libtiff, X11), **`readbitmap`**
  0.1.5 (2018) and **`tiff`** 0.1-12 (libtiff, libjpeg) sit on the same
  system libraries.

Base R reads no image format; `grDevices::png()` and `jpeg()` write only
through a device and depend on how R was built. So the case is not that
R cannot read PNG. It is the combination no package offers: four formats
that install from source with no system library, decoders built for
hostile input, a metadata probe that does not decode, ICC and EXIF
bytes, MIT, and a C table so that siblings stop each choosing a codec.

### 1.3 The admission test

Against `base-layer-candidates.md` §2: (1) PNG (W3C), JPEG (ITU-T T.81,
JFIF), WebP (RFC 9649) and QOI are specified, with PngSuite,
libjpeg-turbo's `testimages`, libwebp's test files and the QOI test
images as corpora; (2) every upstream is permissive C, with R's zlib the
only library not vendored; (3) `zuraster` and `zusvg` would use the C
table and `zuocr`, `zupdf` and `zuxlsx` the R functions (§3); (4) base R
reads no image, and the packages that do need a system library to build.

## 2. Scope

**In v0.1.0:**

- Decoding PNG (every colour type and depth, palettes, `tRNS`, Adam7),
  JPEG (baseline and progressive, 8-bit, grey, YCbCr, Adobe CMYK and
  YCCK), WebP (lossy, lossy with alpha, lossless) and QOI, through Wuffs.
- Output as `nativeRaster`, a double array in `[0, 1]`, or an integer
  array of sample values with a `bits` attribute of 8 or 16 (§6.2).
- Encoding PNG (8 and 16 bits, 1 to 4 channels), JPEG (8-bit, quality,
  subsampling, progressive), WebP (lossy and lossless) and QOI.
- `pix_info()`: format, size, depth, colour type, alpha, interlacing,
  animation, density, EXIF orientation, PNG `gAMA`, `cHRM`, `sRGB` and
  `cICP`, ICC and EXIF presence, with no pixel decode.
- ICC and EXIF bytes out (`pix_icc()`, `pix_exif()`) and in (every
  encoder's `icc` and `exif`).
- Limits checked before allocation (§6.5); the C table (§7); fuzz
  targets under `fuzz/`, as `zukomp`, `zuxml`, `zusvg` and `zupdf` have.

**Not in v0.1.0** (§14): TIFF (v0.2.0, D6); GIF, BMP, AVIF, JPEG XL;
frames after the first; 12-bit and arithmetic-coded JPEG; streaming;
connections as output; colour conversion of any kind.

## 3. Position in the `zu*` family

| | zupix |
| --- | --- |
| Role | provider (codecs for R and for siblings' C code) |
| R prefix | `pix_` |
| Info function | `zupix_info()` |
| Root condition class | `zupix_error` |
| Public C prefix | `zpx_` / `ZPX_` |
| From C | yes: `zupix_get_api(version)` through `zupix-r.h` (§7) |
| Hides symbols | yes (R3); only `R_init_zupix` exported |
| Vendored code | Wuffs; libjpeg-turbo (compress); libwebp (encode); `qoi.h` |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |

`zpx_` occurs in no RFC here and in none of the sibling designs read;
`zu_` is `zukomp`'s (its §14).

**Relationships.** `imaging-stack-2026-10-30.md` plans the seven imaging
packages together: `zupix` owns image files, `zucolor` owns colour, and
§6.2's shapes are the contract every one of them speaks. Every
dependency in that plan points at `zupix` or `zucolor`, and `zupix`
depends on no sibling.

- **`zuraster`** (RFC 0021, revised to the plan). `raster_png()`,
  `raster_jpeg()` and `raster_webp()` hand the page buffer to the table
  (`Imports` and `LinkingTo: zupix`); `zuraster` has no PNG writer, no
  libjpeg and no `configure` probe of its own. `raster_tiff()` returns
  when `zupix` 0.2.0 has TIFF (D6).
- **`zuvips`** (RFC 0013, revised). Not replaced. It links libvips for
  lazy pipelines, every format, and tiled, pyramidal and slide images;
  `zupix` is the whole-image codec layer. Ordinary TIFFs move to `zupix`
  0.2.0. They meet at the contract's arrays, `zupix` in `Suggests`.
- **`zuocr`** (RFC 0019, revised). Its Q3 is answered: files and raw
  vectors decode through `pix_read()` (`Imports: zupix`, R level only),
  and arrays in every §6.2 shape are accepted.
- **`zusvg`** (started). Encodes with plutovg's `stb_image_write`, whose
  PNG compression is weak, and plans a `zukomp` hook for its zlib stream
  (its §7). Encoding through `zupix` gives better PNG, 16-bit, WebP and
  ICC tagging, and makes that hook unnecessary. Embedded `data:` images
  are decoded by `stb_image` inside plutosvg; replacing that needs a
  plutosvg patch and is `zusvg`'s call (Q8).
- **`zupdf`** (started). Its D6 declines a JPEG decoder because it
  "would add a security surface to a package whose input is hostile",
  and returns DCT streams as JPEG bytes. `pix_read()` takes those bytes,
  so `zupdf` can name `zupix` in `Suggests` without changing D6. RGBA
  PNG, which pdfio reads only with libpng, can reach `pdf_image_new()`
  as a `zupix` array. The same route reads scanned PDFs: page images out
  of `zupdf`, decoded by `zupix`, into `zuocr`, with no renderer.
- **`zuxlsx`** (started). Images are out of its initial scope; when it
  handles `xl/media/`, `pix_info()` gives an anchor's size undecoded.
- **`zucolor`** (RFC 0058). The boundary RFC 0058 §3 and its D18 state,
  unchanged: `zupix` moves profile bytes in and out of files (`iCCP`,
  JPEG `APP2`, WebP `ICCP`) as raw vectors and never applies them;
  `zucolor` applies them and never reads an image file. Neither depends
  on the other. Its Q3: 16-bit pixels are an integer array with
  `bits = 16L` (§6.2), the row its §6.6 accepts, and `cICP` is exposed
  by `pix_info()` as four integers (§6.4).
- **`zukomp`**. Not used: PNG encoding needs zlib's deflate and the
  probe inflates compressed `iCCP` profiles, both from the zlib R links,
  following `zukomp` §2's qualification of 2026-09-22 and `zuhttp`'s D-7.

## 4. Architecture

```text
R layer (R/)              arguments, shapes, limits, conditions
.Call glue (zpx_r.c)      R objects <-> buffers; the only R-aware C
core (zpx_*.c)            C99, no R headers; served by the table (§7)
  sniff + scan            own: signatures, PNG chunks, JPEG markers,
                          RIFF chunks, EXIF IFD0 (§6.4)
  decode                  Wuffs: png, jpeg, webp + vp8, qoi
  encode                  own PNG writer over zlib; libjpeg-turbo
                          compressor; libwebp encoder; qoi.h
  container writers       own: iCCP/eXIf, APP1/APP2, VP8X/ICCP/EXIF
```

The core includes no R header, as `zukomp`'s does, so fuzz targets link
it without R and the table serves it unchanged. No core function raises
an R error or longjmps out of itself; each returns a `zpx_status`.

### 4.1 Decoding: Wuffs

Wuffs is a memory-safe language whose compiler proves bounds and
arithmetic overflow and emits C. Its decoders allocate nothing: the
caller passes the pixel buffer and a work buffer whose length the
decoder states after the header. That is the shape §6.5 needs.

Checked on 2026-10-30:

- **Licence.** `LICENSE`: "distributed under the terms of both the MIT
  license and the Apache License (Version 2.0)". Both texts ship (Q2).
- **Versions.** `release/c/README.md` names 0.3 (April 2023) the latest
  stable version, and `wuffs-v0.3.c` has PNG but no JPEG, WebP or QOI.
  Those exist only in `wuffs-v0.4.c`, from the `v0.4.0-alpha` tags
  (alpha.10 2026-06-23, alpha.11 2026-10-18, alpha.12 2026-10-20), with
  "no promises about compatibility". That is D1's cost.
- **Modules.** `WUFFS_CONFIG__MODULES` with `BASE`, `ADLER32`, `CRC32`,
  `DEFLATE`, `ZLIB`, `PNG`, `JPEG`, `VP8`, `WEBP` and `QOI` compiles
  only those from the single 3.7 MB file.
- **Own limits.** Every decoder rejects a side above 16,777,215. JPEG
  rejects arithmetic, hierarchical and lossless coding and 12- and
  16-bit precision with named errors, mapped to
  `zupix_unsupported_error`.
- **Metadata.** The PNG decoder reports `iCCP`, `eXIf`, `gAMA`, `cHRM`,
  `sRGB`, `cICP` and text on request; in alpha.12 the JPEG and WebP
  decoders' `set_report_metadata` are empty. Hence D12.
- **Pixel formats.** `RGBA_NONPREMUL` is a little-endian
  `nativeRaster`'s byte order, so native output decodes in place;
  16-bit goes through `BGRA_NONPREMUL_4X16LE` and is reordered.
- **Build hazards.** About 105 `#pragma GCC diagnostic ignored` lines
  (`-Wconversion` 66, `-Wmaybe-uninitialized` 30), which `R CMD check`
  reports. The vendor script removes them as a recorded patch, as
  `zukomp` and `zusvg` did for theirs; Stage 0 measures the warnings
  left (Q1). Its x86-64 SIMD paths can be turned off with
  `WUFFS_CONFIG__AVOID_CPU_ARCH`.

The alternatives, and why each is second:

- **The reference decoders** (libspng, libjpeg-turbo's decompressor,
  libwebp's decoder, `qoi.h`): mature, fuzzed upstream, and the fallback
  if Stage 0's gate fails. Second because they are hand-written C over
  hostile input: libwebp's lossless decoder carried CVE-2023-4863, a
  heap overflow exploited in the wild in 2023. Wuffs's README also
  measures its PNG decoder at 1.2 to 2.7 times libpng's speed.
- **`stb_image`** 2.30: PNG and JPEG, no WebP, decode only. Its README:
  "it may take significant time for security fixes to be implemented or
  merged. If this poses an unreasonable risk to your project, do not use
  stb libraries." For hostile input it does (D5).

### 4.2 Encoding

Encoders read arrays the caller built: trusted input, where output
quality matters more than parsing. Wuffs has no encoders.

- **PNG: `zupix`'s own writer** (D4). `IHDR`, optional `iCCP`, `eXIf`,
  `sRGB` or `gAMA`, `IDAT` from zlib's `deflate()` over rows filtered by
  libpng's minimum-sum-of-absolute-differences heuristic, `IEND`, CRCs
  from zlib's `crc32()`; about 500 lines. libspng (BSD-2) encodes well,
  but has not released since 2023-05-08 and its latest commit
  (2026-08-31) updates a copyright year; `stb_image_write` compresses
  poorly, as `zusvg` §7 found.
- **JPEG: libjpeg-turbo's compression half, 8-bit, no SIMD.** Its
  quality scale is libjpeg's, so `quality = 90` means what it means to
  `jpeg::writeJPEG()`, and it writes progressive files with optimised
  Huffman tables, which `stb_image_write` does not. A CMake-free build
  is practical in 3.2.0: the per-precision wrappers in `src/wrapper/`
  (`#define BITS_IN_JSAMPLE 12` and an `#include`) ship in the tarball,
  and only `jconfig.h`, `jconfigint.h` and `jversion.h` are generated,
  which `zupix` writes by hand. `jcinit.c` calls the 12- and 16-bit
  initialisers, so their wrappers are compiled though only 8-bit is
  exposed: about 15,500 lines. `NO_GETENV` is defined, `error_exit` and
  `output_message` are replaced, and the `stderr` writes in `jerror.c`
  and `jmemmgr.c` patched out. Stage 0 pins the current 3.2.x; 3.2.1's
  fixes (a PIC regression, hidden in-tree zlib symbols) do not touch
  this subset.
- **WebP: libwebp 1.6.0's encoder**, the only complete lossy WebP
  encoder: `src/enc`, `src/utils`, the encoder's part of `src/dsp` and
  `sharpyuv`, about 510 kB compressed. Its x86 and ARM SIMD is
  intrinsics behind compiler macros and stays on; threads stay off.
  libwebpmux is not vendored: `zupix` writes `VP8X`, `ICCP` and `EXIF`
  around the bitstream (D14). Stage 0 audits `fprintf(stderr, …)` in
  `frame_enc.c`, `quant_enc.c`, `webp_enc.c` and `utils.c`.
- **QOI: `qoi.h`** at `ffb2d2c`, `qoi_encode()` only, `QOI_NO_STDIO`,
  with `QOI_MALLOC` and `QOI_FREE` set to `zupix`'s allocator.

### 4.3 zlib and size

zlib is the one library not vendored: R requires it, Rtools ships it,
and `zuhttp` and `zupdf` link `-lz` on those grounds. `zukomp`'s table
would add a run-time dependency for a codec every R has; its archive
would put a second miniz in the shared object (D3).

Compressed sizes measured on 2026-10-30: `wuffs-v0.4.c` 448 kB, the
libwebp encoder subset about 510 kB, all of libjpeg-turbo's `src/`
932 kB (the compression half less), `qoi.h` 5 kB. The tarball should be
1.5 to 2 MB, under the line `zukomp` §11 drew. Stage 0 records it and
the compile time of the 98,676-line Wuffs unit.

## 5. Public R API (v0.1.0 shape)

```r
# decoding
pix_read(x, as = c("native", "double", "integer"), bits = NULL,
         channels = NULL, orient = FALSE, format = "auto",
         limits = pix_limits())

# header and metadata, no pixel decode
pix_info(x, format = "auto", limits = pix_limits())  # data frame
pix_icc(x)                     # raw vector, or NULL
pix_exif(x)                    # raw vector (TIFF header onward), or NULL
pix_format(x)                  # "png", "jpeg", "webp", "qoi" or NA

# encoding: file = NULL returns a raw vector
pix_write(x, file, format = NULL, ...)       # format from extension
pix_write_png(x, file = NULL, bits = NULL, compression = 6L,
              icc = NULL, exif = NULL, srgb = NULL)
pix_write_jpeg(x, file = NULL, quality = 90L, subsampling = "4:2:0",
               progressive = FALSE, icc = NULL, exif = NULL)
pix_write_webp(x, file = NULL, quality = 75, lossless = FALSE,
               method = 4L, icc = NULL, exif = NULL)
pix_write_qoi(x, file = NULL, colourspace = c("srgb", "linear"))

pix_orient(img, orientation)   # apply an EXIF orientation, 1 to 8
pix_limits(max_side = 65535L, max_pixels = 1e8, max_bytes = 2^31,
           max_metadata = 16 * 2^20)
zupix_info()
```

`x` in the readers is a path, a raw vector, or a connection read whole
up to `max_bytes`. `pix_info()` is vectorised over paths, one row per
file. `zupix_info()` reports the vendored versions, commits and patches,
zlib's linked version, whether Wuffs's SIMD is compiled, and the limits'
defaults.

## 6. Semantics

### 6.1 Formats

`format = "auto"` sniffs the signature (PNG's eight bytes, `FF D8 FF`,
`RIFF....WEBP`, `qoif`); the extension is never consulted on read. A
named `format` that disagrees with the signature is a
`zupix_format_error`.

### 6.2 Shapes

These three are the imaging stack's pixel contract (P1 to P3 of
`imaging-stack-2026-10-30.md` §4), which every sibling that takes or
returns pixels follows. v0.1.0's four formats hold only 8- and 16-bit
unsigned samples, so these three cover them all; the fourth value of
`as`, `"values"`, arrives with TIFF in v0.2.0 (§14).

- **`"native"`**: a `nativeRaster`, 8-bit RGBA, non-premultiplied, as
  `png::readPNG(native = TRUE)` returns. 16-bit samples round to 8.
- **`"double"`**: `height x width x channels` in `[0, 1]`, a matrix for
  one channel: `png::readPNG()`'s shape. 16-bit precision is kept.
- **`"integer"`**: the same shape holding sample values, `0..255` or
  `0..65535`, with attribute `bits` (8L or 16L).

`bits = NULL` keeps the file's depth (1-, 2- and 4-bit PNG become 8);
`8L` or `16L` forces it. `channels = NULL` keeps the file's: 1 grey, 2
grey and alpha, 3 RGB, 4 RGBA; a palette becomes 3, or 4 with `tRNS`.
`channels` may add (grey to RGB, opaque alpha) but never remove: RGB to
grey needs luma weights and dropping alpha needs a background, both
colour decisions (D10). A reduction is a `zupix_input_error`.

CMYK and YCCK JPEG decode to RGB through Wuffs's own conversion, not
colour-managed; `pix_info()` reports the stored colour type (Q3).

Encoders take the same shapes and a matrix as grey. Doubles are clamped
to `[0, 1]` and rounded; an integer array without `bits` is 8-bit if
every value is at most 255, else an error naming `bits`.

### 6.3 Orientation

Pixels come back as stored. `orient = TRUE`, or `pix_orient()` on an
array in hand, applies the EXIF orientation losslessly. The default is
`FALSE` by the governing statement, and so that the reported orientation
and the returned pixels agree (D9). The value is read from JPEG `APP1`,
PNG `eXIf` or WebP `EXIF`.

### 6.4 Metadata

Width and height come from Wuffs's `decode_image_config`, the size the
decoder will produce; everything else from `zupix`'s scanners. Where
both read a field and disagree, the file is a `zupix_decode_error`, so
a crafted header cannot pass the limits with one size and decode with
another. Each scanner is one bounded pass with no recursion:

- **PNG**: chunk walk with CRC checks: `IHDR`, `iCCP` (inflated into at
  most `max_metadata` bytes), `eXIf`, `gAMA`, `cHRM`, `sRGB`, `cICP`
  (four integers: primaries, transfer, matrix, full range), `pHYs`, and
  `acTL` for animation. `IDAT` is skipped by length, never inflated.
- **JPEG**: marker walk to the first `SOS`: `SOFn` (precision,
  components, progressive, arithmetic), `APP0` density, `APP1` Exif,
  `APP2` `ICC_PROFILE` reassembled by sequence number (a gap, repeat or
  out-of-range number is a `zupix_decode_error`), `APP14` Adobe.
- **WebP**: RIFF walk: `VP8`, `VP8L`, `VP8X`, `ICCP`, `EXIF`, `ANIM`. A
  RIFF size beyond the input is a `zupix_decode_error`.
- **QOI**: the 14-byte header, colourspace byte included.
- **EXIF**: TIFF header and IFD0 only, for tag `0x0112`; offsets
  bounds-checked, IFD chains not followed.

`gAMA`, `cHRM`, `sRGB` and `cICP` are reported, never applied (D8).

### 6.5 Hostile input

Here a decompression bomb is a small file declaring a huge image. The
defence is order: parse the header, check, then allocate.

1. Each side at most `max_side` (default 65,535, JPEG's maximum; WebP's
   own is 16,383).
2. `width * height` at most `max_pixels` (default 10⁸).
3. The R result's size from `as`, `bits` and `channels`, plus Wuffs's
   work buffer, at most `max_bytes` (default 2 GiB), in overflow-checked
   arithmetic. 10⁸ RGBA pixels as doubles is 3.2 GB and is refused, with
   a message naming `as = "native"` and the limit.
4. All metadata together at most `max_metadata` (16 MiB); `iCCP` is
   inflated with the cap as its output bound, never into a buffer sized
   by a claim.

A breach is a `zupix_limit_error` carrying `limit`, `value` and `cap`,
raised before allocation; `zupix.max_pixels` and its siblings set
session defaults. A truncated or corrupt file is a `zupix_decode_error`,
never a partial image. Decoding is not interruptible; the limits bound
its time. Encoders check format limits: WebP 16,383 a side, JPEG 65,535,
QOI's `QOI_PIXELS_MAX` of 4 × 10⁸ pixels.

### 6.6 Animation, threads, memory

APNG and animated WebP decode their first frame (for APNG, the default
image in `IDAT`), with `attr(, "animated") = TRUE` and no warning
(D13). The core has no global state: decoders are per call,
libjpeg-turbo's `error_exit` longjmps only within `zupix`'s own encode
frame, and libwebp runs without threads. The R layer allocates the
result after the checks and decodes into it, so the only extra memory
is Wuffs's work buffer and the 16-bit reorder.

## 7. C API

The table follows `zukomp` §15 and its §26 convergence targets: a
pure-C99 `inst/include/zupix.h`, an R-only `zupix-r.h` resolving lazily
through `R_GetCCallable("zupix", "zupix_get_api")` and caching, and
`NULL` on a version mismatch. A consumer has `Imports` and `LinkingTo:
zupix` and an `importFrom()` in its `NAMESPACE`.

```c
#define ZUPIX_ABI_VERSION 1u

typedef enum { ZPX_OK = 0, ZPX_ERR_FORMAT, ZPX_ERR_DECODE,
               ZPX_ERR_UNSUPPORTED, ZPX_ERR_LIMIT, ZPX_ERR_MEMORY,
               ZPX_ERR_ARGUMENT, ZPX_ERR_ENCODE, ZPX_ERR_SINK
} zpx_status;
typedef enum { ZPX_FMT_UNKNOWN = 0, ZPX_FMT_PNG, ZPX_FMT_JPEG,
               ZPX_FMT_WEBP, ZPX_FMT_QOI } zpx_format;
typedef enum { ZPX_PIX_RGBA8 = 1, ZPX_PIX_RGB8, ZPX_PIX_Y8,
               ZPX_PIX_RGBA16, ZPX_PIX_Y16 } zpx_pixfmt;
typedef struct { uint32_t struct_size, max_side;
                 uint64_t max_pixels, max_bytes, max_metadata;
} zpx_limits;
typedef struct { uint32_t struct_size; zpx_format format;
                 uint32_t width, height; uint8_t bits, channels,
                 orientation, animated; size_t icc_len, exif_len;
} zpx_info;
typedef int (*zpx_write_fn)(void *closure, const uint8_t *, size_t);

typedef struct {
  uint32_t abi_version, struct_size;
  zpx_format (*sniff)(const uint8_t *, size_t);
  zpx_status (*probe)(const uint8_t *, size_t, const zpx_limits *,
                      zpx_info *);
  zpx_status (*decode)(const uint8_t *, size_t, const zpx_limits *,
                       zpx_pixfmt, uint8_t *dst, size_t stride,
                       size_t dst_len);
  zpx_status (*metadata)(const uint8_t *, size_t, uint32_t fourcc,
                         uint8_t *dst, size_t *len);
  zpx_status (*encode)(zpx_format, zpx_pixfmt, const uint8_t *src,
                       uint32_t w, uint32_t h, size_t stride,
                       const void *opts, zpx_write_fn, void *closure);
  const char *(*status_string)(zpx_status);
} zupix_api_v1;
```

`probe` then `decode` is two-phase: the consumer allocates `dst` after
`probe` applied the limits. `metadata` with `dst = NULL` returns the
length. `encode` streams through the sink, so `zuraster` writes to its
file and `zusvg` to its buffer without a copy; per-format options are
structs that start with `struct_size`. Nothing raises an R error, so a
consumer may call in from a vendored library's frames, which is
`zusvg` §7's constraint on its hook.

**No static archive** (D11). `zukomp`'s archive mode exists for a
library written against an upstream's own API (`xlsxio` against miniz);
no consumer here is one. The table keeps one copy of the decoders per
process, so a Wuffs or libwebp fix reaches every consumer on `zupix`'s
upgrade alone, the argument `zukomp` §15 makes for its codecs.
`tools/zupixtest` is the fixture package, on all three OSes.

## 8. Errors

Every condition inherits from `zupix_error`; tests assert on class.

| Class | Raised when |
| --- | --- |
| `zupix_input_error` | a bad argument, shape or channel reduction |
| `zupix_format_error` | unknown signature, or `format` disagrees |
| `zupix_unsupported_error` | 12-bit, arithmetic or lossless JPEG |
| `zupix_decode_error` | corrupt, truncated or inconsistent input |
| `zupix_limit_error` | a §6.5 limit, before allocation |
| `zupix_encode_error` | an encoder failed or a format limit was hit |
| `zupix_io_error` | a file could not be read or written |
| `zupix_memory_error` | allocation failed |
| `zupix_internal_error` | a status the core should never return |

Each carries the format and the upstream's message where there is one
(Wuffs's status strings, libjpeg-turbo's message table).

## 9. Testing

`testthat` 3e, one file per section of §6, plus:

- **Conformance.** PngSuite (every file decodes or fails with the class
  its name predicts); libjpeg-turbo's `testimages`; libwebp's test
  files; the QOI test images. Files whose licence forbids
  redistribution are downloaded in CI only (Q6).
- **Differential.** `png::readPNG()` exactly on every PngSuite file it
  reads; `jpeg::readJPEG()` within 2 levels per sample, since the IDCTs
  differ, recorded per file; `webp::read_webp()` and `qoi::readQOI()`
  exactly on lossless files. Each of those packages reads every file
  `zupix` writes.
- **Round trips.** PNG, QOI and lossless WebP identical at 8 and 16 bits
  and every channel count, on random images; JPEG and lossy WebP above a
  recorded PSNR floor per quality; ICC and EXIF bytes unchanged through
  every encoder.
- **Hostile input.** A file per limit (a 60-byte PNG declaring 10⁶ ×
  10⁶, a JPEG at 65,535 × 65,535, a maximal `VP8X` canvas, an `iCCP`
  inflating past the cap); `APP2` sequences with gaps, repeats and a
  count of zero; EXIF offsets outside the block or pointing at
  themselves; every corpus file truncated at each of its first 4,096
  offsets and 64 random later ones, each raising `zupix_decode_error`
  or succeeding. Under ASan and UBSan in the full profile.
- **Fuzzing** (`fuzz/` in `zukomp`'s layout: `build.sh`, `run.sh`,
  `replay.sh`, `corpus/seed/`, `corpus/regressions/` never pruned), over
  the R-free core: `fuzz_decode_png`, `_jpeg`, `_webp`, `_qoi` under a
  16 MiB pixel cap, as `zukomp` caps output, so findings are memory
  safety rather than rediscovered bombs; `fuzz_probe` over arbitrary
  bytes, for `zupix`'s own scanners, the package's only hand-written
  parsers; `fuzz_exif` and `fuzz_jpeg_icc` driving those directly;
  `fuzz_roundtrip` on fuzzer-chosen small images; and a canary.
- **From the family** (R3): `test-abi.R`, that `zupix.so` exports
  `R_init_zupix` only and no `wuffs_`, `jpeg_`, `jinit`, `WebP` or
  `qoi_` symbol, reading the full symbol table as `zukomp`'s does; the
  `tools/zupixtest` fixture resolves the table, decodes, encodes, and
  gets `NULL` for a future ABI version.

## 10. Performance targets

Measured by `tools/run-benchmarks` into `.agents/benchmarks.md`, with
the baseline against `png`, `jpeg`, `webp` and `qoi` run in Stage 0.

| Operation (12-megapixel photograph) | Target |
| --- | --- |
| PNG decode to `nativeRaster` | at least as fast as `png::readPNG()` |
| JPEG decode to `nativeRaster` | within 2× of `jpeg::readJPEG()` |
| WebP decode | within 2× of `webp::read_webp()` |
| PNG encode, level 6 | within 1.5× of `png::writePNG()`, no larger |
| JPEG encode, quality 90 | within 3× of `jpeg::writeJPEG()` |
| WebP encode | within 10 % of `webp::write_webp()` |
| `pix_info()` on 1,000 files | under 1 s |

The JPEG targets are loose because `jpeg` usually links a libjpeg-turbo
with SIMD and `zupix` has none on either side; they tighten if Stage 0
shows Wuffs at parity. The WebP encoder is `webp`'s own library.

## 11. Roadmap

Stages run the quick CI profile unless marked `full`. Each is one pull
request, merged on green.

| Stage | Delivers | Exit criterion |
| --- | --- | --- |
| 0 | repository, vendor tooling and patches, CI, baseline | the gate |
| 1 | core, Wuffs PNG and QOI, limits, `pix_read()`, errors | §6.2, §6.5 |
| 2 | JPEG, WebP; scanners; `pix_info()`, ICC, EXIF, orient | §6.3, §6.4 |
| 3 | PNG writer over zlib; QOI encoder; 16-bit | lossless trips |
| 4 | libjpeg-turbo and libwebp encoders; metadata embedding | §9 trips |
| 5 (`full`) | C table, `zupix-r.h`, `tools/zupixtest`, `test-abi.R` | fixture |
| 6 | corpora, differential and hostile suites, `fuzz/` | §9 |
| 7 (`full`) | README, article, benchmarks, release preparation | §12 |

**Stage 0's gate** settles D1: Wuffs with its pragmas removed compiles
with no warning `R CMD check` counts on every r-actions leg, the r-devel
clang and GCC containers included, in acceptable time. If it does not,
and a small recorded patch cannot fix it, Stage 1 vendors the reference
decoders of §4.1 instead; the R API does not change.

Stage 5 is `full` because the table is called across two shared objects
and the sanitizer legs are the only check that no core function
longjmps or raises. Stage 7 is the closing full run.

## 12. Acceptance criteria for v0.1.0

- Every behaviour in §6, §7 and §8 has a passing test.
- PngSuite decodes as `png` does or fails with the predicted class;
  every hostile file fails with its class, allocating nothing beyond
  the header.
- Lossless round trips hold on 10⁴ random images per format and depth.
- Each fuzz target has run 10 minutes under ASan and UBSan with nothing
  open, and the canary fails.
- `R CMD check --as-cran` is clean on all r-actions legs, with no
  `SystemRequirements`, no `Imports` and no pragma NOTE.
- The tarball is under 3 MB; `inst/COPYRIGHTS` and `LICENSE.note` name
  every vendored licence; all upstream texts (both of Wuffs's, libwebp's
  `PATENTS`) are installed under `licenses/`; the README carries the IJG
  licence's acknowledgement of the Independent JPEG Group's work.
- §10 recorded; a missed target is met or rewritten with its reason.

## 13. Decisions

All **(C)**: this RFC decides, and the maintainer may overturn.
**2026-10-30: the maintainer accepted D1 to D18 as written** before
Stage 1 started; they stand as maintainer decisions from that date.

- **D1 (C).** Decode all four formats with Wuffs, pinned to a
  `v0.4.0-alpha` tag by commit and sha256, pragmas patched out. Memory
  safety is the point for hostile input, and caller-allocated buffers
  make §6.5 enforceable. The cost is an alpha upstream; the core hides
  it, and Stage 0's gate falls back to the reference decoders.
- **D2 (C).** Encoders: `zupix`'s PNG writer, libjpeg-turbo's compressor
  (8-bit, no SIMD, arithmetic or lossless), libwebp 1.6.0's encoder,
  `qoi.h`. Decoders and encoders deliberately come from different code.
- **D3 (C).** zlib from R's toolchain (`-lz`), as `zuhttp` and `zupdf`;
  not `zukomp`'s table or archive.
- **D4 (C).** No libspng: Wuffs decodes PNG, the writer is short, and
  libspng has not released since May 2023.
- **D5 (C).** No `stb_image` or `stb_image_write`: no WebP, and its own
  README warns hostile-input users away.
- **D6 (C).** TIFF is not in v0.1.0; it is v0.2.0's first item,
  through vendored libtiff (4.7.2, July 2026), read and write, with
  none, PackBits, LZW, Deflate and CCITT G3/G4 compression, multi-page
  files read as a list, float samples through `as = "values"`, and a
  bare CCITT decoder for PDF scans (§14). JPEG-in-TIFF, zstd, LZMA,
  WebP, JBIG and LERC are out (imaging stack I11). Both CRAN TIFF
  readers need system libtiff, and `zuraster` and `zuocr` want it, so
  the gap is `zupix`'s. It waits for v0.2.0 because libtiff is the one
  hand-written decoder `zupix` would carry: it is fuzzed and
  limit-checked as §6.5 does for the rest before it ships, and the four
  formats every sibling needs do not wait for that. Tiled, pyramidal
  and slide TIFFs stay with `zuvips` (imaging stack I3).
- **D7 (C).** `max_side`, `max_pixels`, `max_bytes` and `max_metadata`,
  with §5's defaults, checked on declared sizes before allocation, and
  scanner and Wuffs must agree on the size.
- **D8 (C).** No colour management: ICC bytes in and out verbatim,
  colour chunks reported, never applied. That is `zucolor`'s job.
- **D9 (C).** EXIF orientation reported, applied only on request.
- **D10 (C).** Three shapes: `nativeRaster`, a `png`-compatible double
  array, an integer array with `bits`; depth kept unless forced;
  channels added, never removed.
- **D11 (C).** A registered table, no static archive.
- **D12 (C).** `zupix`'s own container scanners for metadata, since
  Wuffs's JPEG and WebP decoders report none; fuzzed as the riskiest
  code in the package.
- **D13 (C).** Animated files decode their first frame, flagged.
- **D14 (C).** `zupix` writes WebP's `VP8X`, `ICCP` and `EXIF` chunks;
  no libwebpmux.
- **D15 (C).** No assembly: libjpeg-turbo without SIMD; Wuffs's and
  libwebp's intrinsic paths kept unless a CRAN leg objects.
- **D16 (C).** One package, no satellites: under 2 MB compressed, so
  `zukomp` §11's size argument does not arise.
- **D17 (C).** R prefix `pix_`; C prefix `zpx_`, internal `zpx_int_`.
- **D18 (C).** Read paths, raw vectors and connections (read whole);
  write a path or return a raw vector.

## 14. Later versions, in the order they are expected

- **TIFF in v0.2.0** (D6), with three parts the imaging plan settled on
  2026-10-30 (its I11 to I13, maintainer decisions):
  - libtiff, the compressions D6 names, and 8- and 16-bit integer
    samples in §6.2's shapes. `pix_info()` reports each file's
    compression; JPEG-compressed TIFF is a `zupix_unsupported_error`
    naming it. If users ask, a later version takes libjpeg-turbo's
    decompressor for that path alone, compression 7 only.
  - `as = "values"` for float, signed and 32-bit samples: unscaled, with
    a `sample_format` attribute (`"float32"`, `"int16"`, ...), the same
    shape `zuvips` returns. `as = "native"`, `"double"` or `"integer"`
    on such a file is a `zupix_input_error` naming `as = "values"`.
  - `pix_decode_ccitt(x, width, height, k = 0L, black_is_1 = FALSE,
    byte_align = FALSE)`: a bare CCITT G3/G4 bitstream, wrapped in an
    in-memory TIFF for libtiff's fax decoder, returned as 8-bit grey. It
    is how scanned PDFs' `CCITTFaxDecode` images, which `zupdf` returns
    undecoded with their parameters, reach `zuocr`.
- **Decode-only formats Wuffs has**: GIF (first frame), BMP, PNM, TGA,
  each a sniff and a pixel-format mapping.
- **Animation**: every frame of APNG, animated WebP and GIF, with
  timings.
- **Streaming decode** of large PNGs through Wuffs's resumable API, and
  connections as output.
- **12-bit JPEG**, if Wuffs gains it, or via libjpeg-turbo's
  decompressor for that case alone.
- **Lossless JPEG rotation** from libjpeg-turbo's `transupp`.
- **AVIF and JPEG XL**: large upstreams (libavif with dav1d; libjxl in
  C++), more likely satellites than `zupix` itself.

## 15. Open questions

- **Q1.** *Partly answered 2026-10-30 (Stage 1): `v0.4.0-alpha.12`,
  with its 306 diagnostic pragmas removed and one unused function
  deleted, compiles with no warning under clang `-Wall -pedantic` in
  about 8 s; GCC and every CRAN-like leg are the Stage 1 gate.* Does
  `wuffs-v0.4.c` compile without warnings on every CRAN
  flavour once its pragmas are gone, and how long does it take? Stage
  0's gate; the alpha tag is chosen then (alpha.12 is ten days old).
- **Q2.** *Answered 2026-10-30 (Stage 1): both texts ship, zupix complies
  with both (Apache-2.0 §4(b)'s notice is in the patched file), and
  `License:` stays `MIT + file LICENSE` with the vendored licences in
  `LICENSE.note` and `inst/COPYRIGHTS`.* Wuffs's `LICENSE` says "both"
  MIT and Apache-2.0, not "either". Shipping both texts and complying with both is safe on any
  reading; the `License:` and `LICENSE.note` wording want the
  maintainer's eye.
- **Q3.** CMYK JPEG: Wuffs offers no CMYK destination, so `zucolor`
  cannot apply a CMYK profile to the stored samples. Is RGB enough, or
  does `zupix` need a raw-sample path (Wuffs's natural pixel format, or
  libjpeg-turbo's decompressor for that case)?
- **Q4.** Are the default limits right? 10⁸ pixels sits near Pillow's
  decompression-bomb warning (about 8.9 × 10⁷); 2 GiB bounds a result
  R holds without long vectors.
- **Q5.** QOI's `linear` colourspace byte is reported and nothing is
  done with it, by D8. Should `pix_read()` at least warn?
- **Q6.** *Answered 2026-10-30 (Stage 7): PngSuite ("permission to use,
  copy, modify and distribute") and libjpeg-turbo's test images (IJG,
  BSD-3, ICC) are committed under `tests/testthat/corpus/`;
  libwebp-test-data and the QOI test images carry no redistribution
  licence and are downloaded, pinned, in CI only.* The corpus licences
  (PngSuite, libwebp's test files, the QOI
  test images) were not read for this RFC; Stage 6 reads them first.
- **Q7.** Is v0.1.0 a CRAN submission? This RFC assumes `CRAN intent:
  Planned`, since `zuraster` and `zuocr` would depend on it.
- **Q8.** Should `zusvg` move PNG and JPEG output to the table instead
  of the `zukomp` hook its §7 plans, and patch plutosvg's embedded-image
  decoding onto `zupix`? `zusvg`'s decision; this RFC only enables it.

## 16. What this RFC does not decide

The print method of a decoded image, `pix_info()`'s column names beyond
those §6.4 lists, the per-format option structs of §7, the article's
examples, and the exact libwebp `dsp` file list, which Stage 4
enumerates.
