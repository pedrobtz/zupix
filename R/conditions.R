#' Conditions raised by zupix
#'
#' Every error zupix raises is a condition of class `zupix_error` with one
#' more specific subclass. Handle them by class, for example with
#' `tryCatch(..., zupix_limit_error = function(e) ...)`, never by matching
#' the message text, which may change.
#'
#' * `zupix_input_error`: an argument is invalid, or `channels` asks to
#'   remove a channel the image has. Field `arg` names the argument.
#' * `zupix_format_error`: the input has no PNG, JPEG, WebP or QOI
#'   signature, or `format` names a different format from the one the
#'   signature shows.
#' * `zupix_unsupported_error`: the image is valid but uses a feature zupix
#'   does not decode.
#' * `zupix_decode_error`: the image is corrupt, truncated or inconsistent.
#'   No partial image is returned.
#' * `zupix_limit_error`: a limit from [pix_limits()] was exceeded. Fields
#'   `limit` (its name, such as `"max_pixels"`), `value` (what the image
#'   needs) and `cap` (the limit). Raised before the pixels are allocated.
#' * `zupix_encode_error`: an encoder failed or a format's own limit was
#'   hit.
#' * `zupix_io_error`: a file or connection could not be read or written.
#' * `zupix_memory_error`: memory could not be allocated.
#' * `zupix_internal_error`: zupix's C code returned a status it should
#'   never return. This is a bug; please report it.
#'
#' Each condition from a decoder also carries `format`, the format being
#' decoded, and `detail`, the decoder's own message where there is one.
#'
#' @name zupix-conditions
NULL

zpx_condition <- function(kind, message, ..., call = NULL) {
  structure(
    class = c(
      paste0("zupix_", kind, "_error"),
      "zupix_error",
      "error",
      "condition"
    ),
    list(message = message, call = call, ...)
  )
}

zpx_abort <- function(kind, message, ..., call = sys.call(-1L)) {
  stop(zpx_condition(kind, message, ..., call = call))
}

zpx_input_error <- function(arg, message, call = sys.call(-1L)) {
  zpx_abort("input", message, arg = arg, call = call)
}

zpx_limit_error <- function(limit, value, cap, message, call = sys.call(-1L)) {
  zpx_abort(
    "limit",
    message,
    limit = limit,
    value = as.double(value),
    cap = as.double(cap),
    call = call
  )
}

# zpx_status in inst/include/zupix.h, in order from ZPX_ERR_FORMAT. The
# last, ZPX_ERR_SINK, is the encoder's sink failing: from R the sink is a
# growable buffer (src/zpx_sink.c), which fails only when out of memory.
zpx_status_kinds <- c(
  "format",
  "decode",
  "unsupported",
  "limit",
  "memory",
  "input",
  "encode",
  "memory"
)

# zpx_limit_kind in src/zpx_core.h, in order from ZPX_LIMIT_SIDE.
zpx_limit_names <- c("max_side", "max_pixels", "max_bytes", "max_metadata")

zpx_formats <- c("png", "jpeg", "webp", "qoi")

# Raises the condition a C-level zupix_failure describes.
zpx_raise_failure <- function(f, format, call = sys.call(-1L)) {
  kind <- if (f$status >= 1L && f$status <= length(zpx_status_kinds)) {
    zpx_status_kinds[[f$status]]
  } else {
    "internal"
  }
  fmt <- if (is.na(format)) "image" else toupper(format)
  if (kind == "limit") {
    limit <- zpx_limit_names[[f$limit]]
    message <- switch(
      limit,
      max_side = sprintf(
        "%s has a side of %s pixels, more than `max_side` (%s).",
        fmt,
        fmt_num(f$value),
        fmt_num(f$cap)
      ),
      max_pixels = sprintf(
        "%s has %s pixels, more than `max_pixels` (%s).",
        fmt,
        fmt_num(f$value),
        fmt_num(f$cap)
      ),
      max_bytes = sprintf(
        paste(
          "Decoding this %s needs %s bytes, more than `max_bytes` (%s).",
          "`as = \"native\"` needs the least memory."
        ),
        fmt,
        fmt_num(f$value),
        fmt_num(f$cap)
      ),
      sprintf("%s exceeds `%s`.", fmt, limit)
    )
    # zpx_limit_error() never returns, nor does any zpx_abort() below.
    zpx_limit_error(limit, f$value, f$cap, message, call = call)
  }
  # A format mismatch carries format codes, not limit numbers: `cap` is the
  # format asked for and `value` the one the signature shows.
  if (kind == "format" && f$cap > 0) {
    message <- sprintf(
      "`format` is \"%s\" but the input is %s.",
      zpx_formats[[f$cap]],
      toupper(zpx_formats[[f$value]])
    )
    zpx_abort(kind, message, format = format, detail = f$detail, call = call)
  }
  message <- switch(
    kind,
    format = "The input is not a PNG, JPEG, WebP or QOI image.",
    decode = sprintf("Can't decode %s: %s.", fmt, f$detail),
    unsupported = sprintf("%s uses an unsupported feature: %s.", fmt, f$detail),
    input = paste0(
      toupper(substr(f$detail, 1, 1)),
      substring(f$detail, 2),
      "."
    ),
    encode = sprintf("Can't encode %s: %s.", fmt, f$detail),
    memory = sprintf("Not enough memory for this %s.", fmt),
    sprintf("zupix internal error: %s.", f$detail)
  )
  if (kind == "input") {
    # The C side names the argument first, in backticks.
    arg <- regmatches(f$detail, regexpr("`[a-z_]+`", f$detail))
    arg <- if (length(arg)) gsub("`", "", arg) else NA_character_
    zpx_abort(kind, message, arg = arg, call = call)
  }
  zpx_abort(kind, message, format = format, detail = f$detail, call = call)
}

fmt_num <- function(x) {
  format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
}
