# RStudio Status parallel resource-monitor test
#
# Select the whole file and run:
# Addins -> Run Selection with Status
#
# Expected menu values while running (approximately):
# - R processes: 4 (one main R session + three workers)
# - Parallel workers: 3
# - CPU: about 30% on a 10-core Mac when three workers each saturate one core

local({
worker_count <- 3L
cluster <- parallel::makeCluster(worker_count)
on.exit(parallel::stopCluster(cluster), add = TRUE)

message("Starting ", worker_count, " parallel workers for 20 seconds")

# Submit short batches instead of one 20-second job per worker. RStudio can
# then stop between batches, and stopCluster() only waits for the current short
# matrix operation before the worker processes disappear.
started_at <- proc.time()[["elapsed"]]
iterations <- 0L
checksum <- 0

while (proc.time()[["elapsed"]] - started_at < 20) {
  batch <- parallel::parLapply(cluster, seq_len(worker_count), function(worker) {
    values <- matrix(rnorm(400L * 400L), nrow = 400L)
    sum(diag(crossprod(values)))
  })
  checksum <- checksum + sum(unlist(batch, use.names = FALSE))
  iterations <- iterations + length(batch)
}

message(
  "Parallel test complete: ",
  iterations,
  " total iterations; checksum = ",
  format(checksum, scientific = TRUE, digits = 4)
)
})
