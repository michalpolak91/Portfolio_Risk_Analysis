# app.R
library(shiny)
library(DT)
library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)
library(bslib)
library(bsicons)

# Source pure functions (includes market data module files)
purrr::walk(list.files("R", full.names = TRUE, pattern = "\\.R$"), source)

ui <- navbarPage(
  title = "Portfolio Risk Sandbox",
  theme = bslib::bs_theme(version = 5),
  
  tabPanel("Data",
           sidebarLayout(
             sidebarPanel(
               checkboxInput("use_mkt", "Use market data (Stooq)", value = FALSE),
               fileInput("file", "Upload returns CSV", accept = c(".csv")),
               checkboxInput("use_synth", "Generate synthetic data", value = FALSE),
               conditionalPanel(
                 "input.use_synth == true",
                 numericInput("n_assets", "Number of assets", value = 5, min = 2, step = 1),
                 numericInput("n_days", "Number of days", value = 750, min = 50, step = 50),
                 sliderInput("vol", "Daily volatility (per asset)", min = 0.005, max = 0.05, value = 0.015, step = 0.001),
                 sliderInput("corr", "Pairwise correlation", min = -0.5, max = 0.95, value = 0.2, step = 0.05)
               ),
               actionButton("load_data", "Load data", class = "btn-primary")
             ),
             mainPanel(
               DTOutput("data_preview"),
               verbatimTextOutput("data_validation"),
               tags$small("Returns assumed to be daily, numeric, and aligned by date.")
             )
           )
  ),
  
  tabPanel("Market Data",
           mod_market_data_ui("mkt")
  ),
  
  tabPanel("Portfolio",
           sidebarLayout(
             sidebarPanel(
               uiOutput("weights_ui"),
               checkboxInput("auto_norm", "Auto-normalize weights", value = TRUE),
               numericInput("conc_thresh", "Concentration warning threshold (%)", value = 40, min = 1, max = 100),
               actionButton("build_portfolio", "Build portfolio", class = "btn-primary")
             ),
             mainPanel(
               DTOutput("weights_table"),
               verbatimTextOutput("weights_summary")
             )
           )
  ),
  
  tabPanel("Risk",
           sidebarLayout(
             sidebarPanel(
               selectInput("method", "Method", choices = c("Historical", "Monte Carlo")),
               numericInput("alpha", "Confidence level (alpha)", value = 0.99, min = 0.9, max = 0.999, step = 0.001),
               conditionalPanel(
                 "input.method == 'Monte Carlo'",
                 numericInput("n_sims", "Number of simulations", value = 10000, min = 1000, step = 1000)
               ),
               actionButton("run_risk", "Run risk", class = "btn-primary")
             ),
             mainPanel(
               layout_columns(
                 bslib::value_box("VaR", textOutput("kpi_var"), showcase = bsicons::bs_icon("exclamation-triangle")),
                 bslib::value_box("CVaR", textOutput("kpi_cvar"), showcase = bsicons::bs_icon("activity"))
               ),
               plotOutput("loss_dist_plot", height = 320),
               card(
                 card_header("Assumptions"),
                 tags$ul(
                   tags$li("Horizon: 1 day"),
                   tags$li(textOutput("assumption_method")),
                   tags$li(textOutput("assumption_dist"))
                 )
               )
             )
           )
  ),
  
  tabPanel("Backtest",
           sidebarLayout(
             sidebarPanel(
               actionButton("run_bt", "Run backtest", class = "btn-primary")
             ),
             mainPanel(
               layout_columns(
                 bslib::value_box("Exceedance rate", textOutput("kpi_exrate"), showcase = bsicons::bs_icon("graph-up")),
                 bslib::value_box("Expected rate", textOutput("kpi_exprate"), showcase = bsicons::bs_icon("bullseye"))
               ),
               plotOutput("bt_plot", height = 340),
               tags$small("Exceedance rate above expectation indicates potential model misspecification.")
             )
           )
  ),
  
  tabPanel("Stress",
           sidebarLayout(
             sidebarPanel(
               uiOutput("stress_asset_ui"),  # <-- FIX: dynamic selector
               numericInput("shock", "Return shock (e.g. -0.05 = -5%)", value = -0.05, step = 0.01),
               actionButton("run_stress", "Apply stress", class = "btn-primary")
             ),
             mainPanel(
               DTOutput("stress_table"),
               plotOutput("stress_contrib_plot", height = 320)
             )
           )
  ),
  
  tabPanel("Report",
           sidebarLayout(
             sidebarPanel(
               actionButton("make_report", "Generate HTML report", class = "btn-primary"),
               downloadButton("download_report", "Download report")
             ),
             mainPanel(
               tags$p("The report includes: data summary, portfolio weights, VaR/CVaR results, backtest chart, stress scenario output."),
               verbatimTextOutput("report_status")
             )
           )
  )
)

server <- function(input, output, session) {
  
  # ---- Shared data store ----
  data_store <- reactiveVal(NULL)
  validation_store <- reactiveVal(list(ok = FALSE, messages = "No data loaded."))
  
  data_obj <- reactive({
    df <- data_store()
    req(df)
    list(df = df, validation = validation_store())
  })
  
  # Market data module
  mkt <- mod_market_data_server("mkt", symbol_map_path = "data/symbol_map.csv")
  
  # ---- Helpers: reset dependent state on asset universe change ----
  portfolio_store <- reactiveVal(NULL)
  risk_store <- reactiveVal(NULL)
  bt_store <- reactiveVal(NULL)
  stress_store <- reactiveVal(NULL)
  report_path <- reactiveVal(NULL)
  
  reset_downstream <- function() {
    portfolio_store(NULL)
    risk_store(NULL)
    bt_store(NULL)
    stress_store(NULL)
    report_path(NULL)
  }
  
  # ---- Push Market Data into shared store automatically ----
  observeEvent(mkt$returns(), {
    df <- mkt$returns()
    req(df)
    
    v <- validate_returns_df(df)
    data_store(df)
    validation_store(v)
    
    updateCheckboxInput(session, "use_mkt", value = TRUE)
    updateCheckboxInput(session, "use_synth", value = FALSE)
  }, ignoreInit = TRUE)
  
  # ---- Data tab load writes into shared store ----
  observeEvent(input$load_data, {
    df <- NULL
    
    if (isTRUE(input$use_mkt)) {
      df <- mkt$returns()
      req(df)
    } else if (isTRUE(input$use_synth)) {
      df <- gen_synth_returns(
        n_assets = input$n_assets,
        n_days   = input$n_days,
        vol      = input$vol,
        corr     = input$corr
      )
    } else {
      req(input$file)
      df <- read_returns_csv(input$file$datapath)
    }
    
    v <- validate_returns_df(df)
    data_store(df)
    validation_store(v)
  }, ignoreInit = TRUE)
  
  # ---- Data outputs ----
  output$data_preview <- renderDT({
    req(data_obj())
    DT::datatable(head(data_obj()$df, 100), options = list(scrollX = TRUE, pageLength = 10))
  })
  
  output$data_validation <- renderText({
    req(data_obj())
    paste(data_obj()$validation$messages, collapse = "\n")
  })
  
  # ---- Assets reactive ----
  assets <- reactive({
    req(data_obj())
    setdiff(names(data_obj()$df), "date")
  })
  
  # ---- FIX 1: dynamic Stress selector (always populated) ----
  output$stress_asset_ui <- renderUI({
    a <- assets()
    if (length(a) == 0) {
      tags$small("No assets available. Load data first.")
    } else {
      selectInput("stress_asset", "Asset", choices = a, selected = a[1])
    }
  })
  
  # ---- FIX 2: auto-reset weights when assets change ----
  observeEvent(assets(), {
    a <- assets()
    if (length(a) == 0) return()
    
    # Reset all dependent results (portfolio/risk/backtest/stress/report)
    reset_downstream()
    
    # Reset sliders to equal weights even if Shiny preserved old inputs
    eq <- round(100 / length(a), 2)
    for (nm in a) {
      updateSliderInput(session, paste0("w_", nm), value = eq)
    }
  }, ignoreInit = TRUE)
  
  # ---- WEIGHTS UI ----
  output$weights_ui <- renderUI({
    a <- assets()
    req(length(a) > 0)
    
    tagList(
      lapply(a, function(nm) {
        sliderInput(
          inputId = paste0("w_", nm),
          label   = nm,
          min     = 0, max = 100,
          value   = round(100 / length(a), 2),
          step    = 1
        )
      })
    )
  })
  
  raw_weights <- reactive({
    a <- assets()
    req(length(a) > 0)
    
    tibble(
      asset = a,
      weight_pct = map_dbl(a, ~ input[[paste0("w_", .x)]] %||% 0)
    )
  })
  
  # ---- Portfolio build (explicit trigger) ----
  observeEvent(input$build_portfolio, {
    req(data_obj())
    w <- raw_weights()
    
    res <- build_weights(w$asset, w$weight_pct, auto_normalize = isTRUE(input$auto_norm))
    warn <- concentration_warning(res$weights_norm, thresh_pct = input$conc_thresh)
    
    portfolio_store(list(weights = res, warning = warn))
    
    # invalidate downstream computations explicitly (portfolio changed)
    risk_store(NULL)
    bt_store(NULL)
    stress_store(NULL)
    report_path(NULL)
  }, ignoreInit = TRUE)
  
  portfolio_obj <- reactive({
    req(portfolio_store())
    portfolio_store()
  })
  
  output$weights_table <- renderDT({
    req(portfolio_obj())
    DT::datatable(
      portfolio_obj()$weights$summary,
      rownames = FALSE,
      options = list(dom = "t", scrollX = TRUE)
    )
  })
  
  output$weights_summary <- renderText({
    req(portfolio_obj())
    wsum <- portfolio_obj()$weights$summary
    lines <- c(
      sprintf("Sum raw weights: %.2f%%", sum(wsum$weight_pct)),
      sprintf("Sum normalized weights: %.6f", sum(wsum$weight_norm))
    )
    if (!is.null(portfolio_obj()$warning)) lines <- c(lines, portfolio_obj()$warning)
    paste(lines, collapse = "\n")
  })
  
  # ---- Portfolio returns ----
  port_returns <- reactive({
    req(data_obj(), portfolio_obj())
    df <- data_obj()$df
    w  <- portfolio_obj()$weights$weights_norm
    compute_portfolio_returns(df, w)
  })
  
  # ---- Risk (explicit trigger) ----
  observeEvent(input$run_risk, {
    req(port_returns(), input$alpha)
    
    r <- port_returns()
    out <- if (input$method == "Historical") {
      calc_var_cvar_hist(r, alpha = input$alpha)
    } else {
      req(input$n_sims)
      calc_var_cvar_mc_1d(r, alpha = input$alpha, n_sims = input$n_sims)
    }
    
    risk_store(out)
    bt_store(NULL)
    report_path(NULL)
  }, ignoreInit = TRUE)
  
  risk_obj <- reactive({
    req(risk_store())
    risk_store()
  })
  
  output$kpi_var <- renderText({ req(risk_obj()); format(risk_obj()$VaR, digits = 6) })
  output$kpi_cvar <- renderText({ req(risk_obj()); format(risk_obj()$CVaR, digits = 6) })
  
  output$assumption_method <- renderText({ paste0("Method: ", input$method) })
  output$assumption_dist <- renderText({
    if (input$method == "Monte Carlo") "MC distribution: Normal (1D, fitted to portfolio returns)"
    else "Distribution: Empirical (historical losses)"
  })
  
  output$loss_dist_plot <- renderPlot({
    req(risk_obj(), port_returns())
    plot_loss_distribution(port_returns(), var_value = risk_obj()$VaR)
  })
  
  # ---- Backtest (explicit trigger) ----
  observeEvent(input$run_bt, {
    req(port_returns(), risk_obj(), input$alpha)
    bt_store(backtest_var(port_returns(), var = risk_obj()$VaR, alpha = input$alpha))
    report_path(NULL)
  }, ignoreInit = TRUE)
  
  bt_obj <- reactive({
    req(bt_store())
    bt_store()
  })
  
  output$kpi_exrate <- renderText({ req(bt_obj()); sprintf("%.3f", bt_obj()$exceedance_rate) })
  output$kpi_exprate <- renderText({ sprintf("%.3f", 1 - input$alpha) })
  
  output$bt_plot <- renderPlot({
    req(bt_obj())
    plot_backtest(bt_obj())
  })
  
  # ---- Stress (explicit trigger) ----
  observeEvent(input$run_stress, {
    req(data_obj(), portfolio_obj(), input$stress_asset, input$shock)
    df <- data_obj()$df
    w  <- portfolio_obj()$weights$weights_norm
    stress_store(stress_portfolio_once(df, w, stress_asset = input$stress_asset, shock = input$shock))
    report_path(NULL)
  }, ignoreInit = TRUE)
  
  stress_obj <- reactive({
    req(stress_store())
    stress_store()
  })
  
  output$stress_table <- renderDT({
    req(stress_obj())
    DT::datatable(stress_obj()$summary, rownames = FALSE, options = list(dom = "t"))
  })
  
  output$stress_contrib_plot <- renderPlot({
    req(stress_obj())
    plot_stress_contrib(stress_obj()$contrib)
  })
  
  # ---- Report ----
  observeEvent(input$make_report, {
    req(data_obj(), portfolio_obj(), risk_obj())
    out <- file.path(tempdir(), "portfolio_risk_report.html")
    
    params <- list(
      data = data_obj()$df,
      weights_summary = portfolio_obj()$weights$summary,
      risk = risk_obj(),
      backtest = if (!is.null(bt_store())) bt_store() else NULL,
      stress = if (!is.null(stress_store())) stress_store() else NULL,
      method = input$method,
      alpha = input$alpha,
      n_sims = if (input$method == "Monte Carlo") input$n_sims else NA_integer_
    )
    
    rmarkdown::render(
      input = normalizePath("report.Rmd"),
      output_file = out,
      params = params,
      envir = new.env(parent = globalenv()),
      quiet = TRUE
    )
    
    report_path(out)
  }, ignoreInit = TRUE)
  
  output$download_report <- downloadHandler(
    filename = function() sprintf("portfolio_risk_report_%s.html", Sys.Date()),
    content = function(file) {
      req(report_path())
      file.copy(report_path(), file, overwrite = TRUE)
    }
  )
  
  output$report_status <- renderText({
    if (is.null(report_path())) "No report generated yet." else paste("Report ready at:", report_path())
  })
}

shinyApp(ui, server)
