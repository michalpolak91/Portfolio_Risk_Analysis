# R/market_data_ui.R
mod_market_data_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$h4("Market Data (Stooq)"),
    tags$p(
      tags$small("Use the local symbol map to find tickers (e.g., Apple → AAPL.US). Then download from Stooq.")
    ),
    
    fluidRow(
      column(
        4,
        selectInput(ns("universe"), "Universe", choices = c("All"), selected = "All"),
        textInput(ns("query"), "Search (name or symbol)", value = "Apple"),
        actionButton(ns("search"), "Search", class = "btn-secondary"),
        hr(),
        actionButton(ns("add_selected"), "Add selected →", class = "btn-primary")
      ),
      column(
        8,
        DT::DTOutput(ns("symbols_table"))
      )
    ),
    
    hr(),
    
    fluidRow(
      column(
        6,
        textAreaInput(ns("tickers"), "Symbols to download (one per line)",
                      value = "AAPL.US\nMSFT.US\nSPY.US", rows = 7),
        checkboxInput(ns("auto_us_suffix"), "Auto-append .US if missing", value = TRUE),
        dateRangeInput(ns("dates"), "Date range",
                       start = Sys.Date() - 365, end = Sys.Date()),
        numericInput(ns("pause_sec"), "Pause between requests (seconds)",
                     value = 0.5, min = 0, step = 0.1),
        actionButton(ns("test"), "Test first symbol"),
        actionButton(ns("download"), "Download", class = "btn-primary")
      ),
      column(
        6,
        verbatimTextOutput(ns("status")),
        DT::DTOutput(ns("preview"))
      )
    )
  )
}
