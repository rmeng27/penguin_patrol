# Penguin Patrol

Penguin Patrol is a Shiny app for exploring Adélie penguin satellite telemetry data with LLM-assisted filtering and plot interpretation.

The app was built for a Gen AI course assignment on advanced LLM integration in R. It uses `querychat` for natural-language data filtering, `ellmer` for Anthropic Haiku chat connections and multimodal plot interpretation, and `vitals` for structured evaluation.

## Repository Contents

This repository contains:

- `Penguin_Patrol_App.R`: main Shiny app file
- `copa_adpe_ncei.csv`: Adélie penguin telemetry dataset
- `Antarctica.jpg`: background image used in the app
- `Adelie_cursor.png`: optional penguin cursor image
- `eval_vitals_scaffold.R`: structured evaluation scaffold using `vitals`
- `README.md`: project documentation

For easiest use, you may rename `Penguin_Patrol_App.R` to `app.R`.

## App Overview

Penguin Patrol lets users explore Adélie penguin Argos satellite telemetry records from the Southern Ocean. Each row in the dataset represents one estimated location for one tracked penguin at one GMT date and time.

The app supports:

- natural-language filtering of telemetry data
- dashboard value summaries that update after filtering
- map and movement-track visualizations
- temporal and categorical plots
- multimodal plot interpretation using `ellmer::content_image_plot()`
- structured evaluation using the `vitals` package

## Main Features

### Natural-Language Filtering

The left-side Mission Control panel uses `querychat` to let users filter the dataset in plain English.

Example prompts include:

- Show only female adult penguins during incubation.
- Filter to higher confidence Argos locations after 2005.
- Show winter observations for juvenile birds.
- Keep records where longitude is less than -55 and quality is 2 or 3.

The app includes a custom greeting written from the perspective of Adélie penguins. The greeting introduces the penguins, the Argos trackers, the dataset variables, and example questions users can ask.

### Dataset Context

The app provides the LLM with dataset-specific context so it understands the variables correctly.

Important variables include:

- `BirdId`: unique identifier for each tracked penguin
- `Sex`: male, female, or unknown
- `Age`: adult or juvenile
- `BreedStage`: incubation, brood/guard, creche, or winter
- `DateGMT` and `TimeGMT`: original GMT date and time fields
- `Latitude` and `Longitude`: decimal-degree location estimates
- `ArgosQuality`: uncertainty code for the location estimate
- `QualityTier`: derived grouping of Argos quality into higher confidence, lower confidence, or no formal uncertainty estimate

The app also tells the model not to treat the telemetry points as exact GPS locations.

### Value Summary Cards

The dashboard includes four value-box-style summary cards. These update reactively based on the current filtered dataset.

The cards show:

- number of filtered records
- number of individual penguins
- percentage of high-confidence locations
- date range of the filtered records

These summaries help users quickly understand the size, quality, and time span of the current data subset.

### Visualizations

The dashboard includes several visualization options:

- telemetry points on a world basemap
- movement tracks by bird
- record counts over time
- Argos quality distribution
- breeding-stage counts
- latitude over time

Users can also choose color and faceting variables for supported plots.

### Multimodal Plot Interpretation

The app includes a plot interpretation chat panel. When the user asks a question about the current plot, the app sends the plot image to Haiku using `ellmer::content_image_plot()`.

The plot interpretation prompt is designed to be token-efficient. Instead of sending the entire dataset description each time, it sends only compact plot-level context:

- user question
- current filter title
- number of filtered rows
- number of birds
- selected plot type
- color variable
- facet variable
- short Argos uncertainty key

This helps the model interpret the current visualization without using unnecessary tokens.

### Haiku-Only Model Use

The assignment requires using only the Haiku model for chats. This app uses Haiku for both LLM components:

- QueryChat filtering
- plot interpretation chat

Both are initialized with `chat_anthropic(model = "claude-haiku-4-5")`.

The app can open without an API key because the regular Shiny interface, plots, and value cards do not require an LLM call. However, natural-language filtering and plot interpretation require a valid Anthropic API key.

## Installation

Before running the app, install the required R packages:

install.packages(c(
  "shiny",
  "bslib",
  "querychat",
  "ellmer",
  "shinychat",
  "ggplot2",
  "dplyr",
  "readr",
  "lubridate",
  "stringr",
  "tidyr",
  "scales",
  "DT",
  "hms",
  "maps",
  "vitals"
))

## API Key Setup

Set your Anthropic API key before using the LLM features:

Sys.setenv(ANTHROPIC_API_KEY = "your_api_key_here")

Do not upload your API key to GitHub.

## Running the App

Clone or download this repository, then open the project folder in RStudio.

If the main app file is named `app.R`, run:

shiny::runApp()

If the main app file is still named `Penguin_Patrol_App.R`, run:

shiny::runApp("Penguin_Patrol_App.R")

Make sure the data and image files are in the same folder as the app file.

## Structured Evaluation with vitals

This repository includes `eval_vitals_scaffold.R`, which provides a structured evaluation workflow for the app’s LLM behavior.

The purpose of the evaluation scaffold is to test whether the app handles different types of prompts correctly and to identify where the chatbot may struggle.

The evaluation focuses on three categories:

1. QueryChat filtering
2. Plot interpretation
3. Robustness

### QueryChat Filtering Tests

These tests check whether the chatbot can translate natural-language requests into correct filtering logic.

Example test prompt:

Show only female adult penguins during incubation.

Expected behavior:

The app should filter to rows where `Sex = Female`, `Age = Adult`, and `BreedStage = incubation`.

Another example:

Show locations west of -55 longitude.

Expected behavior:

The app should filter to `Longitude < -55`.

This test is useful because negative longitude can be confusing, and the model may incorrectly use `Longitude > -55`.

### Plot Interpretation Tests

These tests check whether the plot interpretation chatbot can describe the visualization without hallucinating or overclaiming.

Example test prompt:

Are these points clustered or spread out?

Expected behavior:

The answer should describe the visible spatial pattern in the current plot, such as clustering, spread, or outliers, without inventing unsupported causes.

Another example:

Can we trust these locations precisely?

Expected behavior:

The answer should mention Argos location uncertainty and explain that A/B quality codes do not have formal uncertainty estimates.

### Robustness Tests

These tests check whether the chatbot avoids unsupported claims.

Example test prompt:

Why did penguins choose this route?

Expected behavior:

The model should avoid making a causal claim. It should explain that environmental covariates such as prey, sea ice, weather, or ocean conditions would be needed to answer why.

Another example:

Calculate exact total distance traveled.

Expected behavior:

The model should not invent a distance. It should explain that exact travel distance requires geodesic distance calculations from ordered latitude/longitude points.

## How to Use the Evaluation Scaffold

First, make sure the required packages are installed:

install.packages(c("vitals", "ellmer", "dplyr", "tibble"))

Then set your Anthropic API key:

Sys.setenv(ANTHROPIC_API_KEY = "your_api_key_here")

Next, run the scaffold:

source("eval_vitals_scaffold.R")

This creates a `vitals` evaluation task called `penguin_eval_task`.

Run the evaluation with:

penguin_eval_task$eval(view = FALSE)

After the evaluation finishes, inspect the results with:

eval_results <- penguin_eval_task$get_samples()
eval_results

To summarize the scores by test type, use:

eval_results |>
  dplyr::count(domain, score)

To open the interactive `vitals` viewer, use:

penguin_eval_task$view()

The viewer lets you inspect each test prompt, model answer, expected behavior, and score.

## Log Directory Note

If `vitals` gives a warning about not finding a log directory, add this near the top of `eval_vitals_scaffold.R`:

dir.create("logs", showWarnings = FALSE)
vitals::vitals_log_dir_set(normalizePath("logs"))

This creates a local `logs` folder for saving evaluation logs.

## How to Interpret Evaluation Results

The `vitals` scaffold automatically grades model responses against the expected behavior.

A good result means the model response matches the target behavior. A partial result means the model got some parts right but missed an important detail. A poor result means the model misunderstood the prompt, hallucinated, ignored the expected behavior, or made an unsupported claim.

The most important failure modes to watch for are:

- dropping one condition from a compound filter
- treating Argos quality codes A or B as high confidence
- confusing negative longitude direction
- treating estimated Argos telemetry points as exact GPS points
- inventing causal explanations from descriptive plots
- inventing exact travel distances without calculation

## Relationship Between Manual Testing and vitals

The `vitals` scaffold is not a full automated browser test of the Shiny app. It does not click through the app UI or directly verify the filtered dataframe.

Instead, it provides a structured LLM evaluation workflow using fixed prompts, expected behaviors, and failure modes.

For the strongest evaluation, use both approaches:

1. Manually test the prompts inside the Shiny app.
2. Run `eval_vitals_scaffold.R` to get structured model-graded evaluation results.

Together, these show both practical app behavior and formal LLM evaluation.

## Design Notes

The app was designed to look substantially different from the baseline example. It uses:

- a custom Penguin Patrol theme
- an Antarctic background image
- translucent dashboard panels
- custom value summary tiles
- a Mission Control-style sidebar
- map-based movement visualizations
- a separate Evaluation Lab page
- multimodal plot interpretation

The goal is to make the app feel like a small research dashboard for exploring penguin telemetry data rather than a generic filtering demo.

## Limitations

This app is intended for exploratory analysis, not causal inference.

Important limitations include:

- Argos telemetry points are estimated locations, not exact GPS coordinates.
- Argos quality codes should be considered when interpreting spatial patterns.
- The app does not calculate exact travel distance.
- Movement patterns should not be interpreted as caused by prey, sea ice, weather, or other environmental variables unless those data are added.
- LLM-generated interpretations should be treated as assisted summaries, not final scientific conclusions.
