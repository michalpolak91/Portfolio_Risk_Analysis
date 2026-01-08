# R/risk.R
library(ggplot2)
library(tibble)

calc_var_cvar_hist <- function(port_ret_df, alpha = 0.99) {
  r <- port_ret_df$r_p
  loss <- -r
  
  VaR <- as.numeric(stats::quantile(loss, probs = alpha, type = 7, na.rm = TRUE))
  CVaR <- mean(loss[loss >= VaR], na.rm = TRUE)
  
  list(method = "Historical", alpha = alpha, VaR = VaR, CVaR = CVaR, loss = loss)
}

calc_var_cvar_mc_1d <- function(port_ret_df, alpha = 0.99, n_sims = 10000) {
  r <- port_ret_df$r_p
  mu <- mean(r, na.rm = TRUE)
  sd_ <- stats::sd(r, na.rm = TRUE)
  sim_r <- stats::rnorm(n_sims, mean = mu, sd = sd_)
  loss <- -sim_r
  
  VaR <- as.numeric(stats::quantile(loss, probs = alpha, type = 7, na.rm = TRUE))
  CVaR <- mean(loss[loss >= VaR], na.rm = TRUE)
  
  list(method = "Monte Carlo (1D Normal)", alpha = alpha, VaR = VaR, CVaR = CVaR, loss = loss, n_sims = n_sims)
}

plot_loss_distribution <- function(port_ret_df, var_value) {
  loss <- -port_ret_df$r_p
  ggplot(tibble::tibble(loss = loss), aes(x = loss)) +
    geom_histogram(bins = 50) +
    geom_vline(xintercept = var_value, linewidth = 1) +
    labs(x = "Loss", y = "Count")
}
