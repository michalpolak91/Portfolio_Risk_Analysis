# scripts/build_symbol_map.R
# One-time script: generates data/symbol_map.csv from Wikipedia tables (S&P 500 + Nasdaq-100).
# Run manually, then commit data/symbol_map.csv into the repo.

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(readr)
})

out_dir  <- "data"
out_file <- file.path(out_dir, "symbol_map.csv")

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# -------- helpers --------
clean_ticker <- function(x) {
  x %>%
    as.character() %>%
    str_trim() %>%
    str_replace_all("\\.", "-") %>%   # Wikipedia uses BRK.B; many data vendors use BRK-B
    toupper()
}

to_stooq_us <- function(ticker) paste0(clean_ticker(ticker), ".US")

read_wiki_table <- function(url) {
  page <- read_html(url)
  tbls <- html_table(page, fill = TRUE)
  tbls
}

# -------- S&P 500 --------
# Wikipedia: List of S&P 500 companies table. :contentReference[oaicite:1]{index=1}
sp_url <- "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
sp_tbls <- read_wiki_table(sp_url)

# The first big table contains "Symbol" and "Security"
sp <- sp_tbls %>%
  purrr::keep(~ all(c("Symbol", "Security") %in% names(.x))) %>%
  purrr::pluck(1) %>%
  transmute(
    symbol   = to_stooq_us(.data$Symbol),
    name     = str_trim(.data$Security),
    exchange = NA_character_,
    universe = "SP500"
  ) %>%
  filter(nzchar(symbol), nzchar(name))

# -------- Nasdaq-100 --------
# Wikipedia: Nasdaq-100 page has "Ticker" and "Company". :contentReference[oaicite:2]{index=2}
ndx_url <- "https://en.wikipedia.org/wiki/Nasdaq-100"
ndx_tbls <- read_wiki_table(ndx_url)

ndx <- ndx_tbls %>%
  purrr::keep(~ all(c("Ticker", "Company") %in% names(.x))) %>%
  purrr::pluck(1) %>%
  transmute(
    symbol   = to_stooq_us(.data$Ticker),
    name     = str_trim(.data$Company),
    exchange = "NASDAQ",
    universe = "NASDAQ100"
  ) %>%
  filter(nzchar(symbol), nzchar(name))

# -------- combine + de-dup --------
sym <- bind_rows(sp, ndx) %>%
  mutate(
    exchange = ifelse(is.na(exchange) | !nzchar(exchange), "UNKNOWN", exchange)
  ) %>%
  group_by(symbol) %>%
  summarise(
    name     = first(na.omit(name)),
    exchange = first(exchange),
    universe = paste(sort(unique(universe)), collapse = "+"),
    .groups  = "drop"
  ) %>%
  arrange(universe, symbol)

write_csv(sym, out_file)
cat("Wrote:", out_file, "rows:", nrow(sym), "\n")

