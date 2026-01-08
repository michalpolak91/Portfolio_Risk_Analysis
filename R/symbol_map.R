# R/symbol_map.R
library(dplyr)

load_symbol_map <- function(path = "data/symbol_map.csv") {
  if (!file.exists(path)) stop("Symbol map not found: ", path)
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  
  req_cols <- c("symbol", "name", "exchange", "universe")
  miss <- setdiff(req_cols, names(df))
  if (length(miss) > 0) stop("Symbol map missing columns: ", paste(miss, collapse = ", "))
  
  df <- df %>%
    mutate(
      symbol = trimws(symbol),
      name = trimws(name),
      exchange = trimws(exchange),
      universe = trimws(universe)
    ) %>%
    filter(nzchar(symbol), nzchar(name))
  
  df
}

filter_symbol_map <- function(symbol_map, query = "", universe = "All") {
  df <- symbol_map
  
  if (!is.null(universe) && universe != "All") {
    df <- df %>% filter(.data$universe == universe)
  }
  
  q <- trimws(query %||% "")
  if (nzchar(q)) {
    ql <- tolower(q)
    df <- df %>%
      filter(
        grepl(ql, tolower(.data$symbol), fixed = TRUE) |
          grepl(ql, tolower(.data$name), fixed = TRUE)
      )
  }
  
  df %>% arrange(.data$universe, .data$symbol)
}
