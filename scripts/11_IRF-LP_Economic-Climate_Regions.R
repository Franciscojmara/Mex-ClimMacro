
## ========================================================================== ##
#              Local projections [Jordà (2005)]: Cumulative IRFs               #
#                    Climate anomalies vs CPI and GDP                          #
#                          Mexican regions panel                               #
## ========================================================================== ##
  
# NOTE: Data used in this script is generated from the R script: 
#    "./Code/02_Merge_Macro-Climate-data_Regions.R"


## ========================================================================== ##
## Preamble -----------------------------------------------------------------
## ========================================================================== ##

load("scripts/Functions/Hyper-Parameters_Scripts.RData")
cat(" ===========================================================\n","\n",
    "                       SHORT-RUN EFFECTS                    \n", 
    "             (LOCAL PROJECTIONS - IMPULSE RESPONSES)        \n",
    "\n","===========================================================\n")



## ========================================================================== ##
## Auxiliary functions -----------------------------------------------------
## ========================================================================== ##

# Miscellaneous functions
source("scripts/Functions/99_utils.R")

# For plots
source("scripts/Functions/99_plots.R")

# Econometrics functions
source("scripts/Functions/99_econometrics.R")



## ---------------------------------------------------------------- ##
##                              HELPERS                             ##
## ---------------------------------------------------------------- ##


## Variables to work with and helpers

#  --> Climate & price variables to analyze
tempvars  <- c("deviation.temp", "pos.dev.temp", "neg.dev.temp",
               "deviation.precip", "pos.dev.precip", "neg.dev.precip")
if(faccia.def) tempvars <- c(tempvars,"all.seasons","c.winter","h.spring","h.summer")

macro_vars <- c("headline", "food", "nonfood", "services", "agriculture",
                "energy", "gdp.total", "gdp.primarias", "gdp.secundarias",
                "gdp.terciarias")
#  --> Climate variables to plot its impulse on economic variables
temp_plot <- c("deviation.temp","pos.dev.temp","neg.dev.temp","deviation.precip",
               "pos.dev.precip", "neg.dev.precip") 
if(faccia.def) temp_plot <- c(temp_plot, "all.seasons")



## ---------------------------------------------------------------- ##
##                   Iterate by climate norms                       ##
## ---------------------------------------------------------------- ##


## Iteration
cat("\n++++++++++++++++++++++++++++++++++++++++++++++++++++\n")
for(ma.mean in ma.means) {
  
  cat("   >> LP - IRF USING CLIMATE NORM OF", ma.mean, " YEARS << \n")
  cat("++++++++++++++++++++++++++++++++++++++++++++++++++++\n\n")
  
  ## ========================================================================== ##
  ## Load & manage data -------------------------------------------------------
  ## ========================================================================== ##
  
  ## Load data
  vname <- ifelse(sead_adjst, "ae-", "-")
  cname <- ifelse(center_dta, "-Centered", "")
  fname <- paste0("INPC",vname,"Climate-",toupper(climate_db),"_",data_freq,"_", 
                  no_regions, "Regions", cname, ".xlsx")
  fpath <- file.path(dataPath, fname)
  inpc.clim0 <- read.xlsx(fpath, sheet = paste("MA.mean", ma.mean, sep = "-"))
  
  ## Manage data
  inpc.clim <- initial.setup(inpc.clim0, data_freq)
  
  # Transform max horizon in months/quarters
  hmax <- ifelse(data_freq == "Monthly", IRF.hmax * 12, IRF.hmax * 4)
  
  # List to store local projections estimations
  results_lp <- vector("list", length = length(tempvars))
  names(results_lp) <- sapply(tempvars, inpc.climate.titles) 
  
  
  ## ========================================================================== ##
  ## Local projections --------------------------------------------------------
  ## ========================================================================== ##
  
  # Iterate over temperature dummies
  cat(" ** Estimate LP - IRFs: \n")
  for(temp in tempvars) {
    
    cat("\n                 ", toupper(inpc.climate.titles(temp)),"\n")
    # List to store LP coefficients
    res_lps <- vector("list", length(macro_vars))
    names(res_lps) <- paste(temp, macro_vars, sep = "-")
    
    # Iterate over INPC indices
    for(macro in macro_vars) {
      
      #----------------------------------------------------------------------#
      #               Local projections IRF estimation                       #                                                            
      #----------------------------------------------------------------------#
      
      # Print iteration
      cat(" - LP-IRF:", toupper(macro), "\n")
      
      # Prepare data for estimation
      reg.data <- panel.data.for.lp(inpc.clim, hmax, "date", "region", temp, macro)
      
      # Estimate local projections impulse-response
      lp_irf <- lapply(reg.data, lp.irf, hmax)
      
      # Manage LP-IRF estimates and calculate confidence intervals
      lp_irf <- manage.lp.res(lp_irf, alpha.ci = alpha_LPs, macro)
      
      # Store estimated IRF-LPs
      res_lps[[paste(temp, macro, sep = "-")]] <- lp_irf 
      
      #----------------------------------------------------------------------#
      #           Plot local projection impulse-responses                    #                                                            
      #----------------------------------------------------------------------#
      
      # Plot only if tempvar is any of temp_plot, and if using 30-year climate norm
      if(temp %in% temp_plot & ma.mean == 30) {
        
        # Figure: helpers
        xlabs <- ifelse(data_freq == "Quarterly", "Quarters", "Months")
        if (grepl("^gdp", macro)) {
          if (grepl("temp$", temp)) {
            ybrks <- seq(-30, 50, 20)    # GDP and temperature
          } else {
            ybrks <- seq(-0.6, 0.9, 0.3) # GDP and precipitation
          }
        } else if (macro %in% c("headline","services","nonfood")) {
          if (grepl("temp$", temp)) {
            ybrks <- seq(-8, 8, 4)    # Inflation (1) and temperature
          } else {
            ybrks <- seq(-0.2, 0.2, 0.1) # Inflation (1) and precipitation
          }
        } else {
          if (grepl("temp$", temp)) {
            ybrks <- seq(-20, 20, 8)    # Inflation (2) and temperature
          } else {
            ybrks <- seq(-0.5, 0.5, 0.2) # Inflation (2) and precipitation
          }
        }
        
        # Figure: plot LP-IRF
        (p <- ggplot() +
            geom_ribbon(aes(x = Horizon, ymin = CI.low, ymax = CI.up), data = lp_irf,
                        fill = "#228B22", alpha = 0.3) +
            geom_hline(yintercept = 0, linewidth = 0.5) +
            geom_line(aes(Horizon, Estimate, group = 1), data = lp_irf, 
                      linewidth = 1.1, color = "#228B22") +
            labs(x = xlabs, y = "", title = "") +
            scale_x_continuous(expand = c(0, 0)) +
            scale_y_continuous(breaks = ybrks, expand = c(0, 0)) +
            coord_cartesian(ylim = c(head(ybrks, 1), tail(ybrks, 1))) +
            theme_irf()
        )
        
        # Figure: export
        fname <- paste0("LP-IRF_", climate_db, "_", data_freq, "_", no_regions, 
                        "R_MA",ma.mean,"_",inpc.climate.titles(macro),".pdf")
        fpath <- file.path(figsPath,"LP-IRFs",inpc.climate.titles(temp))
        if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
        ggsave(file.path(fpath,fname), plot=p, height=4.8, width=8, units="cm")
      }
    }
    
    # Reduce LPs estimations data frame
    res_lps <- do.call(rbind, res_lps)
    rownames(res_lps) <- NULL
    
    # Store in list to export
    results_lp[[inpc.climate.titles(temp)]] <- res_lps
  }
  cat("------------------------------------------------------------\n")
  
  
  
  ## ========================================================================== ##
  ## Export local projections -------------------------------------------------
  ## ========================================================================== ##
  
  cat(" ** Exporting LP - IRFs \n")
  
  ## ******* Export raw results in RData format *******
  vname <- ifelse(sead_adjst, "ae-", "-")
  fname <- paste0("LP-IRF_INPC", vname, "GDP-", climate_db, "_", data_freq, "_", 
                  no_regions, "Regiones_MA", ma.mean, ".RData")
  fpath <- file.path(resuPath, "Raw")
  if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
  fpath <- file.path(fpath, fname)
  save(results_lp, file = fpath)
  
  ## ******* Export cleaned results to excel *******
  source("scripts/Functions/51_IRF-LP_Excel-Tables.R")
  
  ## ******* Export cleaned results to LATEX *******
  if(ma.mean == 30) source("scripts/Functions/51_IRF-LP_Latex-Tables.R")
  
  cat(" ** LP-IRF -- Climate norm:", ma.mean, "years -- Analysis done! \n \n")
  cat("\n++++++++++++++++++++++++++++++++++++++++++++++++++++\n")
}


## Clean memory
rm(list = ls())
