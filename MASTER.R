
## ========================================================================== ##
#   Effects of Temperature and Rainfall Anomalies on Macroeconomic Variables   #
#                            The case of Mexico                                #
## ========================================================================== ##

## ========================================================================== ##
## Set up and create data ---------------------------------------------------
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

## ========================================================================== ##
## Econometric analysis -----------------------------------------------------
## ========================================================================== ##

# Descriptive plots and maps
source("10_DescriptivePlots_Economic-Climate_Regions.R")

# Estimate IRF using Local Projections fro short and medium-run climate shocks
source("11_IRF-LP_Economic-Climate_Regions.R")

# Estimate long-run effects of climate shocks using ARDL model
source("12_ARDL_Economic-Climate_Regions.R")
