# R/provider_stooq.R
fetch_prices_stooq <- function(symbol, from, to) {
  # Stooq daily CSV endpoint (best-effort; may be blocked/rate-limited)
  url <- sprintf("https://stooq.com/q/d/l/?s=%s&i=d", tolower(symbol))
  
  df <- utils::read.csv(url, stringsAsFactors = FALSE)
  
  if (!("Date" %in% names(df)) || !("Close" %in% names(df))) {
    stop("Stooq response format unexpected or access blocked.")
  }
  
  df$date <- as.Date(df$Date)
  df$close <- as.numeric(df$Close)
  
  df <- df[df$date >= as.Date(from) & df$date <= as.Date(to), c("date", "close")]
  df <- df[order(df$date), ]
  
  if (nrow(df) < 2) stop("Not enough rows returned for requested range.")
  df
}
