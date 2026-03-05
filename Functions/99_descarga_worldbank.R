
### DOWNLOAD TEMPERATURE (MEAN, MAX, MIN) & PRECIPITATION DATA FROM WORLD BANK
###  MEXICO SUBNATIONAL
###   ** The data is downloaded as json, transformed into a data frame, and exported to a csv file
###   ** The data is monthly and by Mexican state. 
###   ** Retrieved (using API) from    
###      https://climateknowledgeportal.worldbank.org/download-data
###   ** Considers Subnational CRU 0.5-degree collection monthly time series data

### Arguments
###   ** variable: A string. Data to retrieve: max temperature ("temp.max"), 
###                min temperature ("temp.min"), mean temperature ("temp.mean"),
###                precipitation ("precip").
###   ** start.date: Date. Starting date for time series. Available only from January 1901.
###   ** end.date: Date. Ending date for time series. Available until December 2024
###   ** path: String. Path to directory where data is to be downloaded/stored.
###   ** export.data: Boolean. TRUE if the function should export the downloaded data in csv format.
###   ** keep.pdf: Boolean. TRUE if the downloaded pdfs should be preserved. Otherwise are removed.
###   ** return.data: Boolean. TRUE if data should be stored in work space

worldbank.temp.precip <- function(variable = "temp.mean", start.date = NULL, end.date = NULL, 
                           path = NULL, export.data = TRUE, return.data = TRUE) {
  # check args
  variable <- switch(
    variable, 
    "precip" = "pr", "temp.min" = "tasmin", "temp.mean" = "tas", "temp.max" = "tasmax",
    stop(cat("Use any of the following oprtions for `variable` argument:\n", 
             paste(c("precip",paste("temp",c("min","mean","max"),sep=".")), collapse = ", "),
             "\n")
         )
    )
  if (is.null(path)) {
    path <- getwd()
  }
  cat(" ** Downloading Mexico subnational - cru-x0.5_timeseries -", 
      toupper(variable), "\n")
  
  # API call
  # Get data (fetch & parse JSON)
  require(jsonlite)
  raw <- fromJSON(
    paste0("https://cckpapi.worldbank.org/api/v1/cru-x0.5_timeseries_", variable, 
           "_timeseries_monthly_1901-2024_mean_historical_cru_ts4.09_mean/MEX.@?_",
           "format=json")
  )
  dat <- raw[["data"]]
  
  # Get Mexico state names and codes
  codes <- fromJSON(
    "https://climateknowledgeportal.worldbank.org/themes/custom/cckpmodern/data/geonames.json" 
  )
  codes <- unlist(codes[["country"]][["MEX"]][["S"]])
  codes <- gsub("â€š", "e", codes)
  codes <- gsub("(Â)?¢", "o", codes)
  codes <- gsub("(Â)?¡", "i", codes)
  codes <- gsub("\\sn", "an", codes)
  codes <- data.frame(code = names(codes), state = unname(codes))
  
  # Clean data
  dat <- lapply(dat, function(x) do.call(cbind, x)) # each state is now a list
  dat <- as.data.frame(cbind(code = names(dat), do.call(rbind, dat)))
  dat <- merge(codes, dat)
  dat <- dat[, -which(names(dat)=="code")]
  names(dat)[which(names(dat)=="state")] <- "entidad"
  
  # Clean state names
  clean.state <- dat$entidad
  clean.state <- gsub("Michoacan de Ocampo", "Michoacan", clean.state)
  clean.state <- gsub("Coahuila de Zaragoza", "Coahuila", clean.state)
  clean.state <- gsub("Veracruz de Ignacio de la Llave", "Veracruz", clean.state)
  clean.state <- gsub("Mexico", "Estado De Mexico", clean.state)
  clean.state <- gsub("Ciudad de Estado De Mexico", "Ciudad De Mexico", clean.state)
  
  # Create national average
  dat <- apply(dat[,-which(names(dat)=="entidad")], 2, as.numeric) # Data as numeric
  national <- cbind(entidad = "Nacional", t(colMeans(dat)))
  dat <- cbind(entidad = clean.state, dat)
  dat <- as.data.frame(rbind(national, dat))
  
  # Filter according to date
  if(is.null(start.date)) {
    stdate <- as.Date("1901-01-01")
  } else {
    stdate <- as.Date(start.date)
  }
  if(is.null(end.date)) {
    endate <- as.Date("2024-12-01")
  } else {
    if (end.date > as.Date("2024-12-01")) {
      warning("Selected ending date is not available yet. Retrieving up to 2024-12.")
      endate <- as.Date("2024-12-01")
    } else {
      endate <- as.Date(end.date)
    }
  }
  date.subset <- seq.Date(stdate, endate, by = "1 month")
  date.subset <- sapply(date.subset, function(x) format(x, "%Y-%m"))
  dat <- dat[, c("entidad", date.subset)]
  
  # Export to csv
  if(export.data) {
    variableN <- switch(variable, "tas"="TMEAN", "tasmin"="TMIN", "tasmax"="TMAX",
                        "pr"="PREC")
    mdate <- paste(format(stdate,"%Ym%m"), format(endate,"%Ym%m"), sep = "-") 
    fname <- paste0("WorldBank-", variableN, "_", mdate, ".csv")
    fpath <- file.path(path, fname)
    write.csv(dat, file = fpath, row.names = FALSE) 
    cat("   -- Data stored in:", fpath, "\n\n")
  }
  if(return.data) {
    return(dat)
  }
}


# path <- file.path(dataPath, "Raw/Climate")
# variable    <- "tas" # "all"
# start.date  <- "1970-01-01"
# end.date    <- "2022-05-08"
# return.data <- FALSE
# debug(world.bank.cru)
# world.bank.cru(variable, start.date = NULL, end.date = NULL, path, return)






