
### DOWNLOAD TEMPERATURE (MEAN, MAX, MIN) & PRECIPITATION DATA FROM CONAGUA
###   ** The data is downloaded as pdf, transformed into a data frame, and exported to a csv file
###   ** The data is monthly and by Mexican state. 
###   ** CONAGUA calls this data: "Resúmenes Mensuales de Lluvia y Temperatura"
###   ** Retrieved from    
###      https://smn.conagua.gob.mx/es/climatologia/temperaturas-y-lluvias/resumenes-mensuales-de-temperaturas-y-lluvias

### Arguments
###   ** variable: A string. Data to retrieve: max temperature ("temp.max"), 
###                min temperature ("temp.min"), mean temperature ("temp.mean"),
###                precipitation ("precip").
###   ** year: Numeric. A sole number, sequence, or a vector of years to retrieve
###            Available only from january 1985.
###   ** path: String. Path to directory where data is to be downloaded/stored.
###   ** export.csv: Boolean. TRUE if the function should export the downloaded data in csv format.
###   ** keep.pdf: Boolean. TRUE if the downloaded pdfs should be preserved. Otherwise are removed.

conagua.temp.precip <- function(variable = "temp.mean", year = NULL, path = NULL, 
                                export.csv = TRUE, keep.pdf = TRUE) {
  # Check for data type to retrieve: median/min/max temperature, or precipitation
  srcd <- switch(variable,
    "precip" = "PREC", "temp.min" = "TMIN", "temp.mean" = "TMED", "temp.max" = "TMAX",
    stop(
      cat("Use any of the following oprtions for `variable` argument:\n", 
          paste(c("precip",paste("temp",c("min","mean","max"),sep=".")), collapse = ", "),
          "\n")
      )
  )
  # Install/Load `pdftools` package
  if(!require("pdftools", character.only = TRUE)) { 
    install.packages("pdftools", dependencies=TRUE)
  }
  library("pdftools", character.only = TRUE)
  
  # Assign values to arguments if null
  available.years <- c(1985:as.numeric(format(Sys.Date(), "%Y")))
  if(is.null(year)) year <- available.years 
  if(is.null(path)) path <- getwd()
  
  # Check for years available at CONAGUA
  not.available.y <- setdiff(year, available.years)
  if(length(not.available.y) > 0) 
    stop(cat("Year(s):", not.available.y, "not available at CONAGUA"))
  
  # Create path to store downloaded data in pdf
  path.pdf <- file.path(path, paste0("CONAGUA-", srcd, "_pdf"))
  if(!file.exists(path.pdf)) dir.create(path.pdf)
  
  # Download data from CONAGUA and store in new (temporary) directory
  cat("***** DATA DOWNLOAD *****\n")
  url0 <- "https://smn.conagua.gob.mx/tools/DATA/Climatolog%C3%ADa/Pron%C3%B3stico%20clim%C3%A1tico/Temperatura%20y%20Lluvia"
  for(yy in year) {
    url   <- file.path(url0, srcd, paste0(yy, ".pdf"))
    fname <- file.path(path.pdf, paste(yy, "pdf", sep = "."))
    tryCatch({
      download.file(url, fname, mode = "wb", quiet = TRUE)
      message(cat("Downloaded:", paste0(yy, ".pdf"), "\n"))
    }, error = function(e) {
      message(cat("ERROR!! -- Failed download of", paste0(yy, ".pdf :"),  e$message, "\n"))
      next
    })
  }
  
  # FUNCTION: transform pdf file to a data frame (downloaded from CONAGUA)
  conagua.pdf.to.df <- function(pdf) {
    # Open pdf
    text <- pdf_text(pdf)
    # Manage pdf
    text <- gsub(" +", ",", text) # replace spaces for a comma
    text <- strsplit(text, split = "\n")[[1]] # split string by rows in table
    text <- gsub("^,", "", text[4:37]) # select states' data and manage the state "column"
    text <- gsub("(?<=\\D),(?=\\D)", ".", text, perl = TRUE) # manage the state "column"
    # Data as a matrix
    dataN <- strsplit(text[[1]], "\\.")[[1]] # get column names
    dataV <- strsplit(text[-1], ",") # get rows of data
    dataV <- do.call(rbind, dataV)   # append rows into a matrix
    colnames(dataV) <- dataN[1:ncol(dataV)] # add names to matrix columns
    # Data as a data frame:
    #     (i) Matrix as data frame, remove `anual` column (if exists)
    #    (ii) Character values that should be numbers as numbers
    #   (iii) Transform date abbreviations to month numbers
    conagua.df <- as.data.frame(dataV)
    if("Anual" %in% names(conagua.df)) {
      conagua.df <- conagua.df[, -which(names(conagua.df) == "Anual")] 
    }
    conagua.df[,-1] <- lapply(conagua.df[,-1], as.numeric)
    names(conagua.df) <- c(
      "entidad", 
      paste(
        gsub("\\.pdf", "", basename(pdf)),
        sapply(names(conagua.df)[-1], function(x){
          switch(x,
                 "Ene" = "01",
                 "Feb" = "02",
                 "Mar" = "03",
                 "Abr" = "04",
                 "May" = "05",
                 "Jun" = "06",
                 "Jul" = "07",
                 "Ago" = "08",
                 "Sep" = "09",
                 "Oct" = "10",
                 "Nov" = "11",
                 "Dic" = "12"
          )
        }, simplify = TRUE),
        sep = "-"
      )
    )
    return(conagua.df)
  }
  
  # Load downloaded pdfs from COANGUA and transform each to a clean data frame 
  # Store in a list all the dfs
  cat("***** TRANSFORMING PDF DATA INTO DATA FRAME *****\n")
  pdfs <- unname(sapply(list.files(path.pdf), function(ff) file.path(path.pdf, ff)))
  conagua.data <- lapply(pdfs, conagua.pdf.to.df)
  names(conagua.data) <- gsub("\\.pdf", "", basename(pdfs))
  
  # Merge in a data frame 
  conagua.data <- Reduce(function(x, y) merge(x, y, by = "entidad"), conagua.data)
  
  # Clear directories, export data frame, and return data
  if(keep.pdf){
    cat("***** DATA IN PDF FROMAT EXPORTED TO:", normalizePath(path.pdf), "\n")
  } else {
    unlink(path.pdf, recursive = T)
  } 
  if(export.csv) {
    sdate <- gsub("-", "m", names(conagua.data)[2])
    edate <- gsub("-", "m", tail(names(conagua.data),1))
    srcd  <- ifelse(srcd == "TMED", "TMEAN", srcd)
    fname <- paste0("CONAGUA-", srcd, "_", sdate, "-", edate, ".csv")
    fpath <- file.path(path, fname)
    write.csv(conagua.data, fpath, row.names = FALSE, fileEncoding = "UTF-8")
    cat("***** DATA IN CSV FROMAT EXPORTED TO:", normalizePath(path), "\n")
  }
  cat("***** SUCCESS!! *****\n")
  cat("======================================================================\n\n")
  return(conagua.data)
}



#### EXAMPLES

# year       <- 1985:2025
# path       <- "~/Varios/descarga.CONAGUA"
# export.csv <- TRUE
# keep.pdf   <- FALSE
# 
# tmed <- conagua.temp.precip("temp.med", year, path, export.csv, keep.pdf = TRUE)
# tmin <- conagua.temp.precip("temp.min", year, path, export.csv, keep.pdf)
# tmax <- conagua.temp.precip("temp.max", year, path, export.csv, keep.pdf)
# precip <- conagua.temp.precip("precip", year, path, export.csv, keep.pdf = TRUE)
