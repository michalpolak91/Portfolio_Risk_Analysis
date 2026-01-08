# R/provider_av.R
fetch_prices_av_daily <- function(symbol, api_key) {
  # Alpha Vantage daily CSV pattern is documented (example URL). :contentReference[oaicite:5]{index=5}
  # Free tier has usage limits (25 requests/day). :contentReference[oaicite:6]{index=6}
  url <- paste0(
    "https://www.alphavantage.co/query?",
    "function=TIME_SERIES_DAILY_ADJUSTED",
    "&symbol=", utils::URLencode(symbol, reserved = TRUE),
    "&apikey=", utils::URLencode(api_key, reserved = TRUE),
    "&datatype=csv",
    "&outputsize=full"
  )
  df <- utils::read.csv(url, stringsAsFactors = FALSE)
  if (!all(c("timestamp","close") %in% names(df))) {
    # AV returns error messages in CSV-ish responses sometimes
    stop("Alpha Vantage response format unexpected (check API key, symbol, or rate limit).")
  }
  df$date <- as.Date(df$timestamp)
  df$close <- as.numeric(df$close)
  df <- df[order(df$date), c("date","close")]
  if (nrow(df) < 2) stop("Not enough rows returned.")
  df
}
