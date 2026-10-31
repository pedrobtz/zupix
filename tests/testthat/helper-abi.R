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

# A coverage or sanitizer runtime exports symbols of its own: gcov's
# __gcov_*, clang's __llvm_gcov_*, llvm_gcda_* and __llvm_profile_*, and
# the sanitizers' __asan_*, __ubsan_*, __tsan_*, __msan_*, __sancov_* and
# __sanitizer_*, plus the bounds the linker adds for ASan's globals section
# (__start_asan_globals, __stop_asan_globals). Matched as prefixes only (after any leading underscores), so
# a leaked vendored symbol that merely contains those letters is not taken
# for one and still fails the ABI tests.
instrumentation_symbol <- function(syms) {
  runtimes <- c(
    "gcov_",
    "llvm_gcov",
    "llvm_gcda",
    "llvm_prof",
    "asan_",
    "ubsan_",
    "tsan_",
    "msan_",
    "sancov",
    "sanitizer_",
    "start_asan_globals",
    "stop_asan_globals"
  )
  grepl(paste0("^_*(", paste(runtimes, collapse = "|"), ")"), syms)
}

is_instrumented_build <- function() {
  if (identical(Sys.getenv("R_COVR"), "true")) {
    return(TRUE)
  }
  syms <- tryCatch(exported_symbols(), condition = function(e) character())
  any(instrumentation_symbol(syms))
}
