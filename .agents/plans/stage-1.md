# Stage 1 plan: vendored codecs and the Wuffs gate

Scratch; the roadmap is authoritative. Written 2026-10-30.

Findings from local probes (clang, macOS x86_64, `-Wall -pedantic`):

- Wuffs v0.4.0-alpha.12 with every `#pragma (GCC|clang) diagnostic` line
  removed: 0 warnings unless `WUFFS_CONFIG__STATIC_FUNCTIONS` (64
  `-Wunused-function`), so functions stay extern and `$(C_VISIBILITY)`
  hides them. About 8 s to compile. Undefined: libc only.
- libjpeg-turbo 3.2.1 compression closure (46 TUs, the `jc*` wrappers,
  `jcomapi`, `jerror`, forward DCTs, `jmemmgr`, `jmemnobs`, `jpeg_nbits`,
  `jutils`): 0 warnings with `-DNO_GETENV`. Only `jerror.c` references
  `stderr`, `fprintf` and `exit`.
- libwebp 1.6.0 encoder (upstream's `libwebp` minus `dec/`: enc, dsp
  common + enc + every SIMD variant, utils common + enc, sharpyuv): 0
  warnings. Only `__assert_rtn`, gone with `-DNDEBUG`.

Tasks:

1. `tools/vendor/` after zukomp: `manifest.tsv`, `common.sh`, `fetch`,
   `record`, `verify`, `checksums.sha256`; keep lists from the probes.
2. Patches: `wuffs/0001-drop-diagnostic-pragmas.patch` (with the
   Apache-2.0 §4(b) notice), `libjpeg-turbo/0001-no-stdio-or-exit.patch`
   (`error_exit` calls zupix's `zpx_int_jpeg_error_exit`,
   `output_message` is silent).
3. First-party glue: `src/jpeg-config/` (hand-written `jconfig.h`,
   `jconfigint.h`, `jversion.h`), `src/zpx_wuffs.c` (the one Wuffs
   implementation TU), `src/zpx_jpeg_error.c`, `src/zpx_r_info.c`.
4. `src/Makevars`: object lists, `$(C_VISIBILITY)`, `-lz`.
5. `zupix_info()` in R with a test asserting the vendored versions.
6. Licences: `inst/licenses/`, `inst/COPYRIGHTS`, `LICENSE.note`,
   `cph` entries.
7. `tools/check-symbols` (+ canary) and the CI workflows:
   `vendor.yaml`, `native-checks.yaml`, `hardening.yaml`.
8. Local `devtools::check()`; record tarball size, compile time,
   baseline benchmarks.
