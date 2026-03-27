
# Open a xlsx file with multiple sheets
xlsx_multiple_sheets <- function(file) {
  # get info about excel sheets
  sheets <- readxl::excel_sheets(file)
  xlsxfl <- lapply(sheets, function(x) {
    as.data.frame(readxl::read_excel(file, sheet = x))
  })
  # assign names
  names(xlsxfl) <- sheets
  
  return(xlsxfl)
}


#Seasonal adjust
ajuste_estacional <- function(data, print.window = TRUE){
  gen_dead <- list()
  gen_sa <- list()
  for( i in colnames(data) ){
    if( print.window ) print(paste0("Seasonally adjusting: ", i))
    #declare time series
    dat <- ts(data[, i], start = start(data), frequency = frequency(data))
    #try to seasonally adjust
    x_sa <- try(seasonal::final(seas(dat, x11="")), silent = TRUE)
    #actions after `try`
    if ('try-error' %in% class(x_sa)){
      gen_dead[[i]] <- i #just the name of the series that failed to converge
      gen_sa[[i]] <- dat #the unadjusted series
      next
    }else{
      gen_sa[[i]] <- x_sa
    }
  }
  #Data into time series object
  gen_sa <- do.call(cbind, gen_sa)
  gen_sa <- ts(gen_sa, start = start(data), frequency = frequency(data))
  gen_dead <- do.call(cbind, gen_dead)
  #Store in list
  ae <- list(final = gen_sa, dead_names = gen_dead)
  return(ae)
}


# Compute inflation
calculate.inflation <- function(dt, var, dfrequency = 12, approx = FALSE) 
{
  # check if data is time series
  if( !is.ts(dt) )
    stop("Data must be in time series format")
  # frequency and lags
  if( !(dfrequency %in% c(4, 12)) ) 
    stop("Invalid frequency. Please use 4 (for quarterly) or 12 (for monthly).")
  if( dfrequency == 12 )
    lag <- switch(var, "m" = 1, "q" = 4, "y" = 12, 
                  stop("Invalid variation. Please use 'm', 'q', or 'y'."))
  else 
    lag <- switch(var, "q" = 1, "y" = 4, 
                  stop("Invalid variation. Please use 'q' or 'y'."))
  # Calculate inflation
  inf.vec <- function(dt, lag){
    lng <- length(dt)
    res <- numeric(lng - lag) #vector to store results 
    for( r in c((lag + 1):lng) ) {
      r0 <- r - lag
      if( !approx ) 
        res[r0] <- (dt[r] / dt[r0]) - 1
      else
        res[r0] <- log(dt[r]) - log(dt[r0])
    }
    return(res * 100)
  }
  if( !is.null(ncol(dt)) )
    inflation <- apply(dt, 2, inf.vec, lag)
  else
    inflation <- inf.vec(dt, lag)
  # data to time series format
  inflation <- ts(inflation, frequency = dfrequency)
  if( is.ts(dt) ) {
    sy0 <- as.numeric(start(dt)[[1]])
    sm0 <- as.numeric(start(dt)[[2]]) + lag
    if( sm0 <= 12 )
      start <- c(sy0, sm0)
    else
      start <- c(sy0 + 1, 1)
    inflation <- ts(inflation, start = start, frequency = dfrequency)
  }
  return(inflation)
}

# Create rolling windows
window.creator <- function(window.size, sy, sm, ey, em){
  
  start.date <- paste(sy, "-", sm, "-", 01, sep = "")
  start.date0 <- as.Date(start.date)
  
  end.date <- paste(ey, "-", em, "-", 01, sep = "")
  end.date0 <- as.Date(end.date)
  
  freq     <- (window.size - 1) * 12 + 11
  freq_pos <- paste(freq, "month")
  freq_neg <- paste(-freq, "month")
  
  x.date0.1 <- seq(start.date0, length = 2, by = freq_pos)[2]
  x.date0.2 <- seq(end.date0, length = 2, by = freq_neg)[2]
  
  dates.1 <- seq(as.Date(start.date0), as.Date(x.date0.2), by = "1 month")
  dates.1.fmt <- as.yearmon(dates.1)
  year.start <- year(dates.1.fmt)
  month.start <- month(dates.1.fmt)
  
  dates.2 <- seq(as.Date(x.date0.1), as.Date(end.date0), by = "month")
  year.end <- year(dates.2)
  month.end <- month(dates.2)
  
  fechas.ventanas <- cbind(year.start,month.start,year.end,month.end)
  
}


# Quarter of the year depending on the month
decide.quarter <- function(month){
  case_when(
    month %in% c(1, 2, 3) ~ 1,
    month %in% c(4, 5, 6) ~ 2, 
    month %in% c(7, 8, 9) ~ 3,
    month %in% c(10, 11, 12) ~ 4)
}

# Select season name depending on the year's month
season.decider <- function(x, freq){
  if( freq == 12 ){
    case_when(
      x %in% c(12, 1, 2) ~ "invierno",
      x %in% c(3, 4, 5) ~ "primavera",
      x %in% c(6, 7, 8) ~ "verano",
      x %in% c(9, 10, 11) ~ "otono"
    )
  }else{
    case_when(
      x == 4 ~ "otono",
      x == 1 ~ "invierno",
      x == 2 ~ "primavera",
      x == 3 ~ "verano"
    )
  }
}


# INPC labels to english
translate.inpc <- function(string){
  switch(string,
         "general" = "headline",
         "subyacente" = "core",
         "mercancias" = "goods",
         "alimentos" = "food",
         "mercnoalim" = "nonfood",
         "servicios" = "services",
         "vivienda" = "housing",
         "educacion" = "schooling",
         "otroservicios" = "servnohouseschool",
         "nosubyacente" = "noncore",
         "agropecuarios" = "agriculture",
         "frutasverduras" = "fruitsvegetables",
         "pecuarios" = "meat",
         "energeticostarifgob" = "energygovtariffs",
         "energeticos" = "energy",
         "tarifasgob" = "govtariffs")
}


# Monthly data to quarterly --- this is for "01_Manage_INPC_Regions.R"
to_quarterly.inpc <- function(data){
  agg_vars <- names(data)[-1]
  dt <- as.data.frame(data) %>%
    separate(date, c("year", "month", "day"), sep = "-") %>%
    select(-day) %>%
    mutate(across(.cols = c(year, month), ~ as.numeric(.x))) %>%
    mutate(quarter = decide.quarter(month)) %>%
    select(year, quarter, everything()) %>%
    group_by(year, quarter) %>%
    summarise(across(all_of(agg_vars), mean), .groups = 'drop') %>%
    ungroup()
  dt %>%
    mutate(date = as.yearqtr(paste(dt$year, dt$quarter, sep = "-"))) %>%
    select(-c(year, quarter)) %>%
    select(date, everything())
}


# Monthly data to quarterly  --- this is for "02_Merge_Macro-Climate-data_Regions.R"
to_quarterly <- function(data){
  dt <- as.data.frame(data) %>% 
    separate(fecha, c("year", "month", "day"), sep = "-") %>%
    select(-day) %>% 
    mutate(across(.cols = c(year, month), ~ as.numeric(.x))) %>% 
    mutate(quarter = decide.quarter(month)) %>% 
    group_by(year, quarter) %>% 
    summarise(across(all_of(names(data)[-1]), ~mean(.x, na.rm = TRUE)), .groups = 'drop') %>% 
    ungroup()
  dt %>% 
    mutate(fecha = as.yearqtr(paste(dt$year, dt$quarter, sep = "-"))) %>% 
    select(-c(year, quarter)) %>% 
    select(fecha, everything())
}


# Translate and prettify INPC names
# Translate and prettify Season names
inpc.climate.titles <- function(x){
  switch(x,
         "gdp.total"       = "GDP-Total",
         "gdp.primarias"   = "GDP-Primarias",
         "gdp.secundarias" = "GDP-Secundarias",
         "gdp.terciarias"   = "GDP-Terciarias",
         "headline"    = "INPC-General",
         "food"        = "INPC-Alimentos",
         "nonfood"     = "INPC-MercNoAlim",
         "services"    = "INPC-Servicios",
         "agriculture" = "INPC-Agricolas",
         "energy"      = "INPC-Energeticos",
         "all.seasons" = "All_seasons",
         "h.winter"    = "Hot_winter",
         "h.spring"    = "Hot_spring",
         "h.summer"    = "Hot_summer",
         "h.autumn"    = "Hot_autumn",
         "c.winter"    = "Cold_winter",
         "deviation.temp"   = "TempDev",
         "pos.dev.temp"     = "TempDev_positive",
         "neg.dev.temp"     = "TempDev_negative",
         "deviation.precip" = "PrecipDev",
         "pos.dev.precip"   = "PrecipDev_positive",
         "neg.dev.precip"   = "PrecipDev_negative")
}

# Translate and make pretty INPC names
inpc.titles <- function(x){
  switch(x,
         "headline"    = "All items",
         "food"        = "Food, beverages, and tobacco",
         "nonfood"     = "Non-food goods",
         "services"    = "Services",
         "agriculture" = "Agricultural",
         "energy"      = "Energy")
}

# Translate and make pretty region names
region.titles <- function(x){
  switch(as.character(x),
         "area.met.cdmx" = "Mexico City",
         "centro.norte"  = "Center North",
         "centro.sur"    = "Center South",
         "centro"        = "Center",
         "frontera.norte"= "Northern Border",
         "noreste"       = "North East",
         "noroeste"      = "North West",
         "norte"         = "North",
         "sur"           = "South",
         "nacional"      = "National",
         str_to_title(gsub("\\.", " ", as.character(x)))
  )
}

# Translate and make pretty region names for plot file name
region.titles.plot <- function(x){
  switch(x,
         "area.met.cdmx" = "CDMX",
         "centro.norte"  = "CenterNorth",
         "centro.sur"    = "CenterSouth",
         "centro"        = "Center",
         "frontera.norte"= "NorthernNorder",
         "noreste"       = "NorthEast",
         "noroeste"      = "NorthWest",
         "norte"         = "North",
         "sur"           = "South",
         "nacional"      = "National"
  )
}

# Translate and make pretty climate/economic variable names
var.titles <- function(x){
  switch(x,
         "deviation.precip" = "Precipitation anomalies",
         "deviation.temp"   = "Temperature anomalies",
         "gdp.total" = "Total real GDP per capita",
         "headline"  = "Headline inflation",
  )
}


# manage data set depending on the frequency of data
initial.setup <- function(data, frequency) {
  if (frequency == "Quarterly") {
    data %>% 
      filter(region != "nacional") %>% 
      mutate(quartr = quartr * 3) %>% # 4th quarter * 3 = 12 month
      mutate(date = as.Date(paste(year, quartr, "01", sep = "-"))) %>% 
      select(date, everything()) %>% 
      select(-c(year, quartr))
  } else {
    data %>%
      filter(region != "nacional") %>% 
      mutate(date = as.Date(paste(year, month, "01", sep = "-"))) %>% 
      select(date, everything()) %>% 
      select(-c(year, month))
  }
}


## Safe download climate data from World Bank 
## (sometimes TIMEOUT error is reached, this function tries to solve this problem)
safe.download <- function(expr, max_tries = Inf, base_sleep = 2, max_sleep = 60) {
  i <- 0
  repeat {
    i <- i + 1
    out <- tryCatch(
      eval.parent(substitute(expr)),
      error = function(e) e
    )
    # Success → return result
    if (!inherits(out, "error")) return(out)
    msg <- conditionMessage(out)
    # Stop immediately if it's not the timeout error
    if (!grepl("Timeout was reached", msg, fixed = TRUE)) {
      stop(out)
    }
    # Stop if max tries reached
    if (is.finite(max_tries) && i >= max_tries) {
      stop(out)
    }
    # Exponential backoff with cap
    wait <- min(base_sleep * 2^(i - 1), max_sleep)
    message(sprintf("Timeout on try %d. Retrying in %ds...", i, wait))
    Sys.sleep(wait)
  }
}

# # Usage
# res <- safe.download(
#   worldbank.temp.precip(),
#   base_sleep = 2,
#   max_sleep = 60
# )

