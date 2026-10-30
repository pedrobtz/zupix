test_that("zupix_info() reports the vendored versions that were compiled", {
  info <- zupix_info()

  expect_s3_class(info$version, "package_version")
  expect_equal(
    info$vendored$name,
    c("wuffs", "libjpeg-turbo", "libwebp", "qoi")
  )
  # The compiled code reports these; tools/vendor/verify checks the same
  # strings against tools/vendor/manifest.tsv.
  expect_equal(
    info$vendored$version,
    c("0.4.0-alpha.12+4048.20261020", "3.2.1", "1.6.0", "ffb2d2c")
  )
  expect_match(info$vendored$commit, "^[0-9a-f]{40}$")
})

test_that("zupix_info() reports zlib and Wuffs's SIMD flag", {
  info <- zupix_info()

  expect_type(info$zlib, "character")
  expect_match(info$zlib, "^[0-9]+\\.[0-9]+")
  expect_type(info$wuffs_simd, "logical")
  expect_length(info$wuffs_simd, 1)
})
