
## ========================================================================== ##
#                      ARDL panel model: Latex tables                          #
#                    Climate anomalies vs Macroeconomy                         #
#                           Mexican regions panel                              #
## ========================================================================== ##


# NOTE: Data used in this script is generated from the R script: 
#    "./Code/12_ARDL_Economic-Climate_Regions.R"


## ========================================================================== ##
## Auxiliary functions ------------------------------------------------------
## ========================================================================== ##

# Open xlsx file with multiple sheets
source("Functions/99_utils.R")

# Prepare panel ARDL model to create a TeX table
prep.ardl.results.tex <- function(mdl.list, no.vars, norm) {
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
        str_detect(y.var, "Primarias")   ~ "GDP-Primary",
        str_detect(y.var, "Secundarias") ~ "GDP-Secondary",
        str_detect(y.var, "Terciarias")  ~ "GDP-Tertiary",
        TRUE ~ y.var
      ),
      y.var = paste0("\\multirow{", no.vars, "}{4em}{", gsub("GDP-","",y.var), "}"),
      var = case_when( # tex format independent variables
        var == "abs.deviation.temp" ~ "$\\hat{\\theta}_{\\Delta|\\Tilde{T}_{it}(m)|}$",
        var == "deviation.temp"     ~ "$\\hat{\\theta}_{\\Delta\\Tilde{T}_{it}(m)}$",
        var == "pos.dev.temp"       ~ "$\\hat{\\theta}_{\\Delta\\Tilde{T}_{it}(m)^{+}}$",
        var == "neg.dev.temp"       ~ "$\\hat{\\theta}_{\\Delta\\Tilde{T}_{it}(m)^{-}}$",
        var == "abs.deviation.precip" ~ "$\\hat{\\theta}_{\\Delta|\\Tilde{P}_{it}(m)|}$",
        var == "deviation.precip"     ~ "$\\hat{\\theta}_{\\Delta\\Tilde{P}_{it}(m)}$",
        var == "pos.dev.precip"       ~ "$\\hat{\\theta}_{\\Delta\\Tilde{P}_{it}(m)^{+}}$",
        var == "neg.dev.precip"       ~ "$\\hat{\\theta}_{\\Delta\\Tilde{P}_{it}(m)^{-}}$",
        var == "gdp.total"       ~ "$\\hat{\\phi}$",
        var == "gdp.primarias"   ~ "$\\hat{\\phi}_{Primary}$",
        var == "gdp.secundarias" ~ "$\\hat{\\phi}_{Secondary}$",
        var == "gdp.terciarias"  ~ "$\\hat{\\phi}_{Tertiary}$",
        TRUE ~ var
      )
    ) 
  names(mdl.ardl)[4] <- paste("m =", norm)
  
  return(mdl.ardl)
}

# Merge results with different norms
prep.ardl.tex <- function(ardl.list, norms, model.no, tot.vars) {
  # Helpers
  ardl.results.1 <- vector("list", length = length(norms))
  tot.vars <- (tot.vars + 1) * 2 # # manage number of indep variables
  # Prepare to tex
  cat(" --> Managing MODEL", model.no, "results.\n")
  for (i in seq_along(norms)) {
    # Subset model of interest: Model 1
    mdl1.ardl <- lapply(ardl.list[[i]], filter, model == model.no)
    mdl1.ardl <- prep.ardl.results.tex(mdl1.ardl, tot.vars, norms[[i]])
    # Store in list of final results
    ardl.results.1[[i]] <- as.data.frame(mdl1.ardl)
  }
  # Reduce list into one data frame
  ardl.results.1.df <- reduce(ardl.results.1,full_join,by=c("y.var","var","stat")) 
  
  return(ardl.results.1.df)
}

# Export clean results in tex format
export.ardl.tex <- function(ardl.clean, variables.no, fpath){
  
  # Iterate by total GDP or GDP by sector
  for(v in c("total", "sector")){
    
    # Separate to export
    if( v == "total" ) {
      
      # Final touches
      to.slice   <- c(1:((variables.no + 1) * 2))
      ardl.tex.e <- ardl.clean %>% select(-y.var) %>% slice(to.slice) 
      names(ardl.tex.e)[1] <- c("")
      
      # Export
      names(ardl.tex.e) <- gsub("\\.(x|y)", "", names(ardl.tex.e))
      fname <- gsub("\\.tex", paste0("_", toupper(v), "\\.tex"), fpath)
      print(xtable(ardl.tex.e),
            NA.string = "",
            only.contents = T,
            include.rownames = F, 
            sanitize.text.function = identity,
            booktabs = TRUE, 
            comment = FALSE,
            file = fname
      )
      
    } else {
      
      # Final touches
      to.slice   <- c(((variables.no + 1) * 2 + 1):nrow(ardl.clean))
      ardl.tex.e <- ardl.clean %>% slice(to.slice) 
      names(ardl.tex.e)[1:2] <- c("", "")
      
      # Add \midrule command
      n <- nrow(ardl.tex.e)
      inby.s <- (2 * variables.no) + 2
      breaks <- seq(inby.s, n, by = inby.s)
      breaks <- breaks[breaks < n]   # avoid placing rule after last row
      addtorow <- list(
        pos = as.list(breaks),
        command = rep("\\midrule\n", length(breaks))
      )
      
      # Export
      names(ardl.tex.e) <- gsub("\\.(x|y)", "", names(ardl.tex.e))
      fname <- gsub("\\.tex", paste0("_", toupper(v), "\\.tex"), fpath)
      print(xtable(ardl.tex.e),
            NA.string = "",
            only.contents = T,
            include.rownames = F, 
            add.to.row = addtorow, # \midrule command is here
            sanitize.text.function = identity,
            booktabs = TRUE, 
            comment = FALSE,
            file = fname
      )
    }
  }
}


round.sprintf <- function(x, n) {
  sprintf(paste0("%.", n, "f"), round(x, n))
}



## ========================================================================== ##
## Load ARDL results --------------------------------------------------------
## ========================================================================== ##

# List to store loaded results
ardl.r <- vector("list", length = length(ma.means))
ardl.n <- paste0("norm.", ma.means, ".years")
names(ardl.r) <- ardl.n

# Iterate by climate norm
for (i in seq_along(ma.means)) {
  cat(" --> Loading ARDL results with norm", ma.means[[i]], "of years.\n")
  # Load
  vname <- ifelse(sead_adjst, "ae-", "-")
  fname <- paste0("ARDL-FE_GDP-ITAEE", vname, climate_db, "_", data_freq, "_",
                  no_regions,"Regiones_MA", ma.means[[i]], ".RData")
  load(file.path(resuPath, "Raw", fname))
  # Manage: Round numbers in table for format
  ardl.gdp <- lapply(
    ardl.gdp, 
    mutate, 
    across(
      where(is.numeric),
      ~ if_else(row_number()%%2 == 0, round.sprintf(.x,3), round.sprintf(.x,3))
    )
  )
  ardl.r[[ardl.n[i]]] <- ardl.gdp
}
cat("\n")



## ========================================================================== ##
## Manage ARDL results 
## ========================================================================== ##


## Specification 1 - 3 ---------------------------------------------------------

variables.no  <- 4 # max number of independent variables in the models of interest

# Specification 1
ardl.mdl1 <- prep.ardl.tex(ardl.r, ma.means, 1, variables.no)

# Specification 2
ardl.mdl2 <- prep.ardl.tex(ardl.r, ma.means, 2, variables.no)

# Specification 3
ardl.mdl3 <- prep.ardl.tex(ardl.r, ma.means, 3, variables.no)

# Merge results of all models & final touches
ardl1 <- ardl.mdl1 %>% 
  full_join(ardl.mdl2, by = c("y.var","var","stat")) %>% 
  full_join(ardl.mdl3, by = c("y.var","var","stat")) %>% 
  select(-stat) %>% 
  mutate(
      var   = ifelse(row_number() %% 2, var, NA),
      y.var = ifelse(row_number() %in% seq(1,nrow(.),10), y.var, NA)
    ) 

# Export results as TeX table. Separate total production and production by sectors
vname <- ifelse(sead_adjst, "ae-", "-")
fname <- paste0("ARDL-FE_GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_M1-3.tex")
fpath <- file.path(resuPath, "Latex.Tables")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
export.ardl.tex(ardl1, variables.no, file.path(fpath, fname))



## Specification 4 - 6 ---------------------------------------------------------

variables.no  <- 2

# Specification 1
ardl.mdl4 <- prep.ardl.tex(ardl.r, ma.means, 4, variables.no)

# Specification 2
ardl.mdl5 <- prep.ardl.tex(ardl.r, ma.means, 5, variables.no)

# Specification 3
ardl.mdl6 <- prep.ardl.tex(ardl.r, ma.means, 6, variables.no)

# Merge results of all models & final touches
ardl2 <- ardl.mdl4 %>% 
  full_join(ardl.mdl5, by = c("y.var","var","stat")) %>% 
  full_join(ardl.mdl6, by = c("y.var","var","stat")) %>% 
  select(-stat) %>% 
  mutate(
    var   = ifelse(row_number() %% 2, var, NA),
    y.var = ifelse(row_number() %in% seq(1,nrow(.),6), y.var, NA)
  ) 

# Export results as TeX table. Separate total production and production by sectors
vname <- ifelse(sead_adjst, "ae-", "-")
fname <- paste0("ARDL-FE_GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_M4-6.tex")
fpath <- file.path(resuPath, "Latex.Tables")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
export.ardl.tex(ardl2, variables.no, file.path(fpath, fname))



## Specification 7 - 9 ---------------------------------------------------------

variables.no  <- 2

# Specification 1
ardl.mdl7 <- prep.ardl.tex(ardl.r, ma.means, 7, variables.no)

# Specification 2
ardl.mdl8 <- prep.ardl.tex(ardl.r, ma.means, 8, variables.no)

# Specification 3
ardl.mdl9 <- prep.ardl.tex(ardl.r, ma.means, 9, variables.no)

# Merge results of all models & final touches
ardl3 <- ardl.mdl7 %>% 
  full_join(ardl.mdl8, by = c("y.var","var","stat")) %>% 
  full_join(ardl.mdl9, by = c("y.var","var","stat")) %>% 
  select(-stat) %>% 
  mutate(
    var   = ifelse(row_number() %% 2, var, NA),
    y.var = ifelse(row_number() %in% seq(1,nrow(.),6), y.var, NA)
  ) 

# Export results as TeX table. Separate total production and production by sectors
vname <- ifelse(sead_adjst, "ae-", "-")
fname <- paste0("ARDL-FE_GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_M7-9.tex")
fpath <- file.path(resuPath, "Latex.Tables")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
export.ardl.tex(ardl3, variables.no, file.path(fpath, fname))
