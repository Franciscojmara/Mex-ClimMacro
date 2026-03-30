
## ========================================================================== ##
#                       ARDL panel model: Estimations                          #
#                    Climate anomalies vs CPI and GDP                          #
#                          Mexican regions panel                               #
## ========================================================================== ##

# NOTE: Data used in this script is generated from the R script: 
#    "./Code/02_Merge_Macro-Climate-data_Regions.R"


## ========================================================================== ##
## Preamble -----------------------------------------------------------------
## ========================================================================== ##

load("scripts/Functions/Hyper-Parameters_Scripts.RData")
cat(" ==========================================================\n","\n",
    "                        LONG-RUN EFFECTS                   \n", 
    "                       (PANEL-ARDL MODEL)                  \n",
    "\n","==========================================================\n\n")



## ========================================================================== ##
## Auxiliary functions -----------------------------------------------------
## ========================================================================== ##

# Miscellaneous functions
source("scripts/Functions/99_utils.R")

# Econometrics functions
source("scripts/Functions/99_econometrics.R")



## ---------------------------------------------------------------- ##
##                   Iterate by climate norms                       ##
## ---------------------------------------------------------------- ##

for (ma.mean in ma.means) {
  
  cat(" +++++++++++++++++++++++++++++++++++++++++++++++++\n",
      "  >> ARDL MODEL WITH CLIMATE NORM", ma.mean, "YEARS << \n",
      "+++++++++++++++++++++++++++++++++++++++++++++++++\n\n")
  
  ## ========================================================================== ##
  ## Load & manage data -------------------------------------------------------
  ## ========================================================================== ##
  
  ## Load data
  vname <- ifelse(sead_adjst, "ae-", "-")
  cname <- ifelse(center_dta, "-Centered", "")
  fname <- paste0("INPC", vname, "Climate-", toupper(climate_db), "_", data_freq, "_", 
                  no_regions, "Regions", cname, ".xlsx")
  fpath <- file.path(dataPath, fname)
  macro.clim0 <- read.xlsx(fpath, sheet = paste("MA.mean", ma.mean, sep = "-"))
  
  
  ## Manage data
  
  # Remove variables and observations of no interest for the ARDL model
  macro.clim <- initial.setup(macro.clim0, data_freq)
  macro.clim <- select(macro.clim, -region_id) 
  macro.clim <- filter(macro.clim, region != "nacional")
  if (!faccia.def) {
    tempvars  <- c("all.seasons", "c.winter", "h.winter", "h.spring", "h.summer", 
                   "h.autumn")# Season variables to remove 
    tempvars <- c(tempvars, paste(tempvars, "or", sep = "_"))
    macro.clim <- select(macro.clim, -any_of(tempvars)) 
  }
  
  
  ## Calculate quarterly difference of GDP & climate variables
  
  # Prepare dates and some helpers for the lags
  if(data_freq == "Quarterly") date.fn<-get("quarter") else date.fn<-get("month")
  st <- c(year(head(macro.clim$date, 1)), date.fn(head(macro.clim$date, 1)))
  en <- c(year(tail(macro.clim$date, 1)), date.fn(tail(macro.clim$date, 1)))
  fq <- ifelse(data_freq == "Quarterly", 4, 12)
  byseq  <- ifelse(data_freq == "Quarterly", "-1 quarter", "-1 month")
  gdpvar <- ifelse(data_freq == "Quarterly", "q", "m") 
  
  # Calculate 1st difference of GDP/Temperature/Precipitation 
  gdp.clim <- lapply(unique(macro.clim$region), function(y){ # 1st difference climate
    # Separate data into climate and macroeconomic (log macro data)
    kep1 <- grepl("^gdp", names(macro.clim))
    dat1 <- macro.clim[macro.clim$region == y, kep1]
    dat1 <- apply(dat1, 2, log)
    kep2 <- grepl("dev", names(macro.clim))
    dat2 <- macro.clim[macro.clim$region == y, kep2]
    # First difference log(GDP)/Climate variables 
    dat1 <- apply(dat1, 2, delta.diff, 1) # GDP variables
    dat2 <- apply(dat2, 2, delta.diff, 1) # climate variables
    # Merge first differences data
    dseq <- tail(macro.clim$date, nrow(dat2))
    desc <- data.frame(region = rep(y, nrow(dat2)), date = dseq)
    datf <- cbind(desc, dat1, dat2)
    return(datf)
  })
  gdp.clim <- do.call(rbind, gdp.clim)
  
  ## Define data as panel (use "plm" package)
  gdp.clim.p <- pdata.frame(
    gdp.clim, index = c("region", "date"), drop.index = TRUE, row.names = TRUE
    )
  
  
  
  ## ========================================================================== ##
  ## Panel ARDL model ---------------------------------------------------------
  ## ========================================================================== ##
  
  
  ## ----------------------------------- ##
  ##          Fixed-effects ARDL         ##
  ## ----------------------------------- ##
  
  # `plm()` fit fixed effects model: The default behavior of the fn is to use 
  # individual effects. However, we can fit other effects:
  #  * time effects (effect = "time"),
  
  ## Helpers
  lags     <- ifelse(data_freq == "Monthly", IRF.hmax * 12, IRF.hmax * 4)
  gdp.vars <- names(gdp.clim)[grepl("gdp",names(gdp.clim))]
  ardl.gdp <- vector("list", length = length(gdp.vars))
  names(ardl.gdp) <- paste(
    "GDPpc", 
    str_to_title(sapply(gdp.vars, function(x) gsub("gdp\\.", "", x))), 
    sep = "-"
    )
  
  ## Iterate over production variables
  cat(" ** ESTIMATE PANEL-ARDL MODELS      \n")
  for (gdpv in gdp.vars) {
    
    cat("    --> Long-run effects of climate deviations to", toupper(gdpv), "\n")
    
    ## ******* Model 1 fit: with T+, T-, P+, and P- *******
    # Model 1: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(pos.dev.temp, 0:lags)", 
              "lag(neg.dev.temp, 0:lags)", "lag(pos.dev.precip, 0:lags)",
              "lag(neg.dev.precip, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 1: Fit
    mdl1 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 1: long-run coeffs
    vars <- c("pos.dev.temp", "neg.dev.temp", "pos.dev.precip", "neg.dev.precip")
    phi_FE1   <- lr.coeffs.by.var(gdpv, mdl1) # correction term
    theta_FE1 <- sapply(vars, lr.coeffs.by.var, mdl1, phi_FE1[1,gdpv]) # clim long-run
    rownames(theta_FE1) <- c("lr.coeff", "s.e.")
    
    
    ## ******* Model 2: with T+, & T- *******
    # Model 2: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(pos.dev.temp, 0:lags)", 
              "lag(neg.dev.temp, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 2: Fit
    mdl2 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 2: long-run coeffs
    vars <- c("pos.dev.temp", "neg.dev.temp")
    phi_FE2   <- lr.coeffs.by.var(gdpv, mdl2)
    theta_FE2 <- sapply(vars, lr.coeffs.by.var, mdl2, phi_FE2[1,gdpv])
    rownames(theta_FE2) <- c("lr.coeff", "s.e.")
    
    
    ## ******* Model 3: with P+, & P- *******
    # Model 3: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(pos.dev.precip, 0:lags)",
              "lag(neg.dev.precip, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 3: Fit
    mdl3 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 2: long-run coeffs
    vars <- c("pos.dev.precip", "neg.dev.precip")
    phi_FE3   <- lr.coeffs.by.var(gdpv, mdl3)
    theta_FE3 <- sapply(vars, lr.coeffs.by.var, mdl3, phi_FE3[1,gdpv])
    rownames(theta_FE3) <- c("lr.coeff", "s.e.")
    
    
    ## ******* Model 4: with |T|, & |P| *******
    # Model 4: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(abs.deviation.temp, 0:lags)",
              "lag(abs.deviation.precip, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 4: Fit
    mdl4 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 4: long-run coeffs
    vars <- c("abs.deviation.temp", "abs.deviation.precip")
    phi_FE4   <- lr.coeffs.by.var(gdpv, mdl4)
    theta_FE4 <- sapply(vars, lr.coeffs.by.var, mdl4, phi_FE4[1,gdpv])
    rownames(theta_FE4) <- c("lr.coeff", "s.e.")
    
    
    ## ******* Model 5: only |T| *******
    # Model 5: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(abs.deviation.temp, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 5: Fit
    mdl5 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 5: long-run coeffs
    phi_FE5   <- lr.coeffs.by.var(gdpv, mdl5)
    theta_FE5 <- lr.coeffs.by.var("abs.deviation.temp", mdl5, phi_FE5[1,gdpv])
    
    
    ## ******* Model 6: only |P| *******
    # Model 6: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(abs.deviation.precip, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 6: Fit
    mdl6 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 6: long-run coeffs
    phi_FE6   <- lr.coeffs.by.var(gdpv, mdl6)
    theta_FE6 <- lr.coeffs.by.var("abs.deviation.precip", mdl6, phi_FE6[1,gdpv])
    
    
    ## ******* Model 7: with T, & P *******
    # Model 7: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(deviation.temp, 0:lags)",
              "lag(deviation.precip, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 7: Fit
    mdl7 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 7: long-run coeffs
    vars <- c("deviation.temp", "deviation.precip")
    phi_FE7   <- lr.coeffs.by.var(gdpv, mdl7)
    theta_FE7 <- sapply(vars, lr.coeffs.by.var, mdl7, phi_FE7[1,gdpv])
    rownames(theta_FE7) <- c("lr.coeff", "s.e.")
    
    
    ## ******* Model 8: only T *******
    # Model 8: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(deviation.temp, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 8: Fit
    mdl8 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 8: long-run coeffs
    phi_FE8   <- lr.coeffs.by.var(gdpv, mdl8)
    theta_FE8 <- lr.coeffs.by.var("deviation.temp", mdl8, phi_FE8[1,gdpv])
    
    
    ## ******* Model 9: only P *******
    # Model 9: Define regression formula
    xvar <- c(paste0("lag(", gdpv, ", 1:lags)"), "lag(deviation.precip, 0:lags)")
    frml <- as.formula(paste(gdpv, paste(xvar, collapse = " + "), sep = " ~ "))
    # Model 9: Fit
    mdl9 <- plm(frml, data = gdp.clim.p, model = "within")
    # Model 9: long-run coeffs
    phi_FE9   <- lr.coeffs.by.var(gdpv, mdl9)
    theta_FE9 <- lr.coeffs.by.var("deviation.precip", mdl9, phi_FE9[1,gdpv])
    
    
    ## ******* Manage fixed-effects estimations *******
    
    # Store results in list
    mdls.estim.fe  <- list(
      model1 = cbind(theta_FE1, phi_FE1),
      model2 = cbind(theta_FE2, phi_FE2),
      model3 = cbind(theta_FE3, phi_FE3),
      model4 = cbind(theta_FE4, phi_FE4),
      model5 = cbind(theta_FE5, phi_FE5),
      model6 = cbind(theta_FE6, phi_FE6),
      model7 = cbind(theta_FE7, phi_FE7),
      model8 = cbind(theta_FE8, phi_FE8),
      model9 = cbind(theta_FE9, phi_FE9)
    )
    
    # Perform t-tests (H0: b = 0, H1: b != 0)
    # Estimate long-run effects on inflation
    mdls.estim.fe <- lapply(mdls.estim.fe, function(x){
      as.data.frame(x) %>% 
        rownames_to_column("stat") %>% 
        pivot_longer(cols = !stat, names_to = "var", values_to = "estim") %>% 
        pivot_wider(id_cols = var, names_from = stat, values_from = estim) %>% 
        mutate(
          tval   = abs(lr.coeff/s.e.), 
          signif = case_when( # t-test of long-run coefficients
            tval > 2.326 ~ "***",
            tval > 1.960 ~ "**",
            tval > 1.645 ~ "*",
            tval < 1.645 ~ ""
          ),
          lr.effect = (2/(ma.mean+1)) * lr.coeff) %>%  # long-run effects on inflation 
        select(var, lr.coeff, signif, s.e., tval, lr.effect)
    })
    mdls.estim.fe <- lapply(names(mdls.estim.fe), function(n){
      mdls.estim.fe[[n]] %>% 
        mutate(model = gsub("model", "", n)) %>% 
        select(model, everything())
    })
    dname <- paste("GDPpc", str_to_title(gsub("gdp\\.", "", gdpv)), sep = "-")
    ardl.gdp[[dname]] <- do.call(rbind, mdls.estim.fe)
  }
  
  ## ******* Export estimations as RData *******
  vname <- ifelse(sead_adjst, "ae-", "-")
  fname <- paste0("ARDL-FE_GDP-ITAEE", vname, climate_db, "_", data_freq, "_",
                  no_regions, "Regiones_MA", ma.mean, ".RData")
  fpath <- file.path(resuPath, "Raw")
  if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
  fpath <- file.path(fpath, fname)
  save(ardl.gdp, file = fpath)
  cat("\n")
  
}


## ========================================================================== ##
## Export results -----------------------------------------------------------
## ========================================================================== ##

cat(" -------------------------------------------------\n\n")
cat(" ** ARDL RESULTS INTO XLSX TABLES\n\n")
source("scripts/Functions/52_ARDL_Excel-Tables.R")

cat(" -------------------------------------------------\n\n")
cat(" ** ARDL RESULTS in LATEX TABLES\n\n")
source("scripts/Functions/52_ARDL_Latex-Tables.R")

cat(" -------------------------------------------------\n\n")
cat("\n ** LONG-RUN (ARDL) ANALYSIS DONE!!  \n\n",
    "++++++++++++++++++++++++++++++++++++++++++++++++++\n")


## Clean memory
rm(list = ls())
