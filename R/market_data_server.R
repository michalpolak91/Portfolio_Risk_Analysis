# R/market_data_server.R
mod_market_data_server <- function(id, symbol_map_path = "data/symbol_map.csv") {
  moduleServer(id, function(input, output, session) {
    
    status <- reactiveVal("")
    symbol_map <- reactiveVal(NULL)
    cache <- reactiveVal(list())   # in-session cache by (symbol|from|to)
    
    # Store latest computed returns so parent can observe it cleanly
    returns_store <- reactiveVal(NULL)
    prices_store  <- reactiveVal(NULL)
    
    # load symbol map once
    observeEvent(TRUE, {
      sm <- load_symbol_map(symbol_map_path)
      symbol_map(sm)
      
      univ <- sort(unique(sm$universe))
      updateSelectInput(session, "universe", choices = c("All", univ), selected = "All")
    }, once = TRUE)
    
    filtered_symbols <- eventReactive(input$search, {
      req(symbol_map())
      filter_symbol_map(symbol_map(), query = input$query, universe = input$universe)
    }, ignoreInit = FALSE)
    
    output$symbols_table <- DT::renderDT({
      req(filtered_symbols())
      DT::datatable(
        filtered_symbols(),
        selection = "multiple",
        rownames = FALSE,
        options = list(pageLength = 10, scrollX = TRUE)
      )
    })
    
    observeEvent(input$add_selected, {
      req(filtered_symbols())
      idx <- input$symbols_table_rows_selected %||% integer(0)
      if (length(idx) == 0) {
        status("INFO: No rows selected.")
        return()
      }
      
      sel <- filtered_symbols()[idx, , drop = FALSE]
      add <- sel$symbol
      
      existing <- strsplit(input$tickers %||% "", "\n")[[1]]
      existing <- trimws(existing)
      existing <- existing[nzchar(existing)]
      
      merged <- unique(c(existing, add))
      updateTextAreaInput(session, "tickers", value = paste(merged, collapse = "\n"))
      status(sprintf("OK: Added %d symbols.", length(add)))
    }, ignoreInit = TRUE)
    
    tickers <- reactive({
      x <- strsplit(input$tickers %||% "", "\n")[[1]]
      x <- trimws(x)
      x <- x[nzchar(x)]
      if (isTRUE(input$auto_us_suffix)) {
        x <- ifelse(grepl("\\.", x), x, paste0(x, ".US"))
      }
      unique(x)
    })
    
    # TEST access
    observeEvent(input$test, {
      tk <- tickers()
      req(length(tk) >= 1, input$dates)
      sym <- tk[1]
      
      tryCatch({
        p <- fetch_prices_stooq(sym, input$dates[1], input$dates[2])
        status(sprintf("OK: %s rows for %s (%s to %s)", nrow(p), sym, input$dates[1], input$dates[2]))
      }, error = function(e) {
        status(paste("ERROR:", conditionMessage(e)))
      })
    }, ignoreInit = TRUE)
    
    # DOWNLOAD + compute returns + publish to returns_store
    observeEvent(input$download, {
      tk <- tickers()
      req(length(tk) >= 1, input$dates)
      
      out <- vector("list", length(tk))
      names(out) <- tk
      
      c0 <- cache()
      
      tryCatch({
        for (sym in tk) {
          key <- paste(sym, input$dates[1], input$dates[2], sep = "|")
          if (!is.null(c0[[key]])) {
            out[[sym]] <- c0[[key]]
            next
          }
          
          Sys.sleep(input$pause_sec %||% 0)
          p <- fetch_prices_stooq(sym, input$dates[1], input$dates[2])
          
          out[[sym]] <- p
          c0[[key]] <- p
        }
        
        cache(c0)
        prices_store(out)
        
        # compute simple returns, wide by symbol
        ret_list <- lapply(names(out), function(sym) {
          p <- out[[sym]][order(out[[sym]]$date), ]
          close <- p$close
          ret <- c(NA_real_, diff(close) / head(close, -1))
          df <- data.frame(date = p$date, ret = ret)
          df <- df[!is.na(df$ret), ]
          names(df)[2] <- sym
          df
        })
        
        ret_wide <- Reduce(function(a, b) dplyr::full_join(a, b, by = "date"), ret_list) %>%
          dplyr::arrange(date)
        
        returns_store(ret_wide)
        
        status(sprintf("OK: Downloaded %d symbols. Returns ready.", length(out)))
      }, error = function(e) {
        status(paste("ERROR:", conditionMessage(e)))
      })
    }, ignoreInit = TRUE)
    
    output$status <- renderText(status())
    
    output$preview <- DT::renderDT({
      req(returns_store())
      DT::datatable(head(returns_store(), 50), options = list(scrollX = TRUE))
    })
    
    list(
      symbol_map = symbol_map,
      prices = reactive(prices_store()),
      returns = reactive(returns_store())
    )
  })
}
