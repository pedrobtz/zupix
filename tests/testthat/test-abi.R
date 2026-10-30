# Design §7 and §9 (R3): the shared object exports only R_init_zupix, no
# vendored library's symbol is exported, and the public header is installed
# with the ABI version consumers compile against. (Whether a vendored
# function is in the symbol table at all is not asserted: link-time
# optimisation inlines or renames single-caller functions such as
# qoi_encode, which the LTO leg showed.) The C table
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
