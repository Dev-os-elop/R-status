utils::globalVariables(c("self", "private"))

.queue_text_with_status <- function(code, name) {
  if (!nzchar(trimws(code))) {
    stop("\uc2e4\ud589\ud560 R \ucf54\ub4dc\uac00 \uc5c6\uc2b5\ub2c8\ub2e4.", call. = FALSE)
  }

  path <- tempfile(pattern = "rstudio-status-", fileext = ".R")
  writeLines(enc2utf8(code), path, useBytes = TRUE)

  command <- sprintf(
    "rstudiostatus::run_file_with_status(%s, name = %s, cleanup = TRUE)",
    encodeString(path, quote = '"'),
    encodeString(enc2utf8(name), quote = '"')
  )

  # Defer until the Addin callback has fully returned. If sendToConsole() is
  # called synchronously, some RStudio versions keep treating the work as an
  # Addin callback and do not expose the normal Console Busy/Stop UI.
  later::later(function() {
    tryCatch({
      rstudioapi::sendToConsole(command, execute = TRUE, focus = TRUE)
    }, error = function(e) {
      unlink(path)
      warning("RStudio Console \uc2e4\ud589 \uc2e4\ud328: ", conditionMessage(e), call. = FALSE)
    })
  }, delay = 0.1)

  invisible(path)
}

.rstatus_install_progress_integrations <- function() {
  .rstatus_progress_state$enabled <- TRUE
  .rstatus_progress_state$key <- NULL
  .rstatus_progress_state$last_sent <- 0
  hooks <- list(progress = NULL, progressr = NULL)

  if (requireNamespace("progress", quietly = TRUE)) {
    generator <- progress::progress_bar
    originals <- generator$public_methods[c("tick", "update", "terminate")]

    generator$set("public", "tick", function(len = 1, tokens = list()) {
      result <- utils::getFromNamespace("pb_tick", "progress")(self, private, len, tokens)
      label <- tokens$message %||% tokens$what %||% NULL
      rstudiostatus::rstatus_progress(
        private$current,
        private$total,
        message = label,
        started_at = private$start
      )
      invisible(result)
    }, overwrite = TRUE)
    generator$set("public", "update", function(ratio, tokens = list()) {
      result <- utils::getFromNamespace("pb_update", "progress")(self, private, ratio, tokens)
      label <- tokens$message %||% tokens$what %||% NULL
      rstudiostatus::rstatus_progress(
        private$current,
        private$total,
        message = label,
        started_at = private$start
      )
      invisible(result)
    }, overwrite = TRUE)
    generator$set("public", "terminate", function() {
      result <- utils::getFromNamespace("pb_terminate", "progress")(self, private)
      rstudiostatus::rstatus_progress(active = FALSE, force = TRUE)
      invisible(result)
    }, overwrite = TRUE)
    hooks$progress <- list(generator = generator, originals = originals)
  }

  if (requireNamespace("progressr", quietly = TRUE)) {
    old_handlers <- progressr::handlers()
    started_at <- NULL
    handler <- progressr::make_progression_handler(
      name = "rstudio_status",
      reporter = list(
        initiate = function(config, state, progression, ...) {
          started_at <<- Sys.time()
          rstudiostatus::rstatus_progress(
            0,
            config$max_steps,
            message = state$message,
            started_at = started_at,
            force = TRUE
          )
        },
        update = function(config, state, progression, ...) {
          rstudiostatus::rstatus_progress(
            state$step,
            config$max_steps,
            message = state$message,
            started_at = started_at
          )
        },
        finish = function(config, state, progression, ...) {
          rstudiostatus::rstatus_progress(
            config$max_steps,
            config$max_steps,
            message = state$message,
            started_at = started_at,
            force = TRUE
          )
        },
        interrupt = function(...) {
          rstudiostatus::rstatus_progress(active = FALSE, force = TRUE)
        }
      ),
      enable = TRUE,
      interval = 0.25,
      clear = FALSE,
      intrusiveness = 0
    )
    progressr::handlers(handler, append = TRUE)
    hooks$progressr <- old_handlers
  }

  hooks
}

.rstatus_restore_progress_integrations <- function(hooks) {
  if (!is.null(hooks$progress)) {
    for (name in names(hooks$progress$originals)) {
      hooks$progress$generator$set(
        "public",
        name,
        hooks$progress$originals[[name]],
        overwrite = TRUE
      )
    }
  }
  if (!is.null(hooks$progressr)) {
    progressr::handlers(hooks$progressr)
  }
  rstatus_progress(active = FALSE, force = TRUE)
  .rstatus_progress_state$enabled <- FALSE
  invisible(NULL)
}

#' Run an R file while showing menu bar status
#'
#' This function is used by the RStudio Addins to execute code through the
#' regular RStudio Console. Running through the Console makes RStudio's busy
#' indicator and Stop button behave like a normal user-initiated execution.
#'
#' @param path Path to an R source file.
#' @param name A short task name shown by the menu bar app.
#' @param cleanup Whether to remove `path` after execution.
#' @return The last value evaluated by `source()`, invisibly.
#' @export
run_file_with_status <- function(path, name = basename(path), cleanup = FALSE) {
  path <- normalizePath(path, mustWork = TRUE)
  if (isTRUE(cleanup)) {
    on.exit(unlink(path), add = TRUE)
  }

  progress_hooks <- .rstatus_install_progress_integrations()
  on.exit(.rstatus_restore_progress_integrations(progress_hooks), add = TRUE)

  rstatus_notify("running", name)
  tryCatch({
    connection <- file(path, open = "r", encoding = "UTF-8")
    on.exit(close(connection), add = TRUE)
    result <- source(connection, local = .GlobalEnv, echo = FALSE, keep.source = TRUE)
    rstatus_notify("complete", name)
    invisible(result$value)
  }, error = function(e) {
    rstatus_notify("fail", name, conditionMessage(e))
    stop(e)
  }, interrupt = function(e) {
    rstatus_notify("interrupted", name, "Interrupted by user")
    stop(e)
  })
}

#' Run the current RStudio selection with menu bar status
#' @export
run_selection_with_status <- function() {
  context <- rstudioapi::getActiveDocumentContext()
  code <- context$selection[[1L]]$text
  label <- if (nzchar(context$path)) basename(context$path) else "RStudio selection"
  .queue_text_with_status(code, label)
}

#' Run the current RStudio document with menu bar status
#' @export
run_current_document_with_status <- function() {
  context <- rstudioapi::getActiveDocumentContext()
  code <- paste(context$contents, collapse = "\n")
  label <- if (nzchar(context$path)) basename(context$path) else "Untitled R document"
  .queue_text_with_status(code, label)
}
