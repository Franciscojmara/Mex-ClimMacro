
## ========================================================================== ##
#                              PREAMBLE FILE                                   #
#               Weather anomalies and Mexican macroeconomy                     #
#                           Mexican regions panel                              #
## ========================================================================== ##

# Required packages
packages <- c("dplyr", "tidyr", "lubridate", "stats", "ggplot2", "scales", "stringr",
              "tibble", "purrr", "openxlsx", "stringi", "rlang", "janitor", "zoo",
              "plm", "car", "lmtest", "ggridges", "viridis", "patchwork", "sf", 
              "latex2exp", "xtable", "seasonal", "pdftools", "readxl", "seasonal",
              "jsonlite")
for(pkg in packages){
  if(!require(pkg, character.only = TRUE)) { 
    install.packages(pkg, dependencies=TRUE)
  }
  suppressWarnings(library(pkg, character.only = TRUE))
}

# Directories
mainPath <- dirname(getwd())
dataPath <- file.path(mainPath, "Data")
figsPath <- file.path(mainPath, "Figures")
resuPath <- file.path(mainPath, "Results")

# Create directories
dname <- "Data/Preprocessed"
if(!dir.exists(dname)) dir.create(dname, recursive = TRUE)
if(!dir.exists(figsPath)) dir.create(figsPath, recursive = TRUE)
if(!dir.exists(resuPath)) dir.create(resuPath, recursive = TRUE)

# Change ma.mean in case of CONAGUA data
if(climate_db == "CONAGUA") ma.means <- 15

# Store hyper-parameters as an RData file to call in the project scripts
save(mainPath, dataPath, resuPath, figsPath, start_date, end_date, climate_db, 
     data_freq, no_regions, sead_adjst, center_dta, tempdev, ma.means, infvar, 
     IRF.hmax, alpha_LPs, faccia.def, const.data, weight_dta,
     file = "Functions/Hyper-Parameters_Scripts.RData")