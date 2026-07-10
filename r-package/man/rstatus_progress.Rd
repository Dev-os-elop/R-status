\name{rstatus_progress}
\alias{rstatus_progress}
\title{Report progress to the ES Status menu bar app}
\usage{
rstatus_progress(
  current = NULL,
  total = NULL,
  message = NULL,
  started_at = NULL,
  active = TRUE,
  force = FALSE
)
}
\arguments{
\item{current}{Current completed amount.}
\item{total}{Total amount.}
\item{message}{Optional progress label.}
\item{started_at}{Optional start time used to estimate remaining time.}
\item{active}{Whether the progress display is active.}
\item{force}{Send immediately instead of applying the update throttle.}
}
\value{Invisibly returns whether the app accepted the update.}
\description{
This is normally called automatically for \code{progress} and \code{progressr}
while code is executed through the ES Status Addin.
}
