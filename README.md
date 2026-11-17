# Penguin Patrol

<p align="center">
  <strong>An interactive R Shiny application for exploring Adélie penguin satellite telemetry with natural-language filtering and LLM-assisted plot interpretation.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/R-Shiny-276DC3?logo=r&logoColor=white" alt="R">
  <img src="https://img.shields.io/badge/Anthropic-Claude-D97757" alt="Anthropic Claude">
  <img src="https://img.shields.io/badge/querychat-NL%20Filtering-4B8BBE" alt="querychat">
  <img src="https://img.shields.io/badge/vitals-Evaluation-5C7AEA" alt="vitals">
</p>

## Overview

**Penguin Patrol** combines an interactive telemetry dashboard with two LLM-assisted workflows:

1. **Natural-language filtering** turns plain-English requests into data filters over Adélie penguin telemetry records.
2. **Multimodal plot interpretation** sends the current visualization and compact context to Claude Haiku for concise, uncertainty-aware interpretation.

The application is designed for exploratory analysis. It keeps Argos location uncertainty visible and explicitly avoids causal claims that are not supported by the telemetry data.

## What the App Does

- filters telemetry records from natural-language requests
- updates summary metrics reactively after filtering
- maps telemetry locations and movement tracks
- visualizes temporal patterns, breeding stages, and Argos quality
- lets users choose color and faceting variables
- sends the current plot to Claude for LLM-assisted visual interpretation
- includes a structured evaluation workflow for filtering, interpretation, and robustness

## System Flow

```text
Natural-language request
  → QueryChat interprets the request
  → telemetry rows are filtered
  → dashboard metrics + plots update
  → optional plot question
  → current plot + compact context sent to Claude
  → concise interpretation with uncertainty constraints
```

## Key Features

### Natural-language data exploration
`querychat` lets users filter the telemetry dataset without writing R expressions manually.

Example requests include:

- show female adult penguins during incubation
- show winter observations after 2005
- keep locations west of -55 longitude
- filter to higher-confidence Argos locations

### Reactive dashboard
Summary cards update with the current filtered data and report:

- number of records
- number of individual birds
- percentage of higher-confidence locations
- date range

### Telemetry visualizations
The app supports:

- location maps
- movement tracks
- record counts over time
- Argos quality distributions
- breeding-stage counts
- latitude over time

### Multimodal interpretation
The current plot can be sent to Claude Haiku with compact plot-level context. The system prompt asks the model to describe visible patterns, acknowledge Argos uncertainty, and avoid unsupported causal claims.

### Structured evaluation
The included evaluation scaffold tests failure modes such as compound filters, negative-longitude logic, location-precision overclaims, causal explanations, and fabricated distance calculations.

## Tech Stack

| Layer | Tools |
|---|---|
| Application | R, Shiny, bslib |
| Natural-language filtering | querychat |
| LLM integration | ellmer, Anthropic Claude |
| Chat UI | shinychat |
| Visualization | ggplot2, maps |
| Data manipulation | dplyr, readr, lubridate, tidyr |
| Evaluation | vitals |

## Repository Structure

```text
penguin_patrol/
├── app.R
├── README.md
├── .Renviron.example
├── .gitignore
├── copa_adpe_ncei.csv
├── Antarctica.jpg
├── Adelie_cursor.png
└── evaluation/
    └── eval_vitals_scaffold.R
```

## Run Locally

### 1. Install required packages

```r
install.packages(c(
  "shiny", "bslib", "querychat", "ellmer", "shinychat",
  "ggplot2", "dplyr", "readr", "lubridate", "stringr",
  "tidyr", "scales", "DT", "hms", "maps", "vitals"
))
```

### 2. Configure the Anthropic API key

Copy `.Renviron.example` to `.Renviron` and add your key:

```text
ANTHROPIC_API_KEY=your_anthropic_api_key_here
```

The app interface and plots can still open without an API key; LLM-powered filtering and plot interpretation require one.

### 3. Run the app

```r
shiny::runApp()
```

## Evaluation

The evaluation scaffold covers three categories:

| Area | Example risk |
|---|---|
| Query filtering | dropping conditions or reversing negative-longitude logic |
| Plot interpretation | overstating location precision or visible patterns |
| Robustness | inventing causal explanations or exact travel distances |

The evaluation is designed to complement manual app testing rather than replace it.

## Data Notes

Each row represents an estimated location for one tracked Adélie penguin at a GMT date and time. Argos quality codes are treated as uncertainty indicators rather than biological measurements.

The dashboard is intended for descriptive exploration, not causal inference.

## Limitations

- Argos telemetry points are estimated locations rather than exact GPS coordinates.
- Location quality varies across observations.
- The app does not calculate exact travel distance.
- Descriptive movement patterns do not establish why a penguin chose a route.
- LLM-generated interpretations are assisted summaries and should not be treated as final scientific conclusions.

---

<sub>Originally developed as a graduate Generative AI project and refined for portfolio presentation.</sub>
