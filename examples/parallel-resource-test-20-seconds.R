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

results <- parallel::clusterEvalQ(cluster, {
  started_at <- proc.time()[["elapsed"]]
  iterations <- 0L
  checksum <- 0

  while (proc.time()[["elapsed"]] - started_at < 20) {
    values <- matrix(rnorm(400L * 400L), nrow = 400L)
    checksum <- checksum + sum(diag(crossprod(values)))
    iterations <- iterations + 1L
  }

  list(iterations = iterations, checksum = checksum)
})

message(
  "Parallel test complete: ",
  sum(vapply(results, `[[`, integer(1), "iterations")),
  " total iterations"
)
})
