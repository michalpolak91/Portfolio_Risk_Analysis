# R/io.R
library(readr)
library(dplyr)

read_returns_csv <- function(path) {
  df <- readr::read_csv(path, show_col_types = FALSE)
  # standardize column name
  if (!("date" %in% names(df))) {
    stop("CSV must contain a 'date' column.")
  }
  df$date <- as.Date(df$date)
  df
}
