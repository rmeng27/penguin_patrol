
# ============================================================
# Penguin Patrol: AI Explorer for Adélie Penguin Telemetry Data
# ============================================================
#
# Required local files in the same folder as this app:
#   - copa_adpe_ncei.csv
#   - Antarctica.jpg
#   - Adelie_cursor.png
#
# Run:
#   install.packages(c(
#     "shiny", "bslib", "querychat", "ellmer", "shinychat",
#     "ggplot2", "dplyr", "readr", "lubridate", "stringr",
#     "tidyr", "scales", "DT", "hms", "maps"
#   ))
#
#   Sys.setenv(ANTHROPIC_API_KEY = "your_key_here")
#   shiny::runApp()
# ============================================================

library(shiny)
library(bslib)
library(querychat)
library(ellmer)
library(shinychat)
library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(tidyr)
library(scales)
library(DT)
library(maps)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

# Serve local images/assets.
# Put Antarctica.jpg in the same folder as this app.R.
addResourcePath("assets", normalizePath(".", mustWork = FALSE))

# -----------------------------
# 1. Data setup
# -----------------------------

raw_data <- read_csv("copa_adpe_ncei.csv", show_col_types = FALSE)

data_for_app <- raw_data |>
  rename(
    BirdId = `BirdId`,
    BreedStage = `Breed Stage`
  ) |>
  mutate(
    Sex = str_to_title(Sex),
    Age = str_to_title(Age),
    BreedStage = str_to_lower(BreedStage),
    ArgosQuality = as.character(ArgosQuality),
    ArgosQuality = factor(ArgosQuality, levels = c("3", "2", "1", "0", "A", "B"), ordered = TRUE),
    Date = dmy(DateGMT),
    Time = hms::as_hms(TimeGMT),
    DateTimeGMT = as.POSIXct(paste(DateGMT, TimeGMT), format = "%d/%m/%Y %H:%M:%S", tz = "GMT"),
    Year = year(Date),
    Month = month(Date, label = TRUE, abbr = TRUE),
    MonthNum = month(Date),
    SouthernSeason = case_when(
      MonthNum %in% c(12, 1, 2) ~ "Austral summer",
      MonthNum %in% c(3, 4, 5) ~ "Austral autumn",
      MonthNum %in% c(6, 7, 8) ~ "Austral winter",
      MonthNum %in% c(9, 10, 11) ~ "Austral spring",
      TRUE ~ NA_character_
    ),
    QualityTier = case_when(
      ArgosQuality %in% c("3", "2") ~ "Higher confidence",
      ArgosQuality %in% c("1", "0") ~ "Lower confidence",
      ArgosQuality %in% c("A", "B") ~ "No formal uncertainty estimate",
      TRUE ~ "Unknown"
    ),
    QualityMeters = case_when(
      ArgosQuality == "3" ~ "<150 m",
      ArgosQuality == "2" ~ "150-350 m",
      ArgosQuality == "1" ~ "350-1000 m",
      ArgosQuality == "0" ~ ">1000 m",
      ArgosQuality == "A" ~ "3 messages, no formal uncertainty",
      ArgosQuality == "B" ~ "2 messages, no formal uncertainty",
      TRUE ~ NA_character_
    )
  ) |>
  filter(!is.na(Latitude), !is.na(Longitude), !is.na(DateTimeGMT)) |>
  select(
    BirdId, Sex, Age, BreedStage, DateGMT, TimeGMT, Date, DateTimeGMT,
    Year, Month, SouthernSeason, Latitude, Longitude,
    ArgosQuality, QualityTier, QualityMeters
  )

total_rows <- nrow(data_for_app)

# World basemap for latitude/longitude plots.
world_map <- map_data("world")

# -----------------------------
# 2. QueryChat setup
# -----------------------------

qc_greeting <- paste0(
  "## Hello from the Adélies!\n\n",
  "We are **Adélie penguins** — small, black-and-white penguins from Antarctica, scientifically known as *Pygoscelis adeliae*. ",
  "You can recognize us by our tuxedo look, our white eye rings, and our very serious little Antarctic walk. ",
  "We live around the Antarctic coast and spend our lives moving between breeding colonies, sea ice, and the Southern Ocean in search of food like krill and fish.\n\n",
  
  "For this project, some human scientists placed **back-mounted Argos satellite transmitters** on us at the **Copacabana Colony on King George Island**. ",
  "Those trackers recorded our estimated locations in the Southern Ocean from **1996-10-29 to 2013-02-19** during austral summer breeding seasons. ",
  "Each row in this dataset is one estimated location from one of us.\n\n",
  
  "Here is what we brought you:\n\n",
  "- **BirdId**: which penguin we are\n",
  "- **Sex**: whether we were recorded as male, female, or unknown\n",
  "- **Age**: whether we were adult or juvenile\n",
  "- **BreedStage**: what part of our annual cycle we were in, such as incubation, brood/guard, creche, or winter\n",
  "- **DateGMT** and **TimeGMT**: when the location estimate was recorded\n",
  "- **Latitude** and **Longitude**: where the Argos system estimated we were\n",
  "- **ArgosQuality**: how reliable the location estimate is\n\n",
  
  "One important penguin-science warning: our locations are **not perfect GPS points**. ",
  "Argos quality code **3** usually means less than 150 m error, **2** means about 150–350 m, **1** means about 350–1000 m, and **0** means more than 1000 m. ",
  "Codes **A** and **B** do not have formal uncertainty estimates because they were based on fewer satellite messages.\n\n",
  
  "You can ask me to filter our data in plain English. Try something like:\n\n",
  "- `Show me all the locations where penguins traveled the farthest from the colony`\n",
  "- `Which penguins have the most telemetry records and what's their seasonal movement pattern?`\n",
  "- `Show winter observations for juvenile birds`\n",
  "- `Keep records where longitude is less than -55 and quality is 2 or 3`\n\n",
  
  "Once you filter the data, use the dashboard to map our movements, compare breeding stages, inspect Argos quality, and ask the plot interpreter what patterns it sees. ",
  "Please be nice to our tracks. We walked, swam, nested, babysat, and wore science backpacks for this."
)

qc_context <- paste(
  "Dataset: Adélie penguin Argos satellite telemetry from Copacabana Colony, King George Island, Southern Ocean.",
  "Each row is one estimated location for one tracked penguin at one GMT date/time.",
  "BirdId: individual penguin identifier.",
  "Sex: Male, Female, or Unknown.",
  "Age: Adult or Juvenile.",
  "BreedStage: incubation, brood/guard, creche, or winter.",
  "DateGMT and TimeGMT: original GMT date and time fields.",
  "Date, DateTimeGMT, Year, Month, and SouthernSeason: derived fields for filtering.",
  "Latitude and Longitude: decimal-degree estimated location.",
  "ArgosQuality: ordered location-quality code with levels 3, 2, 1, 0, A, B.",
  "ArgosQuality 3: generally <150m error; 2: 150-350m; 1: 350-1000m; 0: >1000m.",
  "ArgosQuality A and B: no formal uncertainty estimate.",
  "QualityTier groups ArgosQuality into Higher confidence, Lower confidence, and No formal uncertainty estimate.",
  "Do not treat telemetry points as exact GPS locations. Mention Argos uncertainty when interpreting location patterns.",
  sep = "\n"
)

qc_extra_instructions <- paste(
"Use concise statistical language.",
"When filtering, prefer exact values from categorical variables.",
"Treat ArgosQuality as a quality/uncertainty indicator, not as a biological trait.",
"Do not over-claim causal explanations from descriptive telemetry data.",
"Use the dashboard title to clearly summarize the active filter."
)

# Assignment requirement: use Haiku for all chats.
haiku_model <- "claude-haiku-4-5"

qc <- QueryChat$new(
  data_for_app,
  table_name = "adelie_telemetry",
  greeting = qc_greeting,
  client = chat_anthropic(model = haiku_model),
  data_description = qc_context,
  extra_instructions = qc_extra_instructions
)

# -----------------------------
# 3. Helper functions
# -----------------------------

safe_mode <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return("NA")
  names(sort(table(x), decreasing = TRUE))[1]
}

fmt_date_range <- function(x) {
  x <- as.Date(x)
  if (all(is.na(x)) || length(x) == 0) return("NA")
  paste0(format(min(x, na.rm = TRUE), "%Y-%m-%d"), " to ", format(max(x, na.rm = TRUE), "%Y-%m-%d"))
}

map_limits <- function(df) {
  lon_rng <- range(df$Longitude, na.rm = TRUE)
  lat_rng <- range(df$Latitude, na.rm = TRUE)
  lon_pad <- max(1.5, diff(lon_rng) * 0.12)
  lat_pad <- max(1.0, diff(lat_rng) * 0.12)

  list(
    xlim = c(lon_rng[1] - lon_pad, lon_rng[2] + lon_pad),
    ylim = c(lat_rng[1] - lat_pad, lat_rng[2] + lat_pad)
  )
}

base_world_map <- function(df) {
  lims <- map_limits(df)

  ggplot() +
    geom_polygon(
      data = world_map,
      aes(x = long, y = lat, group = group),
      fill = "#e9f3f8",
      color = "#9eb7c5",
      linewidth = 0.25
    ) +
    coord_quickmap(xlim = lims$xlim, ylim = lims$ylim, expand = FALSE)
}

build_plot <- function(df, plot_type, color_by, facet_by, selected_bird) {
  validate(need(nrow(df) > 0, "No rows after filtering. Try resetting or broadening the query."))

  color_mapping <- if (nzchar(color_by)) aes(color = .data[[color_by]]) else aes()

  p <- switch(
    plot_type,

    "map_points" = {
      base_world_map(df) +
        geom_point(
          data = df,
          mapping = modifyList(aes(x = Longitude, y = Latitude), color_mapping),
          alpha = 0.70,
          size = 1.8
        ) +
        labs(
          title = "Telemetry Locations on World Map",
          x = "Longitude",
          y = "Latitude",
          color = color_by
        )
    },

    "tracks" = {
      track_df <- df |>
        arrange(BirdId, DateTimeGMT)

      if (nzchar(selected_bird) && selected_bird != "All birds") {
        track_df <- track_df |> filter(BirdId == selected_bird)
      }

      base_world_map(track_df) +
        geom_path(
          data = track_df,
          aes(x = Longitude, y = Latitude, group = BirdId),
          alpha = 0.38,
          linewidth = 0.55,
          color = "#22566b"
        ) +
        geom_point(
          data = track_df,
          mapping = modifyList(aes(x = Longitude, y = Latitude), color_mapping),
          alpha = 0.72,
          size = 1.4
        ) +
        labs(
          title = ifelse(selected_bird == "All birds", "Movement Tracks on World Map", paste("Movement Track:", selected_bird)),
          x = "Longitude",
          y = "Latitude",
          color = color_by
        )
    },

    "time_counts" = {
      time_df <- df |>
        count(Date, name = "Records") |>
        arrange(Date)

      ggplot(time_df, aes(x = Date, y = Records)) +
        geom_line(linewidth = 0.75, color = "#22566b") +
        geom_point(alpha = 0.55, size = 1.1, color = "#22566b") +
        labs(
          title = "Telemetry Records Over Time",
          x = "Date",
          y = "Number of records"
        )
    },

    "quality_bar" = {
      ggplot(df, aes(x = ArgosQuality, fill = QualityTier)) +
        geom_bar(alpha = 0.9) +
        labs(
          title = "Argos Location Quality Distribution",
          x = "Argos quality code",
          y = "Number of records",
          fill = "Quality tier"
        )
    },

    "breed_stage" = {
      ggplot(df, aes(x = BreedStage, fill = BreedStage)) +
        geom_bar(alpha = 0.9, show.legend = FALSE) +
        coord_flip() +
        labs(
          title = "Records by Breeding Stage",
          x = "Breeding stage",
          y = "Number of records"
        )
    },

    "lat_time" = {
      ggplot(df, aes(x = DateTimeGMT, y = Latitude)) +
        geom_point(
          mapping = color_mapping,
          alpha = 0.55,
          size = 1.4
        ) +
        geom_smooth(method = "loess", se = FALSE, linewidth = 0.7, color = "#22566b") +
        labs(
          title = "Latitude Over Time",
          x = "Date/time GMT",
          y = "Latitude",
          color = color_by
        )
    }
  )

  if (nzchar(facet_by) && facet_by %in% names(df) && plot_type %in% c("map_points", "lat_time")) {
    p <- p + facet_wrap(vars(.data[[facet_by]]))
  }

  p +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 15, color = "#0e2b38"),
      plot.subtitle = element_text(color = "#496977", size = 10.5),
      axis.title = element_text(color = "#0e2b38", size = 10.5),
      axis.text = element_text(color = "#355460", size = 9.5),
      panel.grid.major = element_line(color = "#dbe7ec", linewidth = 0.35),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_text(size = 9.5),
      legend.text = element_text(size = 8.8),
      strip.text = element_text(face = "bold", color = "#0e2b38"),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}

# -----------------------------
# 4. UI
# -----------------------------

app_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly",
  base_font = font_google("Inter"),
  heading_font = font_google("Space Grotesk"),
  primary = "#1f6f8b",
  secondary = "#8ecae6",
  success = "#3a8f7b",
  info = "#7aa8bd",
  bg = "#f3f8fb",
  fg = "#102f3c"
)

ui <- page_navbar(
  title = div(class = "brand-title", "Penguin Patrol"),
  theme = app_theme,
  fillable = TRUE,
  header = tagList(
    tags$head(
      tags$style(HTML("
        :root {
  --ink: #0e2b38;
  --muted: #3f6272;
  --ice: rgba(255, 255, 255, .58);
  --ice-solid: rgba(255, 255, 255, .72);
  --line: rgba(25, 74, 92, .15);
  --blue: #1f6f8b;
}

        html, body {
          min-height: 100%;
        }

        body {
  background:
    linear-gradient(90deg, rgba(242, 249, 252, .60), rgba(242, 249, 252, .36)),
    linear-gradient(180deg, rgba(255, 255, 255, .18), rgba(255, 255, 255, .08)),
    url('assets/Antarctica.jpg');
  background-size: cover;
  background-position: center center;
  background-attachment: fixed;
  color: var(--ink);
  cursor: none;
}

        body::before {
          content: '';
          position: fixed;
          inset: 0;
          pointer-events: none;
          background:
            radial-gradient(circle at 18% 15%, rgba(255,255,255,.66), transparent 26%),
            radial-gradient(circle at 90% 8%, rgba(142,202,230,.26), transparent 22%);
          z-index: -1;
        }

        .adelie-cursor {
  position: fixed;
  top: 0;
  left: 0;
  width: 38px !important;
  height: 38px !important;
  object-fit: contain;
  z-index: 999999;
  pointer-events: none;
  user-select: none;
  transform: translate(-28%, -18%);
  filter: drop-shadow(0 2px 4px rgba(0,0,0,.22));
}

        .navbar {
          backdrop-filter: blur(18px);
          background: rgba(255,255,255,.78) !important;
          border-bottom: 1px solid var(--line);
          box-shadow: 0 8px 24px rgba(15, 55, 71, .08);
        }

        .navbar .nav-link,
        .navbar .navbar-brand,
        .brand-title {
          color: var(--ink) !important;
        }

        .brand-title {
          font-weight: 850;
          letter-spacing: .035em;
          text-transform: uppercase;
          font-size: .98rem;
        }

        .hero {
  border: 1px solid var(--line);
  border-radius: 28px;
  padding: 24px 28px;
  margin-bottom: 18px;
  background:
    linear-gradient(135deg, rgba(255,255,255,.62), rgba(224,241,248,.42));
  box-shadow: 0 14px 36px rgba(15, 55, 71, .10);
  backdrop-filter: blur(7px) saturate(1.05);
}

        .hero h1 {
          font-size: clamp(2rem, 3.55vw, 4.1rem);
          line-height: .98;
          font-weight: 850;
          margin-bottom: 10px;
          color: var(--ink);
          letter-spacing: -0.055em;
        }

        .hero p {
          font-size: 1.02rem;
          color: var(--muted);
          max-width: 920px;
          margin-bottom: 0;
        }

        .glass-card, .card {
  background: rgba(255,255,255,.56) !important;
  border: 1px solid rgba(25, 74, 92, .14) !important;
  box-shadow: 0 14px 34px rgba(15, 55, 71, .10);
  backdrop-filter: blur(8px) saturate(1.08);
  border-radius: 24px !important;
  color: var(--ink) !important;
}

        .card-header {
  font-weight: 760;
  letter-spacing: .01em;
  background: rgba(255,255,255,.42) !important;
  border-bottom: 1px solid rgba(25, 74, 92, .12) !important;
  color: var(--ink) !important;
}

        .card-body, .card p, .card label, .card div,
        .sidebar, .sidebar p, .sidebar h3, .sidebar label {
          color: var(--ink) !important;
        }

        .bslib-sidebar-layout > .sidebar {
  background: rgba(255,255,255,.48) !important;
  border-right: 1px solid rgba(25, 74, 92, .13);
  box-shadow: 10px 0 28px rgba(15, 55, 71, .07);
  backdrop-filter: blur(8px) saturate(1.08);
}

        .sidebar h3 {
          font-size: 1.35rem;
          font-weight: 800;
          margin-bottom: .75rem;
        }

        .small-note {
          color: var(--muted) !important;
          font-size: .92rem;
        }

        .stat-tile {
  min-height: 92px;
  max-height: 105px;
  overflow: hidden;
  border-radius: 22px;
  padding: 14px 18px;
  background: rgba(255,255,255,.58);
  border: 1px solid rgba(25, 74, 92, .13);
  box-shadow: 0 10px 24px rgba(15, 55, 71, .08);
  backdrop-filter: blur(8px) saturate(1.05);
}

        .stat-label {
          text-transform: uppercase;
          letter-spacing: .09em;
          font-size: .72rem;
          font-weight: 780;
          color: #527282;
          margin-bottom: 7px;
        }

        .stat-value,
.stat-value .shiny-text-output {
  font-size: 1.35rem;
  line-height: 1.05;
  font-weight: 760;
  color: var(--ink);
  letter-spacing: -0.035em;
}

        .stat-subtitle {
          font-size: .72rem;
          color: #5d7885;
          margin-top: 5px;
        }
        
        .dashboard-spacer {
  height: 20px;
}

        .plot-wrap {
          background: rgba(255,255,255,.97);
          border-radius: 24px;
          padding: 12px;
          border: 1px solid rgba(15, 55, 71, .10);
        }

        .form-control, .form-select {
          background-color: rgba(255,255,255,.94) !important;
          color: var(--ink) !important;
          border: 1px solid rgba(31,111,139,.24) !important;
          border-radius: 13px !important;
        }

        .btn {
          border-radius: 12px !important;
        }

        .shinychat-container,
        .querychat,
        .querychat * {
          color: var(--ink) !important;
        }

        .shinychat-input-textarea,
        textarea,
        input[type='text'] {
          background: rgba(255,255,255,.98) !important;
          color: var(--ink) !important;
          border: 1px solid rgba(31,111,139,.24) !important;
        }

        .shinychat-message,
        .querychat .message,
        .querychat .chat-message {
          background: rgba(255,255,255,.76) !important;
          color: var(--ink) !important;
        }

        .nav-tabs .nav-link.active,
        .nav-pills .nav-link.active {
          background-color: rgba(31,111,139,.12) !important;
          color: var(--ink) !important;
          border-color: rgba(31,111,139,.20) !important;
        }

        .selectize-input {
          background: rgba(255,255,255,.94) !important;
          color: var(--ink) !important;
          border: 1px solid rgba(31,111,139,.24) !important;
          border-radius: 13px !important;
        }
      ")),
      tags$script(HTML("
  document.addEventListener('DOMContentLoaded', function() {
    const c = document.createElement('img');
    c.className = 'adelie-cursor';
    c.src = 'assets/adelie_cursor.png';
    c.alt = '';
    c.draggable = false;
    document.body.appendChild(c);

    document.addEventListener('mousemove', function(e) {
      c.style.left = e.clientX + 'px';
      c.style.top = e.clientY + 'px';
    });

    document.addEventListener('mousedown', function() {
      c.style.transform = 'translate(-28%, -18%) scale(0.92)';
    });

    document.addEventListener('mouseup', function() {
      c.style.transform = 'translate(-28%, -18%) scale(1)';
    });
  });
"))
    )
  ),

  nav_panel(
    "Mission Dashboard",
    page_sidebar(
      fillable = TRUE,

      sidebar = sidebar(
        width = 410,
        class = "glass-card",
        h3("Mission Control"),
        p(class = "small-note", "Use natural language to filter the telemetry data. The dashboard updates from the filtered rows."),
        qc$ui()
      ),

      div(
        class = "hero",
        h1("AI-guided Adélie tracking"),
        p("Filter penguin satellite telemetry records, inspect spatial and temporal movement patterns, then ask a Haiku vision model to interpret the current plot.")
      ),

      layout_columns(
        col_widths = c(3, 3, 3, 3),
        div(
          class = "stat-tile",
          div(class = "stat-label", "Filtered records"),
          div(class = "stat-value", textOutput("vb_records")),
          div(class = "stat-subtitle", "Rows currently selected")
        ),
        div(
          class = "stat-tile",
          div(class = "stat-label", "Individual birds"),
          div(class = "stat-value", textOutput("vb_birds")),
          div(class = "stat-subtitle", "Unique BirdId values")
        ),
        div(
          class = "stat-tile",
          div(class = "stat-label", "High-confidence locations"),
          div(class = "stat-value", textOutput("vb_highq")),
          div(class = "stat-subtitle", "Argos quality 2 or 3")
        ),
        div(
          class = "stat-tile",
          div(class = "stat-label", "Date range"),
          div(class = "stat-value", textOutput("vb_dates")),
          div(class = "stat-subtitle", "GMT observation window")
        )
      ),

    
      div(class = "dashboard-spacer"),
      
      layout_columns(
        col_widths = c(8, 4),

        card(
          card_header("Tracking Visual"),
          div(
            layout_columns(
              col_widths = c(4, 4, 4),
              selectInput(
                "plot_type", "Visualization type",
                choices = c(
                  "Map: points on world map" = "map_points",
                  "Map: movement tracks on world map" = "tracks",
                  "Time: record counts" = "time_counts",
                  "Quality: Argos bar chart" = "quality_bar",
                  "Life cycle: breeding stage counts" = "breed_stage",
                  "Time: latitude trend" = "lat_time"
                ),
                selected = "map_points"
              ),
              selectInput(
                "color_by", "Color by",
                choices = c(
                  "None" = "",
                  "BirdId", "Sex", "Age", "BreedStage",
                  "Year", "Month", "SouthernSeason",
                  "ArgosQuality", "QualityTier"
                ),
                selected = "BreedStage"
              ),
              selectInput(
                "facet_by", "Facet by",
                choices = c("None" = "", "Sex", "Age", "BreedStage", "QualityTier", "SouthernSeason"),
                selected = ""
              )
            ),
            conditionalPanel(
              "input.plot_type == 'tracks'",
              selectInput("selected_bird", "Track one bird or all birds", choices = "All birds", selected = "All birds")
            ),
            div(class = "plot-wrap", plotOutput("main_plot", height = "540px")),
            p(class = "small-note", textOutput("filter_caption"))
          )
        ),

        card(
          card_header("Ask About the Current Plot"),
          p(class = "small-note", "This chat receives a screenshot of the current plot plus compact context, keeping the multimodal prompt token-efficient."),
          chat_ui("interp", height = "590px")
        )
      )
    )
  ),

  nav_panel(
    "Evaluation Lab",
    layout_columns(
      col_widths = c(5, 7),

      card(
        card_header("Structured App Evaluation Plan"),
        p("Use these test cases for the written evaluation section. They cover easy filters, compound filters, spatial filters, quality-code interpretation, and vision-based plot interpretation."),
        tags$ol(
          tags$li("Filter: female adult penguins during incubation."),
          tags$li("Filter: winter observations with Argos quality 3 or 2."),
          tags$li("Filter: juvenile birds after 2005."),
          tags$li("Filter: longitude less than -55 and latitude less than -62."),
          tags$li("Plot interpretation: ask whether mapped points are clustered or spread out."),
          tags$li("Plot interpretation: ask whether the plot supports precise movement paths; expected answer should mention Argos uncertainty."),
          tags$li("Stress test: ask a causal question like “Why did penguins choose this route?”; expected answer should avoid causal overclaiming."),
          tags$li("Stress test: ask for exact distances; expected answer should warn that the current app does not compute geodesic distance.")
        ),
        p(class = "small-note", "Full-points version: run these manually, record expected vs. observed behavior, then optionally reproduce the same cases in vitals.")
      ),

      card(
        card_header("Evaluation Rubric Template"),
        DTOutput("eval_table")
      )
    )
  ),

  nav_panel(
    "About",
    card(
      card_header("About this app"),
      markdown(
"### Penguin Patrol

This app layers two LLM workflows on top of a Shiny dashboard:

1. **QueryChat filtering** turns natural language into SQL-style filters over the telemetry dataset.
2. **Ellmer multimodal interpretation** sends the current plot image to Claude Haiku and asks for a concise statistical interpretation.

The map views plot the telemetry latitude/longitude points on a world basemap. The coordinates are still the original decimal-degree latitude and longitude values, but the plot now has coastline context instead of floating points on a blank coordinate plane.

The dataset contains Adélie penguin satellite telemetry records. Each row is a location estimate for one bird at one GMT date/time. Argos quality codes are treated as uncertainty indicators, not biological measurements.
"
      )
    )
  )
)

# -----------------------------
# 5. Server
# -----------------------------

server <- function(input, output, session) {

  qc_vals <- qc$server()

  observe({
    df <- qc_vals$df()
    birds <- sort(unique(df$BirdId))
    updateSelectInput(
      session,
      "selected_bird",
      choices = c("All birds", birds),
      selected = ifelse(isolate(input$selected_bird %||% "All birds") %in% c("All birds", birds),
                        isolate(input$selected_bird %||% "All birds"),
                        "All birds")
    )
  })

  filtered_df <- reactive({
    qc_vals$df()
  })

  output$vb_records <- renderText({
    comma(nrow(filtered_df()))
  })

  output$vb_birds <- renderText({
    comma(n_distinct(filtered_df()$BirdId))
  })

  output$vb_highq <- renderText({
    df <- filtered_df()
    if (nrow(df) == 0) return("NA")
    pct <- mean(df$ArgosQuality %in% c("3", "2"), na.rm = TRUE)
    percent(pct, accuracy = 0.1)
  })

  output$vb_dates <- renderText({
    fmt_date_range(filtered_df()$Date)
  })

  output$filter_caption <- renderText({
    df <- filtered_df()
    paste0(
      "Current filter: ", qc_vals$title() %||% "All data",
      " | Showing ", comma(nrow(df)), " of ", comma(total_rows), " records",
      " | Most common stage: ", safe_mode(df$BreedStage),
      " | Most common quality: ", safe_mode(as.character(df$ArgosQuality))
    )
  })

  current_plot <- reactive({
    build_plot(
      df = filtered_df(),
      plot_type = input$plot_type,
      color_by = input$color_by %||% "",
      facet_by = input$facet_by %||% "",
      selected_bird = input$selected_bird %||% "All birds"
    ) +
      labs(
        subtitle = paste0(
          qc_vals$title() %||% "All data",
          " | n = ", comma(nrow(filtered_df()))
        )
      )
  })

  output$main_plot <- renderPlot({
    print(current_plot())
  })

  eval_cases <- tibble::tribble(
    ~CaseID, ~TestType, ~TestPrompt, ~ExpectedBehavior, ~FailureModetoWatch,
    1, "QueryChat filter", "Show only female adult penguins during incubation.", "Rows should have Sex = Female, Age = Adult, BreedStage = incubation.", "Model ignores one condition or mismatches BreedStage spelling.",
    2, "QueryChat filter", "Keep high confidence Argos locations only.", "Rows should mostly/only have ArgosQuality 3 or 2, or QualityTier = Higher confidence.", "Model treats A/B as high quality.",
    3, "QueryChat filter", "Show winter records after 2005.", "Rows should have BreedStage = winter and Year > 2005.", "Date parsing confusion or filters DateGMT as text.",
    4, "QueryChat filter", "Show locations west of -55 longitude.", "Rows should have Longitude < -55.", "Longitude direction confusion because values are negative.",
    5, "Vision interpretation", "Are these points clustered or spread out?", "Answer should reference visible spatial clustering/spread without claiming exact routes.", "Overgeneralized answer not tied to plot features.",
    6, "Vision interpretation", "Can we trust these locations precisely?", "Answer should mention ArgosQuality uncertainty and A/B lack formal estimates.", "Forgets uncertainty context.",
    7, "Robustness", "Why did penguins choose this route?", "Answer should avoid causal claims and suggest environmental covariates would be needed.", "Causal overclaiming.",
    8, "Robustness", "Calculate exact total distance traveled.", "Answer should say exact distance is not currently computed from the plot alone.", "Invents a distance."
  )

  output$eval_table <- renderDT({
    datatable(eval_cases, options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
  })

  interp_chat <- chat_anthropic(
    model = haiku_model,
    system_prompt = paste(
      "You are a concise statistics tutor interpreting one plot from an Adélie penguin telemetry dashboard.",
      "Use 3-5 bullets max.",
      "Refer only to visible plot features and the provided context.",
      "Mention Argos uncertainty when discussing location precision.",
      "Avoid causal claims unless the plot directly supports them.",
      "If the user's request needs calculations not shown in the plot, say what additional computation is needed."
    )
  )

  observeEvent(input$interp_user_input, {
    df <- filtered_df()
    req(nrow(df) > 0)

    # Ensure the plot is available on the graphics device for content_image_plot().
    print(current_plot())

    tiny_context <- paste0(
      "Question: ", input$interp_user_input, "\n",
      "Filter: ", qc_vals$title() %||% "All data", "\n",
      "Rows: ", nrow(df), "/", total_rows, "\n",
      "Birds: ", n_distinct(df$BirdId), "\n",
      "Plot type: ", input$plot_type, "\n",
      "Color: ", ifelse(nzchar(input$color_by), input$color_by, "none"), "\n",
      "Facet: ", ifelse(nzchar(input$facet_by), input$facet_by, "none"), "\n",
      "Argos context: 3 <150m; 2 150-350m; 1 350-1000m; 0 >1000m; A/B no formal uncertainty estimate."
    )

    chat_append(
      "interp",
      interp_chat$stream_async(
        content_image_plot(),
        tiny_context
      )
    )
  })
}

shinyApp(ui, server)
