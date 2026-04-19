# Travel Planner A/B Test ✈️

An A/B test investigating whether adding a progress bar increases task-completion rates in a multi-step travel planning web application.

---

## 🚀 Overview

This project designs, deploys, and analyzes a controlled A/B experiment on a Shiny web app. Users plan a trip through a 7-step wizard (destination, travel style, budget, interests, transport, accommodation, duration) and receive a personalized itinerary. The two versions differ only in the presence of a progress bar:

- **Version A (Control):** No progress bar. Users see step content and navigation buttons only.
- **Version B (Treatment):** A progress bar with numbered dots, a gradient fill rail, and step labels appears at the top of the card.

**Research Question:** Does adding a progress bar increase users' completion rate in a multi-step travel planning webpage?

---

## 🌐 Live Application

👉 **https://qiujunzhang.shinyapps.io/MyTravel/**

Users are randomly assigned to Version A or B (50/50). Assignment is persisted via browser cookie so returning users always see the same version.

---

## 📂 Repository Structure

```
5243_Project3/
├── app.R                         # Main Shiny app (A/B test logic, logging, admin dashboard)
├── deploy.R                      # Deployment script for shinyapps.io
├── google_sheets_setup.R         # One-time script to create and share the Google Sheet
├── EDA+Visualization.ipynb       # Data cleaning, EDA, simulation, and statistical analysis
├── travel_planner_ab_test.xlsx   # Collected event data exported from Google Sheets
├── report.pdf                    # Final report
├── README.md
├── .gitignore
└── 5243Project3.Rproj
```

---

## ⚙️ Installation

Make sure you have R 4.5+ and RStudio installed.

Install required R packages:

```r
install.packages(c("shiny", "shinyjs", "cookies", "googlesheets4", "googledrive", "rsconnect"))
```

---

## 🚀 Running the App

### 🌐 Option 1: Use Online (Recommended)

Access the deployed application directly in your browser:

👉 https://qiujunzhang.shinyapps.io/MyTravel/

### 💻 Option 2: Run Locally

1. Clone the repository:
```bash
git clone https://github.com/qiujunzhang03-7/5243_Project3.git
cd 5243_Project3
```

2. The Google Sheets service account key is included at `secrets/gs_key.json`.

3. Run the app in RStudio:
```r
shiny::runApp("app.R")
```

The app will open in your browser. A badge in the top-right corner shows the assigned version (A or B).

> **Note:** Without `gs_key.json`, the app still runs but event logs will be saved to a local `data/events.csv` fallback instead of Google Sheets.

---

## 🧪 Experimental Design

### A/B Assignment
Users are assigned via a three-tier priority system:
1. **URL parameter** — `?group=A` or `?group=B` forces assignment (for QA only)
2. **Cookie persistence** — returning users stay in their original group (30-day expiry)
3. **Random 50/50** — new users are randomly assigned

### Data Collection
A dual-stream logging architecture captures every user interaction:
- **Google Sheets (primary):** Real-time, row-level event log via `googlesheets4` with service-account authentication
- **Google Analytics 4 (supplementary):** Client-side events via `gtag.js` for aggregate engagement context

### Events Logged

| Event           | Step             | Extra Info                              |
| --------------- | ---------------- | --------------------------------------- |
| `session_start` | 0                | `returning=TRUE/FALSE`                  |
| `step_next`     | step departed    | `time_secs=X`                           |
| `step_back`     | step departed    | `time_secs=X`                           |
| `completed`     | 8                | —                                       |
| `restart`       | current step     | —                                       |
| `dropout`       | exit step        | `dropout_at_step=X;secs_on_step=Y`      |
| `session_end`   | exit step        | `completed=T/F;last_step_secs=X`        |

---

## 📊 Key Results

### Real Data (31 sessions: 26 A, 5 B)
- **Group A:** 0% completion rate (0/26)
- **Group B:** 20% completion rate (1/5)
- Fisher's exact test: p = 0.161 (not significant due to small sample)

### Combined Data (Real + Simulated, 60 per group)
- **Group A:** 31.7% completion rate
- **Group B:** 66.7% completion rate
- Two-proportion z-test: χ² = 13.34, p = 0.000260

> **Note:** The combined dataset is 74% simulated. Statistical significance in the combined analysis reflects the simulation parameters, not observed user behavior. See the report for full discussion.

---

## 📈 Analysis

The full analysis pipeline is in `EDA+Visualization.ipynb`, including:
- Data cleaning and session-level aggregation
- Real-data Fisher's exact test
- Simulated data generation
- Combined-data chi-square test, t-test, and Wilcoxon test
- Visualizations: completion rate bar charts, dropout step distributions, retention curves, steps-completed boxplots

---

## 👥 Team Members

- **Qixiang Fan** — Shiny app development (UI/UX, itinerary generation, A/B version design)
- **Qiujun Zhang** — A/B test infrastructure, data logging, Google Sheets/GA integration, deployment
- **Feiran Guo** — Data cleaning, EDA, statistical analysis, visualization
- **Ayaz Khan** — Report writing

---

## 📌 Technologies Used

- R / Shiny / shinyjs
- Google Sheets API (`googlesheets4`)
- Google Analytics 4
- Python (Jupyter Notebook for analysis)
- shinyapps.io (deployment)

---

## 📄 License

This project is for academic use (STATGR5243 Project 3, Columbia University).
