# Design §7 and §9 (R3): the shared object exports only R_init_zupix, the
# vendored libraries stay hidden inside it, and the public header is
# installed with the ABI version consumers compile against. The C table
# itself is exercised from outside by tools/zupixtest (abi.yaml).

test_that("the shared object exports nothing but R_init_zupix", {
  skip_if(
    is_instrumented_build(),
    "instrumented build: its runtime exports symbols of its own"
  )
  expect_identical(exported_symbols(), "R_init_zupix")
})

test_that("no vendored library's symbols are exported", {
  skip_if(
    is_instrumented_build(),
    "instrumented build: its runtime exports symbols of its own"
  )
  exported <- exported_symbols()
  for (prefix in c(
    "wuffs_",
    "jpeg_",
    "jinit",
    "WebP",
    "VP8",
    "SharpYuv",
    "qoi_",
    "zpx_",
    "zupix_get_api"
  )) {
    expect_length(grep(paste0("^", prefix), exported, value = TRUE), 0L)
  }
})

test_that("the vendored codecs are compiled in, hidden", {
  syms <- compiled_symbols()
  for (name in c(
    "wuffs_jpeg__decoder__decode_frame",
    "jpeg_start_compress",
    "WebPEncode",
    "qoi_encode",
    "zupix_get_api"
  )) {
    expect_true(any(grepl(paste0("\\b_?", name, "$"), syms)), info = name)
  }
})

test_that("the public headers are installed at ABI version 1", {
  h <- system.file("include", "zupix.h", package = "zupix")
  skip_if(!nzchar(h), "headers are not installed (load_all)")
  text <- readLines(h)
  expect_true(any(grepl("^#define ZUPIX_ABI_VERSION 1u$", text)))
  expect_true(any(grepl("zupix_api_v1;", text, fixed = TRUE)))
  r <- readLines(system.file("include", "zupix-r.h", package = "zupix"))
  expect_true(any(grepl(
    "R_GetCCallable(\"zupix\", \"zupix_get_api\")",
    r,
    fixed = TRUE
  )))
})
