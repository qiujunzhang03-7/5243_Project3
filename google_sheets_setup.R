library(googlesheets4)
library(googledrive)

gs4_auth()

ss <- gs4_create(
  "travel_planner_ab_test",
  sheets = list(
    events = data.frame(
      session_id = character(),
      group      = character(),
      event      = character(),
      step       = integer(),
      extra      = character(),
      timestamp  = character()
    )
  )
)

SERVICE_ACCOUNT_EMAIL <- "shiny-logger@atomic-optics-493505-k1.iam.gserviceaccount.com"

drive_share(
  ss,
  role = "writer",
  type = "user",
  emailAddress = SERVICE_ACCOUNT_EMAIL
)

cat("\n\n===== COPY THIS SHEET ID =====\n")
cat(as.character(ss), "\n")
cat("================================\n\n")