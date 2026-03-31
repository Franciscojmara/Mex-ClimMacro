
## ========================================================================== ##
#                       ARDL panel model: xlsx tables                          #
#                    Climate anomalies vs Macroeconomy                         #
#                           Mexican regions panel                              #
## ========================================================================== ##


# NOTE: Data used in this script is generated from the R script: 
#    "./Code/12_ARDL_Economic-Climate_Regions.R"


## ========================================================================== ##
## Auxiliary functions ------------------------------------------------------
## ========================================================================== ##

# Open xlsx file with multiple sheets
source("scripts/Functions/99_utils.R")

# Prepare panel ARDL model to create a TeX table
prep.ardl.results.xlsx <- function(mdl.list, no.vars, norm) {
  # Remove variables of no interest
  mdl.ardl <- lapply(mdl.list, select, -c(model, tval, lr.effect))
  # Paste significance stars with coefficient
  mdl.ardl <- lapply(mdl.ardl, mutate, 
                     lr.coeff = gsub("NA", "", paste(lr.coeff, signif)))
  mdl.ardl <- lapply(mdl.ardl, select, -signif)
  # Standard errors in parenthesis
  mdl.ardl <- lapply(mdl.ardl, mutate, s.e. = paste0("(", s.e., ")"))
  # Pivot data so standard errors are below the coefficients
  mdl.ardl <- lapply(mdl.ardl, pivot_longer, 
                     cols = !var, names_to = "stat", values_to = "values")
  # Append list elements and create y variable column
  mdl.ardl <- do.call(rbind, mdl.ardl) %>% 
    rownames_to_column("y.var") %>% 
    mutate(
      y.var = gsub('\\.[[:digit:]]+', '', y.var),
      y.var = case_when(
        str_detect(y.var, "Primarias")   ~ "PIB-Primarias",
        str_detect(y.var, "Secundarias") ~ "PIB-Secundarias",
        str_detect(y.var, "Terciarias")  ~ "PIB-Terciarias",
        TRUE ~ y.var
      )
    ) 
  names(mdl.ardl)[4] <- paste("m =", norm)
  
  return(mdl.ardl)
}

# Merge results with different norms
prep.ardl.xlsx <- function(ardl.list, norms, model.no, tot.vars) {
  # Helpers
  ardl.results.1 <- vector("list", length = length(norms))
  tot.vars <- (tot.vars + 1) * 2 # # manage number of indep variables
  cat(" --> Managing MODEL", model.no, "results.\n")
  # Prepare to tex
  for (i in seq_along(norms)) {
    # Subset model of interest: Model 1
    mdl1.ardl <- lapply(ardl.list[[i]], filter, model == model.no)
    mdl1.ardl <- prep.ardl.results.xlsx(mdl1.ardl, tot.vars, norms[[i]])
    # Store in list of final results
    ardl.results.1[[i]] <- as.data.frame(mdl1.ardl)
  }
  # Reduce list into one data frame
  ardl.results.1.df <- reduce(ardl.results.1,full_join,by=c("y.var","var","stat")) 
  
  return(ardl.results.1.df)
}

# Export clean results
export.ardl.xlsx <- function(ardl.clean, variables.no, fpath){
  # Iterate by total GDP or GDP by sector
  res <- vector("list", length = 2)
  names(res) <- c("TOTAL","SECTOR")
  for(v in c("total", "sector")){
    # Separate to export
    if( v == "total" ) {
      to.slice <- c(1:((variables.no + 1) * 2))
      ardl.e   <- ardl.clean %>% select(-y.var) %>% slice(to.slice) 
      names(ardl.e)[1] <- c("")
    } else {
      to.slice <- c(((variables.no + 1) * 2 + 1):nrow(ardl.clean))
      ardl.e   <- ardl.clean %>% slice(to.slice) 
      names(ardl.e)[1:2] <- c("", "")
    }
    names(ardl.e) <- gsub("\\.(x|y)", "", names(ardl.e))
    res[[toupper(v)]] <- ardl.e
  }
  
  # Export: Create or load workbook for pretty tables
  write.xlsx(res, file = fpath)
}



## ========================================================================== ##
## Load ARDL results --------------------------------------------------------
## ========================================================================== ##

# List to store loaded results
ardl.n <- paste0("norm.", ma.means, ".years")
ardl.r <- vector("list", length = length(ma.means))
names(ardl.r) <- ardl.n

# Load results (by norm)
for (i in seq_along(ma.means)) {
  cat(" --> Loading ARDL results with norm", ma.means[[i]], "of years.\n")
  vname <- ifelse(sead_adjst, "ae-", "-")
  fname <- paste0("ARDL-FE_GDP-ITAEE", vname, climate_db, "_", data_freq, "_",
                  no_regions,"Regiones_MA", ma.means[[i]], ".RData")
  load(file.path(resuPath, "Raw", fname))
  ardl.r[[ardl.n[i]]] <- ardl.gdp
}
cat("\n")



## ========================================================================== ##
## Manage ARDL results 
## ========================================================================== ##

## Specification 1 - 3 ---------------------------------------------------------

no.vars  <- 4 # max number of independent variables in the models of interest

# Specification 1
ardl.mdl1 <- prep.ardl.xlsx(ardl.r, ma.means, 1, no.vars)

# Specification 2
ardl.mdl2 <- prep.ardl.xlsx(ardl.r, ma.means, 2, no.vars)

# Specification 3
ardl.mdl3 <- prep.ardl.xlsx(ardl.r, ma.means, 3, no.vars)

# Merge results of all models & final touches
ardl1 <- ardl.mdl1 %>% 
  full_join(ardl.mdl2, by = c("y.var","var","stat")) %>% 
  full_join(ardl.mdl3, by = c("y.var","var","stat")) %>% 
  select(-stat) %>% 
  mutate(
      var   = ifelse(row_number() %% 2, var, NA),
      y.var = ifelse(row_number() %in% seq(1,nrow(.),10), y.var, NA)
    ) 

# Export results
fname <- paste0("ARDL-FE_GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_M1-3.xlsx")
export.ardl.xlsx(ardl1, no.vars, file.path(resuPath, fname))



## Specification 4 - 6 ---------------------------------------------------------

# Max number of variables in table
no.vars <- 2

# Specification 4
ardl.mdl4 <- prep.ardl.xlsx(ardl.r, ma.means, 4, no.vars)

# Specification 5
ardl.mdl5 <- prep.ardl.xlsx(ardl.r, ma.means, 5, no.vars)

# Specification 4
ardl.mdl6 <- prep.ardl.xlsx(ardl.r, ma.means, 6, no.vars)

# Merge results of all models & final touches
ardl2 <- ardl.mdl4 %>% 
  full_join(ardl.mdl5, by = c("y.var","var","stat")) %>% 
  full_join(ardl.mdl6, by = c("y.var","var","stat")) %>% 
  select(-stat) %>% 
  mutate(
    var   = ifelse(row_number() %% 2, var, NA),
    y.var = ifelse(row_number() %in% seq(1,nrow(.),6), y.var, NA)
  ) 

# Export results
fname <- paste0("ARDL-FE_GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_M4-6.xlsx")
export.ardl.xlsx(ardl2, no.vars, file.path(resuPath, fname))



## Specification 7 - 9 ---------------------------------------------------------

# Max number of variables in table
no.vars <- 2

# Specification 7
ardl.mdl7 <- prep.ardl.xlsx(ardl.r, ma.means, 7, no.vars)

# Specification 8
ardl.mdl8 <- prep.ardl.xlsx(ardl.r, ma.means, 8, no.vars)

# Specification 9
ardl.mdl9 <- prep.ardl.xlsx(ardl.r, ma.means, 9, no.vars)

# Merge results of all models & final touches
ardl3 <- ardl.mdl7 %>% 
  full_join(ardl.mdl8, by = c("y.var","var","stat")) %>% 
  full_join(ardl.mdl9, by = c("y.var","var","stat")) %>% 
  select(-stat) %>% 
  mutate(
    var   = ifelse(row_number() %% 2, var, NA),
    y.var = ifelse(row_number() %in% seq(1,nrow(.),6), y.var, NA)
  ) 

# Export results
fname <- paste0("ARDL-FE_GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_M7-9.xlsx")
export.ardl.xlsx(ardl3, no.vars, file.path(resuPath, fname))
