# R/backtest.R
library(tibble)
library(ggplot2)

backtest_var <- function(port_ret_df, var, alpha) {
  loss <- -port_ret_df$r_p
  exceed <- loss > var
  ex_rate <- mean(exceed, na.rm = TRUE)
  
  df <- tibble::tibble(
    date = port_ret_df$date,
    loss = loss,
    VaR = var,
    exceed = exceed
  )
  
  list(
    alpha = alpha,
    VaR = var,
    exceedance_rate = ex_rate,
    expected_rate = 1 - alpha,
    series = df
  )
}

plot_backtest <- function(bt) {
  df <- bt$series
  ggplot(df, aes(x = date, y = loss)) +
    geom_line() +
    geom_hline(yintercept = bt$VaR, linewidth = 1) +
    geom_point(data = df[df$exceed %in% TRUE, ], aes(x = date, y = loss)) +
    labs(x = NULL, y = "Loss")
}
