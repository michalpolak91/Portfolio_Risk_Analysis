# R/stress.R
library(dplyr)
library(tibble)
library(ggplot2)

stress_portfolio_once <- function(df, w_norm, stress_asset, shock) {
  asset_cols <- setdiff(names(df), "date")
  stopifnot(stress_asset %in% asset_cols)
  
  # Use last row as "current" return snapshot (simple + auditable)
  last <- df[nrow(df), asset_cols, drop = FALSE]
  base_r <- as.numeric(as.matrix(last) %*% w_norm)
  
  stressed <- last
  stressed[[stress_asset]] <- stressed[[stress_asset]] + shock
  stressed_r <- as.numeric(as.matrix(stressed) %*% w_norm)
  
  contrib <- tibble::tibble(
    asset = asset_cols,
    weight = w_norm,
    base_return = as.numeric(last[1, asset_cols]),
    stressed_return = as.numeric(stressed[1, asset_cols]),
    delta = as.numeric(stressed[1, asset_cols] - last[1, asset_cols])
  ) %>%
    mutate(weighted_delta = weight * delta)
  
  summary <- tibble::tibble(
    base_portfolio_return = base_r,
    stressed_portfolio_return = stressed_r,
    delta = stressed_r - base_r
  )
  
  list(summary = summary, contrib = contrib, stress_asset = stress_asset, shock = shock)
}

plot_stress_contrib <- function(contrib_df) {
  ggplot(contrib_df, aes(x = reorder(asset, weighted_delta), y = weighted_delta)) +
    geom_col() +
    coord_flip() +
    labs(x = NULL, y = "Weighted delta contribution")
}
