# ============================================================
# Deploy to shinyapps.io
# Run this from the project root after everything works locally
# ============================================================

pkgs <- c("shiny", "shinyjs", "cookies", "googlesheets4", "rsconnect")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

library(rsconnect)

deployApp(
  appDir    = ".",
  appFiles  = c("app.R", "secrets/gs_key.json"),
  appName   = "MyTravel",   
  forceUpdate = TRUE
)

#   Version A：https://qiujunzhang.shinyapps.io/MyTravel/?group=A
#   Version B：https://qiujunzhang.shinyapps.io/MyTravel/?group=B
#   Random Assignment：https://qiujunzhang.shinyapps.io/MyTravel/
#   Admin：https://qiujunzhang.shinyapps.io/MyTravel/?admin=1
