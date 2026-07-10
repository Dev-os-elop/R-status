# RStudio Status progress integration test
#
# Select the whole file and run:
# Addins -> Run Selection with Status
#
# The progress bar and remaining time appear below R Resource Usage only while
# progress::progress_bar is actively reporting ticks.

library(progress)

total_steps <- 100L
pb <- progress_bar$new(
  format = "Processing [:bar] :percent ETA: :eta",
  total = total_steps,
  clear = FALSE,
  show_after = 0
)

pb$tick(0)
for (step in seq_len(total_steps)) {
  Sys.sleep(0.1)
  pb$tick(tokens = list(message = paste("step", step)))
}
