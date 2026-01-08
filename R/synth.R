# R/synth.R
library(MASS)
library(tibble)

gen_synth_returns <- function(n_assets, n_days, vol, corr) {
  stopifnot(n_assets >= 2, n_days >= 10)
  Sigma <- matrix(corr, n_assets, n_assets)
  diag(Sigma) <- 1
  # scale to target vols
  Sigma <- (vol^2) * Sigma
  
  X <- MASS::mvrnorm(n = n_days, mu = rep(0, n_assets), Sigma = Sigma)
  colnames(X) <- paste0("Asset_", seq_len(n_assets))
  
  tibble::tibble(
    date = seq.Date(from = Sys.Date() - n_days + 1, by = "day", length.out = n_days),
    !!!as.data.frame(X)
  )
}
