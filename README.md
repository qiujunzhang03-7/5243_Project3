# Travel Planner A/B Test

**Research Question:** Does adding a progress bar increase users' completion rate in a multi-step travel planning webpage?

## Versions

- **A (control):** No progress bar
- **B (treatment):** Progress bar + step indicator ("Step 3 / 7")

## Data Collection Strategy

This project uses a **dual-stream logging architecture**:

1. **Primary: Google Sheets** (via `googlesheets4`)
   Session-level events, step transitions, completion, and dropout points.
   Real-time, session-scoped, full user journeys. Used for all statistical analysis.

2. **Supplementary: Google Analytics 4** (via `gtag.js`)
   Aggregate engagement metrics, device/browser distribution, bounce rate.
   Provides context on sample composition; not used for primary A/B inference
   due to aggregation delay (24–48h) and small-sample thresholds.

## Project Structure

```
.
├── app.R                   # Shiny app (includes A/B logic + admin dashboard)
├── deploy.R                # Script to deploy to shinyapps.io
├── secrets/
│   └── gs_key.json         # Google service account key (DO NOT commit to public repo)
├── data/
│   └── events.csv          # Local fallback log (only used if cloud fails)
└── README.md
```

## Setup (one time)

### 1. Install R packages

```r
install.packages(c("shiny", "shinyjs", "cookies",
                   "googlesheets4", "googledrive", "rsconnect"))
```

### 2. Google Cloud + Sheets setup

See the detailed guide in the team handoff doc. Quick version:

1. Create Google Cloud project, enable **Sheets API** and **Drive API**
2. Create a service account (`shiny-logger`), download its JSON key
3. Save the key as `secrets/gs_key.json`
4. Create the Google Sheet and share it with the service account's email
5. Copy the Sheet ID into `app.R` (the `SHEET_ID` variable at the top)

### 3. Google Analytics setup

1. Create a GA4 property at https://analytics.google.com/
2. Add a Web data stream; copy the **Measurement ID** (form `G-XXXXXXXXXX`)
3. Open `app.R` and replace **both occurrences** of `G-XXXXXXXXXX` with your ID
   (one in the `<script src=...>` tag, one in the `gtag('config', ...)` call)

### 4. Run locally

```r
shiny::runApp("app.R")
```

Verify in a browser:
- Right-side badge shows "Version A" or "Version B"
- A row appears in your Google Sheet (`session_start`)

## A/B Assignment Logic

Priority: **URL parameter > Cookie > Random 50/50**

- `?group=A` or `?group=B` forces assignment (for QA testing)
- Otherwise, new users are randomly assigned and the group is stored in a cookie (30-day expiry)
- Returning users see the same version; logged as `returning=TRUE`

## Events Logged

All events are written to **both** Google Sheets and Google Analytics simultaneously
(except `session_end` / `dropout`, which only go to Sheets since the session has already
disconnected and cannot send client-side events).

| event           | step               | extra                                              |
| --------------- | ------------------ | -------------------------------------------------- |
| `session_start` | 0                  | `returning=TRUE/FALSE`                             |
| `step_next`     | step left          | `time_secs=X` (seconds spent on that step)         |
| `step_back`     | step left          | `time_secs=X`                                      |
| `completed`     | 8                  | —                                                  |
| `restart`       | step when clicked  | —                                                  |
| `dropout`       | step when exited   | `dropout_at_step=X;secs_on_step=Y` *(Sheets only)* |
| `session_end`   | step when exited   | `completed=T/F;last_step_secs=X` *(Sheets only)*   |

### GA4 event parameters

Every GA event carries:
- `ab_group` — "A" or "B"
- `step` — integer 0–8
- `session_id` — matches the Sheets row, enables cross-reference
- `extra` — raw extra-info string

A/B group is also set as a **user property** (`ab_group`), so GA4's built-in
comparisons and segments work across all default reports.

## Admin Dashboard

Visit `?admin=1` to see live stats:
- Total sessions per group
- Completion rate per group
- Median dropout step per group
- Download full CSV

## Verifying GA is working

1. Open the app with browser DevTools open (F12) → Network tab
2. Filter by `collect` — you should see requests to `google-analytics.com/g/collect`
3. Or install the [GA Debugger Chrome extension](https://chrome.google.com/webstore/detail/google-analytics-debugger/jnkmfdileelhofjcijamephohjechhna)
4. In GA4 console: **Reports → Realtime** — you should see yourself within ~30 seconds
5. Custom events appear in **Reports → Events** (may take 24h to fully populate)

## Deployment

Edit `deploy.R` with your shinyapps.io credentials, then:

```r
source("deploy.R")
```

## For the Data-Analysis Teammate

Pull the data directly from Google Sheets:

```r
library(googlesheets4)
gs4_auth(path = "secrets/gs_key.json")
events <- read_sheet("PASTE_SHEET_ID", sheet = "events")

# Completion rate per group
library(dplyr)
events %>%
  group_by(group) %>%
  summarise(
    starts = n_distinct(session_id[event == "session_start"]),
    comps  = n_distinct(session_id[event == "completed"]),
    rate   = comps / starts
  )

# Dropout step distribution
events %>% filter(event == "dropout") %>% count(group, step)
```

## Security Note

`secrets/gs_key.json` grants write access to the Sheet. If pushing to a **public** GitHub repo, add `secrets/` to `.gitignore` and share the key with teammates another way. For a private class repo this is fine.
