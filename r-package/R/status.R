.rstatus_json_escape <- function(x) {
  x <- enc2utf8(as.character(x %||% ""))
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub('"', '\\\\"', x)
  x <- gsub("\r", "\\\\r", x, fixed = TRUE)
  x <- gsub("\n", "\\\\n", x, fixed = TRUE)
  x <- gsub("\t", "\\\\t", x, fixed = TRUE)
  x
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Send an R execution status to the menu bar app
#'
#' @param status One of `idle`, `running`, `complete`, `fail`, or `interrupted`.
#' @param name A short task name.
#' @param message Optional detail or error message.
#' @param host Local app host.
#' @param port Local app port.
#' @return Invisibly returns `TRUE` when the event was sent, otherwise `FALSE`.
#' @export
rstatus_notify <- function(status, name = "R task", message = NULL,
                           host = "127.0.0.1", port = 47821L) {
  status <- match.arg(status, c("idle", "running", "complete", "fail", "interrupted"))
  fields <- c(
    sprintf('"status":"%s"', .rstatus_json_escape(status)),
    sprintf('"name":"%s"', .rstatus_json_escape(name)),
    sprintf('"pid":%d', Sys.getpid())
  )
  if (!is.null(message)) {
    fields <- c(fields, sprintf('"message":"%s"', .rstatus_json_escape(message)))
  }
  body <- paste0("{", paste(fields, collapse = ","), "}")
  body_raw <- charToRaw(enc2utf8(body))
  request <- paste0(
    "POST /status HTTP/1.1\r\n",
    "Host: ", host, ":", port, "\r\n",
    "Content-Type: application/json; charset=utf-8\r\n",
    "Content-Length: ", length(body_raw), "\r\n",
    "Connection: close\r\n\r\n"
  )

  connection <- tryCatch(
    socketConnection(host = host, port = port, open = "w+b", blocking = TRUE,
                     timeout = 1, encoding = "bytes"),
    error = function(e) NULL
  )
  if (is.null(connection)) {
    warning("RStudio Status \uc571\uc5d0 \uc5f0\uacb0\ud560 \uc218 \uc5c6\uc2b5\ub2c8\ub2e4. \uc571\uc774 \uc2e4\ud589 \uc911\uc778\uc9c0 \ud655\uc778\ud558\uc138\uc694.", call. = FALSE)
    return(invisible(FALSE))
  }
  on.exit(close(connection), add = TRUE)
  tryCatch({
    writeBin(c(charToRaw(request), body_raw), connection)
    flush(connection)
    response <- readLines(connection, n = 1L, warn = FALSE, encoding = "UTF-8")
    ok <- length(response) == 1L && grepl("^HTTP/1\\.[01] 200 ", response)
    if (!ok) {
      warning("RStudio Status \uc571\uc774 \uc694\uccad\uc744 \uc218\ub77d\ud558\uc9c0 \uc54a\uc558\uc2b5\ub2c8\ub2e4.", call. = FALSE)
    }
    invisible(ok)
  }, error = function(e) {
    warning("RStudio Status \uc804\uc1a1 \uc2e4\ud328: ", conditionMessage(e), call. = FALSE)
    invisible(FALSE)
  })
}

.rstatus_progress_state <- new.env(parent = emptyenv())
.rstatus_progress_state$enabled <- FALSE
.rstatus_progress_state$key <- NULL
.rstatus_progress_state$last_sent <- 0

#' Report progress to the RStudio Status menu bar app
#'
#' This is normally called automatically for `progress` and `progressr` while
#' code is executed through the RStudio Status Addin.
#'
#' @param current Current completed amount.
#' @param total Total amount.
#' @param message Optional progress label.
#' @param started_at Optional start time used to estimate remaining time.
#' @param active Whether the progress display is active.
#' @param force Send immediately instead of applying the update throttle.
#' @return Invisibly returns whether the app accepted the update.
#' @export
rstatus_progress <- function(current = NULL, total = NULL, message = NULL,
                             started_at = NULL, active = TRUE, force = FALSE) {
  if (!isTRUE(.rstatus_progress_state$enabled)) return(invisible(FALSE))

  fields <- '"active":false'
  if (isTRUE(active)) {
    current <- suppressWarnings(as.numeric(current)[1L])
    total <- suppressWarnings(as.numeric(total)[1L])
    if (!is.finite(current) || !is.finite(total) || total <= 0) {
      return(invisible(FALSE))
    }

    now <- as.numeric(Sys.time())
    start <- if (length(started_at)) suppressWarnings(as.numeric(started_at)[1L]) else NA_real_
    if (!is.finite(start)) start <- now
    key <- paste(format(start, digits = 15), format(total, digits = 15), sep = ":")
    if (!identical(.rstatus_progress_state$key, key)) {
      .rstatus_progress_state$key <- key
      .rstatus_progress_state$last_sent <- 0
    }

    final_update <- current >= total
    if (!isTRUE(force) && current > 0 && !final_update &&
        now - .rstatus_progress_state$last_sent < 0.25) {
      return(invisible(FALSE))
    }
    .rstatus_progress_state$last_sent <- now

    elapsed <- max(0, now - start)
    eta <- if (current > 0 && current < total && elapsed > 0) {
      elapsed * (total - current) / current
    } else if (final_update) {
      0
    } else {
      NA_real_
    }
    fields <- c(
      '"active":true',
      sprintf('"current":%.10g', current),
      sprintf('"total":%.10g', total)
    )
    if (is.finite(eta)) fields <- c(fields, sprintf('"etaSeconds":%.10g', eta))
    if (!is.null(message) && nzchar(paste(message, collapse = ""))) {
      fields <- c(fields, sprintf('"message":"%s"', .rstatus_json_escape(paste(message, collapse = ""))))
    }
  }

  body <- paste0("{", paste(fields, collapse = ","), "}")
  body_raw <- charToRaw(enc2utf8(body))
  request <- paste0(
    "POST /progress HTTP/1.1\r\n",
    "Host: 127.0.0.1:47821\r\n",
    "Content-Type: application/json; charset=utf-8\r\n",
    "Content-Length: ", length(body_raw), "\r\n",
    "Connection: close\r\n\r\n"
  )
  connection <- tryCatch(
    socketConnection(host = "127.0.0.1", port = 47821L, open = "w+b",
                     blocking = TRUE, timeout = 1, encoding = "bytes"),
    error = function(e) NULL
  )
  if (is.null(connection)) return(invisible(FALSE))
  on.exit(close(connection), add = TRUE)
  tryCatch({
    writeBin(c(charToRaw(request), body_raw), connection)
    flush(connection)
    response <- readLines(connection, n = 1L, warn = FALSE, encoding = "UTF-8")
    invisible(length(response) == 1L && grepl("^HTTP/1\\.[01] 200 ", response))
  }, error = function(e) invisible(FALSE))
}

#' Run R code while showing its status in the macOS menu bar
#'
#' @param expr R expression to evaluate.
#' @param name A short task name shown in the menu bar app.
#' @return The value returned by `expr`, invisibly.
#' @export
rstatus_run <- function(expr, name = deparse1(substitute(expr), nlines = 1L)) {
  expression <- substitute(expr)
  progress_hooks <- .rstatus_install_progress_integrations()
  on.exit(.rstatus_restore_progress_integrations(progress_hooks), add = TRUE)
  rstatus_notify("running", name)
  tryCatch({
    value <- eval(expression, envir = parent.frame())
    rstatus_notify("complete", name)
    invisible(value)
  }, error = function(e) {
    rstatus_notify("fail", name, conditionMessage(e))
    stop(e)
  }, interrupt = function(e) {
    rstatus_notify("interrupted", name, "Interrupted by user")
    stop(e)
  })
}
