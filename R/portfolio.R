# R/portfolio.R
library(tibble)
library(dplyr)

build_weights <- function(assets, weight_pct, auto_normalize = TRUE) {
  stopifnot(length(assets) == length(weight_pct))
  w_raw <- as.numeric(weight_pct) / 100

  if (auto_normalize) {
    s <- sum(w_raw)
    w_norm <- if (s == 0) rep(0, length(w_raw)) else w_raw / s
  } else {
    w_norm <- w_raw
  }

  summary <- tibble::tibble(
    asset = assets,
    weight_pct = as.numeric(weight_pct),
    weight_norm = w_norm
  )

  list(weights_raw = w_raw, weights_norm = w_norm, summary = summary)
}

concentration_warning <- function(w_norm, thresh_pct = 40) {
  mx <- max(w_norm, na.rm = TRUE)
  if (is.finite(mx) && mx * 100 > thresh_pct) {
    sprintf("WARN: Concentration %.1f%% exceeds threshold (%.1f%%).", mx * 100, thresh_pct)
  } else {
    NULL
  }
}

compute_portfolio_returns <- function(df, w_norm) {
  stopifnot("date" %in% names(df))
  asset_cols <- setdiff(names(df), "date")
  stopifnot(length(asset_cols) == length(w_norm))

  r_mat <- as.matrix(df[asset_cols])
  r_p <- as.numeric(r_mat %*% w_norm)
  tibble::tibble(date = df$date, r_p = r_p)
}
