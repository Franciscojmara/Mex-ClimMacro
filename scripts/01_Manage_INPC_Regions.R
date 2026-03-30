
# ============================================================================ #
#                   INPC APERTURA 16 BY GEOGRAPHIC REGIONS
#
#
#  ** Note 1: OUTPUT of this script is EXPORTED to:
#          "./Data/Preprocessed"
#  ** Note 2: OUTPUT of this script is USED in:
#          "./Code/02_Merge_INPC-Climate_data.R"
# ============================================================================ #


## Preamble --------------------------------------------------------------------

load("scripts/Functions/Hyper-Parameters_Scripts.RData")
cat(" =================================================\n","\n",
    "                MANAGING INPC DATA               \n",
    "\n","=================================================\n\n")


## Auxiliary functions ---------------------------------------------------------

source("scripts/Functions/99_utils.R")




## Open data -------------------------------------------------------------------

inputPath  <- file.path(dataPath, "Raw")
outputPath <- file.path(dataPath, "Preprocessed")

# Headline index
fname <- paste0("Raw-INPC-AP16_", no_regions, "Regiones.csv")
fpath <- file.path(inputPath, "Inflation", fname)
inpc0 <- read.csv(fpath)



## Manage INPC data (I) --------------------------------------------------------

# Get Food and Non-food indices
inpc_vars  <- c("general", "subyacente", "alimentos", "mercnoalim", "servicios",
                "agropecuarios", "energeticos")
inpc <- lapply(inpc_vars, function(x){
  inpc0 %>% filter(apertura == x) %>% select(-ends_with("apertura"))
}) 
names(inpc) <- sapply(inpc_vars, translate.inpc, simplify = TRUE)

# Pivot: regions as columns
inpc <- lapply(inpc, pivot_wider, 
               id_cols = date, names_from = region, values_from = index)

# Filter dates
start_date <- as.Date(start_date)
end_date   <- as.Date(end_date)
inpc <- lapply(inpc, filter, date >= start_date & date <= end_date)

# Change to quarterly frequency (if needed)
if( data_freq  == "Quarterly" ){
  inpc <- lapply(inpc, to_quarterly.inpc)
}

# Pivot longer
inpc <- lapply(inpc, pivot_longer, 
               cols = !date, names_to = "region", values_to = "x")

# Name `x` variable according to the list element it belongs
for( n in names(inpc) ){
  dat <- inpc[[n]]
  names(dat)[length(names(dat))] <- n
  inpc[[n]] <- dat
  rm(dat)
}

# Reduce list into a data frame by joining its elements
inpc <- reduce(inpc, full_join, by = c("date", "region")) %>% 
  rename(fecha = date) %>% 
  arrange(region, fecha)

# Homogenize states names
if(no_regions == 32){
  inpc$region <- gsub("michoacan.de.ocampo", "michoacan", inpc$region)
  inpc$region <- gsub("coahuila.de.zaragoza", "coahuila", inpc$region)
  inpc$region <- gsub("veracruz.de.ignacio.de.la.llave", "veracruz", 
                             inpc$region)
  inpc$region <- gsub("mexico", "estado.de.mexico", inpc$region)
  inpc$region <- str_squish(inpc$region) # remove white space start & end
  inpc$region <- str_to_title(gsub("\\.", " ", inpc$region))
}

# Seasonal adjust data (if needed)
if (sead_adjst) {
  inpc <- lapply(unique(inpc$region), function(r){
    cat("             ", toupper(r), "\n")
    to.seas <- filter(inpc, region == r)
    if (data_freq == "Quarterly") {
      seas.st <- str_split_1(head(as.character(to.seas$fecha), 1), " Q")
    } else {
      seas.st <- str_split_1(head(as.character(to.seas$fecha), 1), "-")[1:2]
    }
    seas.fq <- ifelse(data_freq == "Quarterly", 4, 12)
    to.merg <- select(to.seas, fecha, region)
    to.seas <- to.seas %>% 
      select(-c(fecha, region)) %>% 
      ts(start = seas.st, frequency = seas.fq)
    to.seas <- ajuste_estacional(to.seas)$final
    cat("-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -\n")
    return(cbind(to.merg, to.seas))
  })
  inpc <- do.call(rbind, inpc)
}
cat("\n")

# Final touches
inpc$region <- tolower(gsub(" ", "\\.", inpc$region))



## Export INPC to a .csv file --------------------------------------------------

vname <- ifelse(data_freq == "Quarterly", "-trimestral_", "-mensual_")
fname <- paste0("inpc", vname, no_regions, "region.csv")
write.csv(inpc, file.path(outputPath, fname), row.names = FALSE)


## Clean memory
rm(list = ls())
