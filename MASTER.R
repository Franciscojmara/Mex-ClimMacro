
## ========================================================================== ##
#   Effects of Temperature and Rainfall Anomalies on Macroeconomic Variables   #
#                            The case of Mexico                                #
## ========================================================================== ##

## ========================================================================== ##
## Set up and create data ---------------------------------------------------
## ========================================================================== ##

## *** Packages, options, and paths
source("scripts/00_Preamble.R")

## *** Data construction 

# Get and manage climate (temperature & precipitation) data
source("scripts/01_Manage_Climate_Regions.R")
# Manage macroeconomic (prices) data
source("scripts/01_Manage_INPC_Regions.R")
# Manage macroeconomic (production) data
source("scripts/01_Manage_ITAEE-GDP_Regions.R")
# Merge climate and macroeconomic data
source("scripts/02_Merge_Macro-Climate-data_Regions.R")

## ========================================================================== ##
## Econometric analysis -----------------------------------------------------
## ========================================================================== ##

# Descriptive plots and maps
source("scripts/10_DescriptivePlots_Economic-Climate_Regions.R")

# Estimate IRF using Local Projections fro short and medium-run climate shocks
source("scripts/11_IRF-LP_Economic-Climate_Regions.R")

# Estimate long-run effects of climate shocks using ARDL model
source("scripts/12_ARDL_Economic-Climate_Regions.R")
