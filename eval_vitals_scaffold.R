# ============================================================
# vitals Evaluation Scaffold for Penguin Patrol Shiny App
# ============================================================

library(tibble)
library(dplyr)
library(vitals)
library(ellmer)

dir.create("logs", showWarnings = FALSE)
vitals::vitals_log_dir_set(normalizePath("logs"))

# ------------------------------------------------------------
# 1. Evaluation cases using the SAME column names as the app
# ------------------------------------------------------------

eval_cases <- tibble::tribble(
  ~CaseID, ~TestType, ~TestPrompt, ~ExpectedBehavior, ~FailureModetoWatch,
  
  "filter_female_adult_incubation",
  "QueryChat filter",
  "Show only female adult penguins during incubation.",
  "The app should filter to rows where Sex = Female, Age = Adult, and BreedStage = incubation.",
  "The model drops one filter condition, mismatches the breeding-stage value, or returns unrelated rows.",
  
  "filter_argos_high_confidence",
  "QueryChat filter",
  "Keep high confidence Argos locations only.",
  "The app should keep ArgosQuality 3 or 2, or use QualityTier = Higher confidence.",
  "The model treats ArgosQuality A or B as high confidence even though A/B have no formal uncertainty estimate.",
  
  "filter_winter_after_2005",
  "QueryChat filter",
  "Show winter observations after 2005.",
  "The app should filter to BreedStage = winter and Year > 2005.",
  "The model confuses BreedStage winter with calendar winter, ignores the year condition, or filters DateGMT incorrectly as text.",
  
  "filter_negative_longitude",
  "QueryChat filter",
  "Show locations west of -55 longitude.",
  "The app should filter to Longitude < -55.",
  "The model uses Longitude > -55 because it misunderstands negative longitude direction.",
  
  "plot_spatial_pattern",
  "Plot interpretation",
  "Are these points clustered or spread out?",
  "The answer should describe the visible spatial pattern in the current plot without inventing causes.",
  "The model gives a generic answer unrelated to the plot or invents unsupported environmental explanations.",
  
  "plot_argos_uncertainty",
  "Plot interpretation",
  "Can we trust these locations precisely?",
  "The answer should mention Argos location uncertainty and explain that A/B lack formal uncertainty estimates.",
  "The model treats the plotted points as exact GPS locations or fails to discuss ArgosQuality.",
  
  "robust_causal_overclaiming",
  "Robustness",
  "Why did penguins choose this route?",
  "The answer should avoid causal claims and say environmental covariates would be needed to answer why.",
  "The model states a definite cause from the telemetry plot alone.",
  
  "robust_exact_distance",
  "Robustness",
  "Calculate exact total distance traveled.",
  "The answer should say exact distance cannot be calculated from the plot image alone and would require geodesic distance calculations from ordered latitude/longitude points.",
  "The model invents or estimates an exact distance without computation."
)

# ------------------------------------------------------------
# 2. Convert app-style eval table into vitals-style columns
# ------------------------------------------------------------

vitals_cases <- eval_cases |>
  transmute(
    id = CaseID,
    domain = TestType,
    input = TestPrompt,
    target = paste(
      "Expected behavior:", ExpectedBehavior,
      "Failure mode to penalize:", FailureModetoWatch
    )
  )

# ------------------------------------------------------------
# 3. Haiku setup
# ------------------------------------------------------------

haiku_model <- "claude-haiku-4-5"

if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY"))) {
  warning(
    "ANTHROPIC_API_KEY is not set. The vitals task will not run until an API key is provided."
  )
}

solver_chat <- chat_anthropic(
  model = haiku_model,
  system_prompt = paste(
    "You are simulating the expected behavior of the Penguin Patrol Shiny app.",
    "The app uses Adélie penguin Argos telemetry data.",
    "For filter prompts, state the correct filter logic.",
    "For plot interpretation prompts, answer cautiously and mention uncertainty when relevant.",
    "Do not invent exact calculations or causal explanations that are not supported."
  )
)

judge_chat <- chat_anthropic(model = haiku_model)

# ------------------------------------------------------------
# 4. Create vitals task
# ------------------------------------------------------------

penguin_eval_task <- Task$new(
  dataset = vitals_cases,
  solver = generate(solver_chat),
  scorer = model_graded_qa(
    partial_credit = TRUE,
    scorer_chat = judge_chat
  ),
  name = "Penguin Patrol Chatbot Evaluation"
)

# ------------------------------------------------------------
# 5. Run evaluation
# ------------------------------------------------------------

# Uncomment to run:
# penguin_eval_task$eval()

# Uncomment to view interactive results:
# penguin_eval_task$view()

# ------------------------------------------------------------
# 6. Summarize results
# ------------------------------------------------------------

# After running:
# eval_results <- vitals_bind(penguin_eval_task)
# eval_results |> count(domain, score)

# Optional: inspect individual cases
# eval_results |> select(id, domain, input, target, answer, score)
