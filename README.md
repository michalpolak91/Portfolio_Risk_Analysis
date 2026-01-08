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

## Reproducibility

-Computation is explicitly triggered (buttons) to avoid accidental recomputation.
-Analytical logic is implemented as pure R functions in /R.
-The report is rendered using the same objects as the UI.
## 3) GitHub Actions (lint + smoke test)

This is the **minimal CI** that works for a Shiny repo (not an R package).

### 3.1 Add workflow: `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: "release"

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          packages: |
            any::lintr
            any::styler
          cache-version: 1

      - name: Lint (lintr)
        run: |
          Rscript -e "lintr::lint_dir(c('R'), exclusions = character())"
          Rscript -e "lintr::lint('app.R')"
```

### 3.2 Add workflow: .github/workflows/smoke.yml
```yaml
name: Smoke

on:
  push:
  pull_request:

jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: "release"

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          packages: |
            any::shiny
            any::DT
            any::ggplot2
            any::dplyr
            any::tidyr
            any::purrr
            any::bslib
            any::bsicons
            any::rmarkdown
            any::yaml
          cache-version: 1

      - name: Smoke test (source files)
        run: |
          Rscript -e "source('app.R'); cat('OK: app.R sourced\n')"
          Rscript -e "stopifnot(file.exists('report.Rmd')); cat('OK: report exists\n')"
          Rscript -e "stopifnot(dir.exists('R')); cat('OK: R dir exists\n')"
```
This “smoke” test checks that:

-dependencies install,
-app.R can be sourced without crashing,
-report file exists.

It avoids launching the app (which would hang CI).
