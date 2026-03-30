
## ========================================================================== ##
#                              PREAMBLE FILE                                   #
#               Weather anomalies and Mexican macroeconomy                     #
#                           Mexican regions panel                              #
## ========================================================================== ##

# Required packages
packages <- c("dplyr", "tidyr", "lubridate", "stats", "ggplot2", "scales", "stringr",
              "tibble", "purrr", "openxlsx", "stringi", "rlang", "janitor", "zoo",
              "plm", "lmtest", "ggridges", "viridis", "patchwork", "car", "sf", 
              "latex2exp", "xtable", "seasonal", "pdftools", "readxl", "jsonlite")
missing <- setdiff(packages, rownames(installed.packages()))
install.packages(missing, dependencies = TRUE)
sapply(packages, require, character.only = TRUE)


# Directories
dataPath <- file.path(getwd(), "Data")
figsPath <- file.path(getwd(), "Figures")
resuPath <- file.path(getwd(), "Results")

# Create directories
dname <- "Data/Preprocessed"
if(!dir.exists(dname)) dir.create(dname, recursive = TRUE)
if(!dir.exists(figsPath)) dir.create(figsPath, recursive = TRUE)
if(!dir.exists(resuPath)) dir.create(resuPath, recursive = TRUE)


# Hyper-parameters: Data construction
start_date <- "2003-12-01" # INPC start date (so inflation starts on 2001m1)
end_date   <- "2024-12-01" # INPC end date
climate_db <- "WorldBank"  # Climate data source: "WorldBank", or "CONAGUA"
data_freq  <- "Quarterly"  # Frequency of data: "Monthly", or "Quarterly"
infvar     <- "q"          # monthly (m), quarterly (q), or yearly (y) inflation
no_regions <- 07           # Number of Mexican regions [4, 7, or 32]
sead_adjst <- TRUE         # TRUE to seasonally adjusted INPC/ITAEE data
center_dta <- FALSE        # Center data distribution?
weight_dta <- TRUE         # Use population-weighted data?
ma.means   <- c(20,30,40)  # Years to consider for the historical norm (mean)
faccia.def <- FALSE        # Use the climate anomalies definition of Faccia?
tempdev    <- 0.02         # °C deviation significant weighted temp.deviations
const.data <- TRUE         # Reconstruct data-set? (Required if first time run)

# Hyper-parameters: Econometrics
IRF.hmax   <- 2            # Max horizon for impulse-responses in years 
alpha_LPs  <- 0.05         # Confidence level to estimate LPs confidence int.


# Change ma.mean in case of CONAGUA data
if(climate_db == "CONAGUA") ma.means <- 15

# Store hyper-parameters as an RData file to call in the project scripts
save(dataPath, resuPath, figsPath, start_date, end_date, climate_db, 
     data_freq, no_regions, sead_adjst, center_dta, tempdev, ma.means, infvar, 
     IRF.hmax, alpha_LPs, faccia.def, const.data, weight_dta,
     file = "Functions/Hyper-Parameters_Scripts.RData")
