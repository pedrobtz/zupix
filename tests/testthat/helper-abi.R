# Symbol-table helpers for test-abi.R, adapted from zukomp's helper-abi.R.
# In a helper so every testthat worker sources them.

zupix_dll_path <- function() {
  dll <- getLoadedDLLs()[["zupix"]]
  skip_if(is.null(dll), "zupix DLL is not loaded")
  path <- dll[["path"]]
  skip_if(!file.exists(path), "zupix shared object not found on disk")
  path
}

run_nm <- function(args) {
  nm <- Sys.which("nm")
  skip_if(!nzchar(nm), "nm is not available on this platform")
  syms <- suppressWarnings(
    system2(
      nm,
      c(args, shQuote(zupix_dll_path())),
      stdout = TRUE,
      stderr = FALSE
    )
  )
  skip_if(!is.character(syms) || length(syms) == 0L, "nm produced no output")
  syms
}

# What the object exports. Windows is skipped: R exports from a .def file
# there and $(C_VISIBILITY) is empty, so the export set is not this build's
# to control.
exported_symbols <- function() {
  skip_on_os("windows")
  names <- if (Sys.info()[["sysname"]] == "Darwin") {
    run_nm("-gU")
  } else {
    run_nm(c("-D", "--defined-only"))
  }
  names <- sub("^.*[[:space:]]", "", names)
  names <- sub("@.*$", "", names)
  names <- sub("^_", "", names)
  setdiff(names, c("_init", "_fini", "_edata", "_end", "__bss_start", ""))
}

# A coverage or sanitizer runtime exports symbols of its own.
is_instrumented_build <- function() {
  if (identical(Sys.getenv("R_COVR"), "true")) {
    return(TRUE)
  }
  syms <- tryCatch(exported_symbols(), condition = function(e) character())
  any(grepl("gcov|__llvm_prof|asan|ubsan|tsan|msan|sancov", syms))
}
