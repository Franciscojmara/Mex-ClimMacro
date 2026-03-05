
# Prepare data to estimate panel local projections
# Returns a list: each element a data frame, each representing "t + h" of `y var`
panel.data.for.lp <- function(data, hmax, timeV, individualV, tempV, macroV) {
  
  # Variables to work with
  p.dt <- data %>% 
    select(all_of(c(timeV, individualV, macroV, tempV))) %>% 
    filter(region != "nacional")
  
  # Generate first difference of macro & climate variables [right side of LP]
  f.diff <- lapply(unique(p.dt$region), function(r){
    data.frame(
      date   = tail(unique(p.dt[,timeV]), length(unique(p.dt[,timeV])) - 1),
      region = r,
      inflat = delta.diff(log(p.dt[p.dt$region==r, macroV]), 1),
      climat = delta.diff(p.dt[p.dt$region==r, tempV], 1)
    )
  }) %>% do.call(rbind, .) 
  colnames(f.diff)[3:4] <- c(macroV,tempV) # All of this so I can later merge :(
  rownames.f.diff <- paste(f.diff$region, f.diff$date, sep = "-")
  f.diff <- as.matrix(f.diff[, c(macroV,tempV)])
  rownames(f.diff) <- rownames.f.diff
  f.diff <- as.data.frame(f.diff)
  
  # Define data of interest as panel 
  p.dt <- pdata.frame(p.dt, index=c(individualV, timeV), drop.index=T, row.names=T)
  
  # Create, t-1, t, & t+h CPI/GDP variables [left side of LP].
  leads <- do.call(cbind, lapply(1:hmax, function(x) plm::lead(p.dt[, macroV], x)))
  lags  <- plm::lag(p.dt[, macroV])
  lead.lag <- cbind(lags, p.dt[, macroV], leads)
  colnames(lead.lag) <- c("lag", paste0(rep("lead"), 0:hmax))
  
  # Calculate cumulative log inflation log(CPI_{t+h} - CPI_{t-1}) [left side LP] 
  # Merge cumulative inflation with independent vars. (climate & quarterly inflation)
  reg.data <- lapply(0:hmax, function(x){
    # Subset lagged index and t+h index and remove generated NAs
    h <- na.omit(cbind(lead.lag[, "lag"], lead.lag[, paste0("lead", x)]))
    # Cumulative log inflation [left side LP]
    h <- (log(h[,2]) - log(h[,1])) # Y_{t+h} - Y_{t-1}
    # Merge cumulative inflation [left side LP] with independent vars. [right side]
    h <- merge(as.data.frame(h), f.diff, by = 0) # merge by row names (panel index)
    # Manage data to re-transform to a panel 
    h <- separate(h, Row.names, into = c(individualV, timeV), sep = "-", 
                  extra = "merge")
    h <- pdata.frame(h, index = c(individualV, timeV), drop.index = TRUE, 
                     row.names = TRUE)
    colnames(h) <- c("y", "inflation", "tempvar")
    return(h)
  })
  names(reg.data) <- paste0("h", 0:hmax)
  
  return(reg.data)
}


# Estimate linear model in panel data
# data input should be either element of the output of `panel.data.for.lp()`
# returns the \beta of interest, plus S.E., R^2, and NxT dimension the panel
lp.irf <- function(data, hmax) {
  ## Fit panel fixed effects model
  mdl <- plm(y ~ tempvar + plm::lag(inflation, 1:hmax), data=data, model="within")
  ## Estimate Driscoll and Kraay standard errors
  cfs <- lmtest::coeftest(mdl, vcov. = function(cc) vcovSCC(cc, type = "sss"))
  ## Get beta1 (LP coefficient), R2, and N*T
  cfs.0 <- try({cfs["tempvar", c("Estimate", "Std. Error")]}, silent = TRUE)
  if(inherits(cfs.0, "try-error")) cfs.0 <- c(0, 0)
  ## Return coefficients & stats
  res <- c(cfs.0,R2=unname(summary(mdl)$r.squared[1]),NT=length(summary(mdl)$residuals))
  return(res)
}


# Difference of a variable with x lags (x_t - x_{t-p})
delta.diff <- function(data, lag, d.type = "index"){
  lge <- lag + 1
  dte <- stats::embed(data, lge) # lag data
  per <- (dte[, 1] - dte[, lge])
  return(per)
}


# t-statistic critical value decider
t.critical.value <- function(alpha){
  t.cv <- switch(
    as.character(alpha),
    "0.1"  = ,
    "0.10" = "1.645", 
    "0.05" = "1.96", 
    "0.01" = "2.576",
    stop("Only use alpha = 0.1, 0.05, or 0.01"))
  return(as.numeric(t.cv))
}


# Manage local projections irf estimates and calculate confidence intervals
manage.lp.res <- function(lps.list, alpha.ci, macroV){
  lp_irf <- as.data.frame(do.call(rbind, lps.list))
  colnames(lp_irf)[1:2] <- c("Estimate", "SE")
  rownames(lp_irf) <- paste0("h", 0:hmax)
  lp_irf <- lp_irf %>% 
    rownames_to_column(var = "Horizon") %>%
    mutate(
      Macro.var = macroV,
      Estimate  = Estimate * 100, # (Estimate * 0.01) * 100 (for 0.01°C shock effect)
      SE        = SE * 100,       # (SE * 0.01)* 100 (for 0.01°C shock effect)
      CI.low    = Estimate - (t.critical.value(alpha.ci) * SE),
      CI.up     = Estimate + (t.critical.value(alpha.ci) * SE),
      Horizon   = as.numeric(str_remove(Horizon, "h")),
      t.cval.ci = t.critical.value(alpha.ci),
      Signif    = case_when(
        abs(Estimate/SE) > t.critical.value(0.01) ~ "***",
        abs(Estimate/SE) > t.critical.value(0.05) ~ "**",
        abs(Estimate/SE) > t.critical.value(0.10) ~ "*",
        abs(Estimate/SE) <= t.critical.value(0.10) ~ NA
      )
    ) %>% 
    select(Macro.var,Horizon,Estimate,Signif,starts_with("CI"),SE,t.cval.ci,R2,NT)
  
  return(lp_irf)
}


# Estimate the standard error of the ARDL model long-run coefficients
lr.coeffs.by.var <- function(var.grep, model, phi = NULL){
  # 1.- Correct parameter names inside model object 
  #  ** deltaMethod function doesn't work if names are left as the output of `plm()` 
  to.rename <- grep(var.grep, rownames(summary(model)$coefficients))
  names(model$coefficients)[to.rename] <- paste0(var.grep, to.rename)
  # 2.- Function of the parameter estimates to be evaluated
  #   a) subset estimates' names (those with corrected names)
  coeffs.var<- model$coefficients[to.rename] 
  #   b) create function of estimates as string using the names of step a)
  fn.coeff.string <- paste(names(coeffs.var), collapse = "+")
  if(is.null(phi)){ # decide between correction term (\phi) or rest of estimates
    fn.coeff.string <- paste0("1-(", fn.coeff.string, ")")
  }else{
    phi <- unname(phi)
    phi.inv <- phi^(-1)
    fn.coeff.string <- paste0(phi.inv, "*(", fn.coeff.string,")")
  }
  # 3.- Estimate standard errors of the sum of coefficients with delta method
  dmet <- deltaMethod(coef(model), fn.coeff.string, vcov. = vcovSCC(model))
  # 4.- Coefficients and its standard errors in matrix format to return
  sum.bs <- unname(dmet[["Estimate"]])
  sum.se <- unname(dmet[["SE"]])
  sum.res <- rbind(sum.bs, sum.se)
  rownames(sum.res) <- c("lr.coeff", "s.e.")
  colnames(sum.res) <- var.grep
  return(sum.res)
}
