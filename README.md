# Portfolio Risk Sandbox (Shiny)

Interactive Shiny app to explore portfolio risk using daily return data.
Supports Historical and Monte Carlo VaR/CVaR, a basic VaR backtest, and stress scenarios.
Designed for fast scenario iteration, explicit computation triggers, and auditable outputs.

## What this app is for
Risk / strategy users often need to answer questions like:
- “What happens to VaR if weights change?”
- “How sensitive is the portfolio to a single-asset shock?”
- “Do we see more VaR breaches than expected?”

This app provides a lightweight UI to run those checks without writing code.

## Features
- Data inputs:
  - Upload returns CSV
  - Generate synthetic returns
  - Download market data (Stooq) and compute daily returns
- Portfolio:
  - Weight sliders with optional auto-normalization
  - Concentration warning threshold
- Risk:
  - Historical VaR/CVaR (empirical losses)
  - Monte Carlo VaR/CVaR (1D normal fitted to portfolio returns)
- Backtest:
  - Exceedance rate vs expected rate
  - Visualization of losses vs VaR threshold
- Stress:
  - Deterministic return shock to one selected asset
  - Impact summary + contribution plot
- Report:
  - One-click HTML report from the same objects used in the UI

## Non-goals / limitations
- One-day horizon only
- Parametric MC is simplified (1D normal on portfolio returns)
- Stooq downloads are best-effort; may be throttled/blocked for bulk automation
- Stress scenarios are illustrative, not predictive

## Project structure
```bash
.
├── app.R
├── R/ # pure functions + Shiny modules
├── data/
│ └── symbol_map.csv # shipped ticker map for selection (offline at runtime)
├── sample_data/
├── scripts/
│ └── build_symbol_map.R
└── report.Rmd
```
## Running locally
```r
shiny::runApp()
```
## Returns CSV format
Uploaded CSV must contain:

date column

one numeric column per asset (daily returns)

Example:
date,AAPL.US,MSFT.US,SPY.US
2022-01-03,0.0042,-0.0021,0.0008

## Market data (Stooq)
-The app downloads daily close prices per symbol and computes simple daily returns.
-Symbols for US stocks typically use .US (e.g., AAPL.US).
-For robust selection, the app ships data/symbol_map.csv (S&P 500 / Nasdaq-100 map).
-You can regenerate data/symbol_map.csv using scripts/build_symbol_map.R and commit the result.
