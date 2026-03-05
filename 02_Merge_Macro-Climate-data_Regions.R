
# ============================================================================ #
#                         Mexican regional panel of 
#                        inflation and climate data
#
#
#  ** Note 1: Main INPUTS of this script are CREATED in:
#          "./Code/01_Manage_INPC-Regions.R",
#          "./Code/01_Manage_ITAEE-GDP_Regions.R"  
#          "./Code/01_Manage_Temperature-Precipitations.R"
#  ** Note 2: Main data INPUT of this script is IMPORTED from:
#          "./Data/Raw.Data"
#  ** Note 3: Main data OUTPUT of this script is EXPORTED to:
#          "./Data"
# ============================================================================ #


## Preamble --------------------------------------------------------------------

load("Functions/Hyper-Parameters_Scripts.RData")
inputPath <- file.path(dataPath, "Preprocessed")
cat(" =================================================\n","\n",
    "       MERGING MACROECONOMIC & CLIMATE DATA      \n",
    "\n","=================================================\n\n")



## Auxiliary functions ---------------------------------------------------------

# Miscellaneous functions
source("Functions/99_utils.R")

# Manage date strings
start_date <- as.Date(start_date)
end_date   <- as.Date(end_date)

if(climate_db == "CONAGUA") ma.means <- 15



## Open macroeconomic data -----------------------------------------------------

# Open real GDP per capita data
vname <- ifelse(data_freq == "Quarterly", "-trimestral_", "-mensual_")
fname <- paste0("gdp-itaee", vname, no_regions, "region.csv")
gdp   <- read.csv(file.path(inputPath, fname))

# Open CPI data
fname <- paste0("inpc", vname, no_regions, "region.csv")
inpc  <- read.csv(file.path(inputPath, fname))



## Open & manage Disasters data ------------------------------------------------

# cat(" ***** Managing: DISASTERS DATA \n")
# 
# # Open
# fname <- paste0("disas_", no_regions, "region_EMDAT.xlsx")
# emdat <- read.xlsx(file.path(inputPath, fname))



## ---------------------------------------------------------------- ##
##            Merge all macroeconomic and climate data              ##
## ---------------------------------------------------------------- ##

# Prepare list to store final data
full_dfs <- vector("list", length = length(ma.means))
names(full_dfs) <- paste0("MA.mean-", ma.means)


# Iterate by climate norms
for(ma.mean0 in ma.means) {
  
  cat(" >> MERGING: MACRO WITH CLIMATE USING NORM", ma.mean0, "YEARS << \n")
  
  
  ## Open temperature data -----------------------------------------------------
  fname <- paste0("temp_", no_regions, "region_", toupper(climate_db), ".xlsx")
  fpath <- file.path(inputPath, fname)
  tempt <- read.xlsx(fpath, sheet = paste0("MA", ma.mean0))
  
  tempt$fecha <- as.yearqtr(tempt$fecha, format = "%Y Q%q")
  
  
  ## Open precipitation data ---------------------------------------------------
  fname  <- paste0("precip_", no_regions, "region_", toupper(climate_db), ".xlsx")
  fpath  <- file.path(inputPath, fname)
  precip <- read.xlsx(fpath, sheet = paste0("MA", ma.mean0))
  
  precip$fecha <- as.yearqtr(precip$fecha, format = "%Y Q%q")
  
  
  
  ## Merge and manage Climate and Macro data -----------------------------------
  
  # Merge temperature and precipitation data
  weather <- full_join(tempt, precip, by=c("fecha","year","quartr","season","region"))
  
  #  Manage INPC & ITAEE date
  if (data_freq == "Quarterly") {
    inpc <- mutate(inpc, fecha = as.yearqtr(fecha))
    gdp  <- mutate(gdp, fecha = as.yearqtr(date))
  } else {
    inpc <- mutate(inpc, fecha = as.Date(fecha))
    gdp  <- mutate(gdp, fecha = as.Date(date))
  }
  
  # Merge and manage
  fulldf <- inpc %>% 
    left_join(gdp, by = c("fecha", "region")) %>%
    left_join(weather,  by = c("fecha", "region")) %>% 
    select(-fecha) %>% 
    mutate(
      region_id = case_when(
        region == "nacional" ~ 0,
        region == "area.met.cdmx" ~ 1,
        region == "centro.norte" ~ 2,
        region == "centro.sur" ~ 3,
        region == "frontera.norte" ~ 4,
        region == "noreste" ~ 5,
        region == "noroeste" ~ 6,
        region == "sur" ~ 7
      )
    ) %>% 
    arrange(region_id) %>% 
    select(region_id,region,year,any_of(c("quartr","month")),season,everything()) %>% 
    select(-date)
  
  
  ## Store in list 
  full_dfs[[paste0("MA.mean-", ma.mean0)]] <- fulldf
  cat("   --> Data construction: NORM", ma.mean0, "years -- DONE! \n\n")
}



## Export constructed data to xlsx ---------------------------------------------

# File name
vname <- ifelse(sead_adjst, "ae-", "-")
cname <- ifelse(center_dta, "-Centered", "")
fname <- paste0("INPC", vname, "Climate-", toupper(climate_db), "_", data_freq, "_", 
                no_regions, "Regions", cname, ".xlsx")

# Export
write.xlsx(full_dfs, file.path(dataPath, fname))


## Clean memory
rm(list = ls())

cat(" ** CLIMATE AND PRICES DATA READY FOR ANALYSIS!!  \n\n")
