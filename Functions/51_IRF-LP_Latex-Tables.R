
## ========================================================================== ##
#                      Local projections: Latex tables                         #
#                    Climate anomalies vs Macroeconomy                         #
#                           Mexican regions panel                              #
## ========================================================================== ##


# NOTE: Data used in this script is generated from the R script: 
#    "./Code/11_IRF-LP_Economic-Climate_Regions.R"

## ========================================================================== ##
## Manage LP results 
## ========================================================================== ##


## Manage LP-IRF results

# Remove from list plotted variables: "TemperatureDev" and "PrecipitationDev"
options(scipen = 99999)
lps0 <- results_lp
var.to.rm <- c("TempDev", "PrecipDev")
lps0[var.to.rm] <- NULL

# From each set of estimations, keep the betas, and the S.E.
lps <- lapply(lps0, select, Macro.var, Horizon, Estimate, SE, Signif)

# Manage estimators and put SE in parenthesis
lps <- lapply(lps, mutate, 
              Estimate = sprintf("%.2f", round(Estimate, 2)),
              Estimate = gsub("NA", "", paste(Estimate, Signif)),
              SE = sprintf("%.3f", round(SE, 3)),
              SE = paste0("(", SE, ")"))
lps <- lapply(lps, mutate, Estimate = gsub("\\.00", "\\.01", Estimate))
lps <- lapply(lps, select, -Signif)

# Pivot so horizons now become the columns
lps <- lapply(lps, mutate, Horizon = paste0("Horizon.", Horizon))
lps <- lapply(lps, pivot_longer, 
              cols = !c(Macro.var, Horizon), 
              names_to = "stat", 
              values_to = "estim")
lps <- lapply(lps, pivot_wider, 
              id_cols = c(Macro.var, stat),
              names_from = Horizon,
              values_from = estim)
lps <- lapply(lps, select, -stat)

# Separate by inflation and GDP vars
lps.i <- lapply(lps, filter, !grepl("gdp", Macro.var))
lps.g <- lapply(lps, filter,  grepl("gdp", Macro.var))


## Add latex commands

# Make NA even rows of `Macro.var` variable and manage CPI names
lps.i <- lapply(lps.i, mutate, 
                Macro.var = ifelse(row_number()%%2,Macro.var,NA),
                Macro.var = gsub("headline", "All items", Macro.var),
                Macro.var = gsub("nonfood", "non food", Macro.var),
                Macro.var = str_to_sentence(Macro.var)
                )
lps.g <- lapply(lps.g, mutate,  
                Macro.var = ifelse(row_number()%%2,Macro.var,NA),
                Macro.var = gsub("primarias", "primary", Macro.var),
                Macro.var = gsub("secundarias", "secondary", Macro.var),
                Macro.var = gsub("terciarias", "tertiary", Macro.var),
                Macro.var = str_to_sentence(gsub("^gdp\\.", "", Macro.var))
                )

lps0 <- list("INPC" = lps.i, "GDP" = lps.g)
rm(lps.i, lps.g)


# Iterate by economic data type
for(en in names(lps0)) {
  
  # Table to manage
  lps <- lps0[[en]]
  
  # Add column with the climate variable name (list element names)
  n.lps <- names(lps)
  lps <- lapply(n.lps, function(x){
    if (x == "TempDev_negative") {
      x1 <- "$\\Tilde{T}_{it}^{-}(m)$"
    } else if (x == "TempDev_positive") {
      x1 <- "$\\Tilde{T}_{it}^{+}(m)$"
    } else if (x == "PrecipDev_negative") {
      x1 <- "$\\Tilde{P}_{it}^{-}(m)$"
    } else if (x == "PrecipDev_positive") {
      x1 <- "$\\Tilde{P}_{it}^{+}(m)$"
    } else {
      x1 <- gsub("_", " ", x)
    }
    lps[[x]] %>% mutate(Climate.var = x1, .before = Macro.var) 
  })
  names(lps) <- n.lps
  lps <- lapply(lps, mutate, Climate.var = ifelse(row_number()!=1,NA,Climate.var))
  
  # Multirow for climate variable
  nrw <- ifelse(en == "INPC", 12, 8)
  lps <- lapply(
    lps, 
    mutate,
    Climate.var = case_when(
      !is.na(Climate.var)~paste0("\\multirow{",nrw,"}{3em}{",Climate.var,"}")
      )
    )
  
  ## Append all list elements --> 2 dfs: (i) Faccia var type, (ii) Khan var type
  if (faccia.def) {
    lps.df <- list(
      "Dev" = do.call(rbind, lps[grepl("Dev", names(lps))]),
      "Ext" = do.call(rbind, lps[-which(grepl("Dev", names(lps)))])
    )
  } else {
    lps.df <- list("Dev" = do.call(rbind, lps[grepl("Dev", names(lps))]))
  }
  
  ## Manage names
  hmax <- ifelse(data_freq == "Monthly", IRF.hmax * 12, IRF.hmax * 4)
  texnames <- c("", "", paste0("$", paste("h", 0:hmax, sep = "="), "$"))
  lps.df <- lapply(lps.df, function(x) {colnames(x) <- texnames; return(x)})
  
  # Add \midrule command
  n <- nrow(lps.df[[1]])
  inby.s <- ifelse(en == "INPC", 12, 8)
  breaks <- seq(inby.s, n, by = inby.s)
  breaks <- breaks[breaks < n]   # avoid placing rule after last row
  addtorow <- list(
    pos = as.list(breaks),
    command = rep("\\midrule\n", length(breaks))
  )
  
  
  ## Export
  for(nn in names(lps.df)) {
    
    # File name & directory to export results
    if(nn != "Dev") next
    dname <- ifelse(nn == "Dev", "Deviations", "Extremes")
    fname <- paste0("LP-IRF_", en, "-", climate_db, "_", data_freq, "_", 
                    no_regions,"Regiones_MA", ma.mean, "_", toupper(dname), ".tex")
    fpath <- file.path(resuPath, "Latex.Tables")
    if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
    
    # Export results as a latex formatted table
    print(xtable(lps.df[[nn]]),
          NA.string = "",
          only.contents = T,
          include.colnames = T,
          include.rownames = F, 
          add.to.row = addtorow,
          sanitize.text.function = identity,
          booktabs = TRUE, 
          comment = FALSE,
          file = file.path(fpath, fname)
          )
  }
}
