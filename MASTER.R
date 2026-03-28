
## ========================================================================== ##
#   Effects of Temperature and Rainfall Anomalies on Macroeconomic Variables   #
#                            The case of Mexico                                #
## ========================================================================== ##

## ========================================================================== ##
## Hyper-parameters ---------------------------------------------------------
## ========================================================================== ##

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
IRF.hmax   <- 2            # Max horizon for impulse-responses in years 
alpha_LPs  <- 0.05         # Confidence level to estimate LPs confidence int.
faccia.def <- FALSE        # Use the climate anomalies definition of Faccia?
tempdev    <- 0.02         # °C deviation significant weighted temp.deviations
const.data <- TRUE         # Reconstruct data-set? (Required if first time run)


## ========================================================================== ##
## Main analysis ------------------------------------------------------------
## ========================================================================== ##

## *** Packages, options, and paths
source("00_Preamble.R")

## *** Data preparation 
if (const.data) {
  # Get and manage climate (temperature & precipitation) data
  source("01_Manage_Climate_Regions.R")
  # Manage macroeconomic (prices) data
  source("01_Manage_INPC_Regions.R")
  # Manage macroeconomic (production) data
  source("01_Manage_ITAEE-GDP_Regions.R")
  # Merge climate and macroeconomic data
  source("02_Merge_Macro-Climate-data_Regions.R")
}

## *** Econometric analysis

# Descriptive plots and maps
source("10_DescriptivePlots_Economic-Climate_Regions.R")

# Estimate IRF using Local Projections fro short and medium-run climate shocks
source("11_IRF-LP_Economic-Climate_Regions.R")

# Estimate long-run effects of climate shocks using ARDL model
source("12_ARDL_Economic-Climate_Regions.R")
