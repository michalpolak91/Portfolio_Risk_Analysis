# R/validate.R
library(dplyr)

validate_returns_df <- function(df) {
  msgs <- character(0)
  
  if (!("date" %in% names(df))) msgs <- c(msgs, "ERROR: Missing 'date' column.")
  if (!inherits(df$date, "Date")) msgs <- c(msgs, "WARN: 'date' is not Date; coercion may be needed.")
  
  asset_cols <- setdiff(names(df), "date")
  if (length(asset_cols) < 1) msgs <- c(msgs, "ERROR: No asset return columns found.")
  
  # numeric checks
  non_num <- asset_cols[!vapply(df[asset_cols], is.numeric, logical(1))]
  if (length(non_num) > 0) msgs <- c(msgs, paste("ERROR: Non-numeric asset columns:", paste(non_num, collapse = ", ")))
  
  # missing data
  na_any <- any(is.na(df[asset_cols]))
  if (na_any) msgs <- c(msgs, "WARN: Missing values detected in returns.")
  
  list(
    ok = !any(grepl("^ERROR:", msgs)),
    messages = if (length(msgs) == 0) "OK: Data looks valid." else msgs
  )
}
