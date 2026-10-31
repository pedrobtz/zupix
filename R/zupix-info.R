# What tools/vendor/manifest.tsv pins, for zupix_info(). tools/ is not
# installed, so this copy is checked against the manifest by
# tools/vendor/verify; the versions themselves are read from the compiled
# code, and the tests assert they match.
vendored <- data.frame(
  name = c("wuffs", "libjpeg-turbo", "libwebp", "qoi"),
  pinned = c("0.4.0-alpha.12+4048.20261020", "3.2.1", "1.6.0", "ffb2d2c"),
  commit = c(
    "7f70dda95c77b10c087c0908790837b5e9c15713",
    "7b4993786d856cbccabfc0ed2f923ba000e326cc",
    "4fa21912338357f89e4fd51cf2368325b59e9bd9",
    "ffb2d2cb74a1de60819b21b939f7209aa53e91c1"
  ),
  patches = c(
    "0001-drop-diagnostic-pragmas.patch, 0002-drop-unused-swizzle.patch",
    "0001-no-stdio-or-exit.patch",
    "0001-backport-rescaler-sse2-casts.patch",
    ""
  ),
  used_for = c(
    "decoding PNG, JPEG and WebP",
    "encoding JPEG",
    "encoding WebP",
    "encoding and decoding QOI"
  )
)

#' Build information
#'
#' Reports the codecs compiled into zupix: each vendored library's version,
#' the upstream commit it was taken from and the local patches applied to
#' it, the version of zlib zupix is linked against, and whether Wuffs's
#' CPU-specific (SIMD) code paths were compiled for this platform.
#'
#' @return A list with elements `version` (zupix's own, a
#'   [package_version]), `vendored` (a data frame with one row per vendored
#'   library and columns `name`, `version`, `commit`, `patches` and
#'   `used_for`), `zlib` (a string) and `wuffs_simd` (`TRUE` or `FALSE`).
#' @export
#' @examples
#' info <- zupix_info()
#' info$vendored[c("name", "version")]
#' info$zlib
zupix_info <- function() {
  compiled <- .Call(zpx_r_versions)
  out <- vendored
  out$version <- unname(c(
    compiled[c("wuffs", "libjpeg-turbo", "libwebp")],
    "ffb2d2c"
  ))
  out <- out[c("name", "version", "commit", "patches", "used_for")]
  list(
    version = utils::packageVersion("zupix"),
    vendored = out,
    zlib = unname(compiled[["zlib"]]),
    wuffs_simd = .Call(zpx_r_wuffs_simd)
  )
}
