
# ============================================================================ #
#                 Temperature and precipitation in Mexican Regions
#
#
#  ** Note 1: Data is from CONAGUA
#             https://smn.conagua.gob.mx/es/climatologia/temperaturas-y-lluvias/resumenes-mensuales-de-temperaturas-y-lluvias
#  ** Note 2: Main OUTPUT of this script is EXPORTED to:
#          "./Data/Preprocessed"
#  ** Note 3: Main OUTPUT of this script is USED in:
#          "./Code/02_Merge_INPC-Climate_variables.R"
# ============================================================================ #


# ## Preamble --------------------------------------------------------------------

load("Functions/Hyper-Parameters_Scripts.RData")
inputPath  <- file.path(dataPath, "Raw")
outputPath <- file.path(dataPath, "Preprocessed")
cat(" =================================================\n","\n",
    "      DOWNLOADING AND MANAGING CLIMATE DATA      \n",
    "\n =================================================\n\n")


## Auxiliary functions ---------------------------------------------------------

# Function to download data
source("Functions/99_descarga_conagua.R")
source("Functions/99_descarga_worldbank.R")
source("Functions/99_utils.R")



## Auxiliary data --------------------------------------------------------------

## Cities, states, and regions

# Load data
fname <- "CiudadesxRegion.csv"
fpath <- file.path(inputPath, "Helpers", fname)
regions <- read.csv(fpath)

# Manage data
regions <- regions %>% 
  select(-c(ciudad, ent)) %>% 
  distinct(.keep_all = TRUE) %>% 
  mutate(
    to.rm = case_when( # remove entidades with wrong region
      d_region_7 == "Noreste" & entidad == "Tamaulipas" ~ 1,
      d_region_7 == "Noreste" & entidad == "Chihuahua" ~ 1,
      d_region_7 == "Noreste" & entidad == "Coahuila" ~ 1,
      d_region_7 == "Sur" & entidad == "Veracruz" ~ 1
    )
  ) %>% 
  filter(is.na(to.rm)) %>% 
  select(-to.rm)


## Population (Censo 2020)

# Load data
fname <- "Poblacion_Entidades_Censo2020.xlsx"
fpath <- file.path(inputPath, "Helpers", fname)
population <- read.xlsx(fpath, sheet = "02")

# Manage data
population <- population %>% 
  slice(-c(1:2)) %>% 
  row_to_names(row_number = 1) %>% 
  clean_names() %>% 
  filter(grupos_quinquenales_de_edad == "Total") %>% 
  filter(sexo == "Total") %>%
  select(entidad_federativa, poblacion_total1) %>% 
  filter(entidad_federativa != "Estados Unidos Mexicanos") %>% 
  mutate(poblacion_total1 = as.numeric(poblacion_total1)) %>% 
  rename(poblacion = poblacion_total1,
         entidad = entidad_federativa)

# Homogenize states names
population$entidad <- gsub('[[:digit:]]+', '', population$entidad)
population$entidad <- stri_trans_general(str = population$entidad, 
                                         id = "Latin-ASCII") # removes accents
population$entidad <- gsub("Michoacan de Ocampo", "Michoacan", population$entidad)
population$entidad <- gsub("Coahuila de Zaragoza", "Coahuila", population$entidad)
population$entidad <- gsub("Veracruz de Ignacio de la Llave", "Veracruz", 
                           population$entidad)
population$entidad <- gsub("Mexico", "Estado De Mexico", population$entidad)
population$entidad <- gsub("Ciudad de Estado De Mexico", "Ciudad De Mexico", 
                           population$entidad)
population$entidad <- str_squish(population$entidad) # remove white space start & end

# Set population in millions
population <- mutate(population, poblacion = poblacion / 1000000)

# Get total population (in millions)
tot.popul  <- sum(population$poblacion)


## Merge cities, states, and regions with its population
regions <- full_join(regions, population, by = "entidad")



## Download & manage temperature data ------------------------------------------

cat(" ++++++++++++++++++++++++++++++++++++\n",
    " >>       TEMPERATURE DATA       << \n",
    "++++++++++++++++++++++++++++++++++++\n\n")

## Download data from CONAGUA
if (climate_db == "WorldBank") {
  temp0 <- safe.download(
    worldbank.temp.precip("temp.mean", path = file.path(inputPath, "Climate"))
  )
} else {
  temp0 <- conagua.temp.precip("temp.mean", path = file.path(inputPath, "Climate"))
}
  

## Manage data

# Remove national temperature
temp <- temp0 %>% 
  filter(entidad != "Nacional") %>% 
  mutate(
    entidad = str_to_title(gsub("\\.", " ", entidad)), 
    entidad = stri_trans_general(str = entidad, id = "Latin-ASCII"),
    across(.cols = !entidad, ~ round(as.numeric(.x), 2))
  )

# Merge regions
temp <- full_join(regions, temp, by = "entidad")  # df for data to be weighted

# Weight temperatures by population. 
# See Tol R. (2017). Population and trends in the global mean temperature.
# Atmosfera. 30(2). 121-135. [Cited by Pesaran et al (2021) in Note 9]
# https://www.sciencedirect.com/science/article/pii/S0187623617300462
# Equation (4)
if (weight_dta) {
  temp <- temp %>%
    mutate(weight = poblacion/tot.popul) %>% 
    select(starts_with("region"), starts_with("d_region"), entidad, weight, 
           everything()) %>% 
    mutate(
      across(c(starts_with("19"), starts_with("20")), ~ .*weight)
    )
}  
temp <- select(temp, -any_of(c("poblacion","weight")))

# Remove either 4, 7, or 32 regions
if(no_regions != 32){
  to.rm <- ifelse(no_regions == "4", 7, 4)
  temp  <- select(temp, -all_of(paste0(c("region_", "d_region_"), to.rm)))
  names(temp)[1:2] <- c("region", "d_region")
} else {
  to.rm <- c("region_", "d_region_")
  temp  <- select(temp, -starts_with(to.rm))
  temp  <- mutate(temp, region=1:32, d_region=entidad, .before=everything())
}

# Calculate mean National temperature
to.summ  <- setdiff(names(temp), c("region", "d_region", "entidad"))
national <- temp %>% 
  summarise_at(to.summ, mean) %>% 
  mutate(d_region = "Nacional", region = 0, entidad = "Nacional") %>% 
  select(region, d_region, entidad, everything())

# Append national data to state data
temp <- rbind(temp, national)

# Final touches
temp <- temp %>%
  pivot_longer(
    cols = !c(region, d_region, entidad),
    names_to = "date",
    values_to = "temp"
    ) %>%
  group_by(region, d_region, date) %>%
  summarise(temp = sum(temp), .groups = 'drop') %>% # use sum as the temperature data is weighted
  separate(date, into = c("year", "mes"), sep = "-") %>%
  select(-region) %>% 
  select(d_region, everything()) %>% 
  pivot_wider( # Regions as columns
    id_cols = c(year, mes),
    names_from = d_region,
    values_from = temp) %>% 
  mutate(fecha = as.Date(paste(year, mes, 01, sep="-")), .before = everything()) %>% 
  select(-c(year, mes)) 

# Center data [subtract mean and divide by standard deviation] (if required)
if (center_dta){
  rname <- names(temp)
  temp  <- mutate(temp, across(!fecha, ~ scale(.x, scale = TRUE)))
  names(temp) <- rname
}



## Temperature norm & deviations -----------------------------------------------

temp.norms <- vector("list", length = length(ma.means))
names(temp.norms) <- paste0("MA", ma.means)

cat(" ** Computing temperature normals, deviations, and anomalies \n")
for(ma.mean0 in ma.means) {
  
  cat("   --", ma.mean0, "years norm \n")
  
  # Historical temperatures norm by region: mean temp. in rolling windows
  # See section 2 of Khan et al. 2021. Long-term macroeconomic effects of climate 
  # change: A cross-country analysis. Energy Economics. 104.
  # Estimate mean in rolling windows
  byseq <- "-1 month"
  sy <- year(head(temp$fecha, 1)); sm <- month(head(temp$fecha, 1))
  ey <- year(tail(temp$fecha, 1)); em <- month(tail(temp$fecha, 1))
  rollwin   <- window.creator(ma.mean0, sy, em, ey, em)
  mean.temp <- lapply(split(rollwin, seq(nrow(rollwin))), function(x){
    # Rolling window to filter
    st <- paste(x[1], x[2], "01", sep = "-")
    en <- paste(x[3], x[4], "01", sep = "-")
    # Estimate mean of window
    dat <- temp %>% filter(fecha >= st & fecha <= en) %>% select(-fecha)
    dat <- apply(dat, 2, mean, na.rm = TRUE)
    return(dat)
  })
  
  # Append results and manage dates
  mean.temp <- as.data.frame(do.call(rbind, mean.temp)) %>% 
    mutate(
      fecha = rev(seq.Date(from=as.Date(end_date), by=byseq, length.out=nrow(rollwin)))
    ) %>% 
    select(fecha, everything()) %>% 
    filter(fecha >= as.Date(start_date))
  
  # Manage region names
  names(mean.temp) <- tolower(make.names(names(mean.temp), unique = TRUE))
  names(mean.temp) <- stri_trans_general(str = names(mean.temp), id = "Latin-ASCII") # no accent
  names(mean.temp) <- gsub("x.", "", names(mean.temp))
  names(mean.temp) <- gsub("cd..de.meco", "cdmx", names(mean.temp))
  
  # Final touches before merging with observed temperatures
  if (data_freq == "Quarterly"){
    mean.temp <- to_quarterly(mean.temp)
  }
  mean.temp <- mean.temp %>% 
    pivot_longer(cols = !fecha, names_to = "region", values_to = "mean.temp")
  
  # ---------------- #

  # Manage observed temperatures for estimation
  tempt <- temp %>% 
    filter(fecha >= as.Date(start_date) & fecha <= as.Date(end_date))
  
  # Region names as in INPC data
  names(tempt) <- tolower(make.names(names(tempt),unique = TRUE))
  names(tempt) <- stri_trans_general(str = names(tempt), id = "Latin-ASCII") #no accent
  names(tempt) <- gsub("x.", "", names(tempt))
  names(tempt) <- gsub("cd..de.meco", "cdmx", names(tempt))
  
  # Pivot data and create season variable (create dummies of Faccia et al 2021)
  if( data_freq  == "Quarterly" ){
    tempt <- tempt %>% 
      to_quarterly() %>% # data to quarterly frequency
      pivot_longer(cols = !fecha, names_to = "region", values_to = "temp") %>% 
      mutate(
        year=year(fecha), quartr=quarter(fecha), season=season.decider(quartr, 4)
      )
  } else {
    tempt <- tempt %>% 
      pivot_longer(cols = !fecha, names_to = "region", values_to = "temp") %>% 
      mutate(
        year = year(fecha), month = month(fecha), day = day(fecha),
        season = season.decider(month, 12)
      )
  }
  tempt <- select(tempt, fecha, season, everything())
  
  # Merge historical mean temperature by region with observed temperatures
  tempt <- full_join(tempt, mean.temp, by = c("fecha", "region"))
  
  # Temperature deviations from historical norm
  tempt  <- tempt %>%
    arrange(region, fecha) %>% 
    mutate(deviation.temp = temp - mean.temp) %>% 
    select(fecha, year, quartr, season, region, everything())
  
  
  
  ## Temperature anomalies [à la Khan, & à la Faccia] --------------------------
  
  # Khan et al (2021) multiplies the deviation from the historical norm by 
  # 2/(m+1), where "m" is the size of the rolling window used to estimate the norm 
  tempt <- tempt %>% 
    mutate(
      deviation.temp     = (2/(ma.mean0+1)) * deviation.temp,
      abs.deviation.temp = abs(deviation.temp)
      ) %>% 
    mutate( 
      pos.dev.temp = case_when( # Temperature positive
        deviation.temp > 0  ~ deviation.temp,
        deviation.temp <= 0 ~ 0
      ),
      neg.dev.temp = case_when( # Temperature negative
        deviation.temp < 0  ~ (-1)*deviation.temp,
        deviation.temp >= 0 ~ 0
      )
    )
  
  if (faccia.def) {
    # Extreme temperatures dummy: 
    # Based on Table 2 of Faccia et al. December 2021.Feeling the heat: Extreme 
    # temperatures and price stability. ECB working paper series. No. 2626.
    # As temperatures are normalized (weighted) by population, instead of considering
    # deviations above or below 1.5°C, we use deviations above 0.25°C, or 0.35°C
    tempt <- tempt %>% 
      mutate( 
        fdev.temp = deviation.temp,
        all.seasons = ifelse(abs(fdev.temp) >= tempdev, 1, 0),
        h.winter = ifelse(season == "invierno" & fdev.temp >= tempdev, 1,
                          ifelse(season == "invierno" & fdev.temp <= -tempdev,NA,0)),
        h.spring = ifelse(season == "primavera" & fdev.temp >= tempdev, 1,
                          ifelse(season == "primavera" & fdev.temp <= -tempdev,NA,0)),
        h.summer = ifelse(season == "verano" & fdev.temp >= tempdev, 1,
                          ifelse(season == "verano" & fdev.temp <= -tempdev,NA,0)),
        h.autumn = ifelse(season == "otono" & fdev.temp >= tempdev, 1,
                          ifelse(season == "otono" & fdev.temp <= -tempdev,NA,0)),
        c.winter = ifelse(season == "invierno" & fdev.temp <= -tempdev, 1,
                          ifelse(season == "invierno" & fdev.temp >= tempdev,NA,0))
      )
  }
  
  # Store in list
  temp.norms[[paste0("MA", ma.mean0)]] <- select(tempt, -any_of(c("fdev.temp")))
}
cat("\n ** Temperature data done! \n\n")



## Download & manage precipitation data -------------------------------------

cat(" ++++++++++++++++++++++++++++++++++++\n",
    " >>      PRECIPITATION DATA      << \n",
    "++++++++++++++++++++++++++++++++++++\n\n")

## Download data
if (climate_db == "WorldBank") {
  prec0 <- safe.download(
    worldbank.temp.precip("precip", path = file.path(inputPath, "Climate"))
  )
} else {
  prec0 <- conagua.temp.precip("precip", path = file.path(inputPath, "Climate"))
}

## Manage data

# Remove national temperature
prec <- prec0 %>% 
  filter(entidad != "Nacional") %>% 
  mutate(
    entidad = str_to_title(gsub("\\.", " ", entidad)), 
    entidad = stri_trans_general(str = entidad, id = "Latin-ASCII"),
    across(.cols = !entidad, ~ round(as.numeric(.x), 2))
  )

# Merge regions
prec <- full_join(regions, prec, by = "entidad") 

# Weight precipitation by population. 
# See Tol R. (2017). Population and trends in the global mean temperature.
# Atmosfera. 30(2). 121-135. [Cited by Pesaran et al (2021) in Note 9]
# https://www.sciencedirect.com/science/article/pii/S0187623617300462
# Equation (4)
if (weight_dta) {
  prec <- prec %>% 
    mutate(
      weight = poblacion/tot.popul,
      across(c(starts_with("19"), starts_with("20")), ~ .*weight)
    )  
}
prec <- prec %>% select(-any_of(c("poblacion","weight")))

# Remove either 7 or 4 regions
if(no_regions != 32){
  to.rm <- ifelse(no_regions == "4", 7, 4)
  prec  <- select(prec, -all_of(paste0(c("region_", "d_region_"), to.rm)))
  names(prec)[1:2] <- c("region", "d_region")
} else {
  to.rm <- c("region_", "d_region_")
  prec  <- select(prec, -starts_with(to.rm))
  prec  <- mutate(prec, region=1:32, d_region=entidad, .before=everything())
}

# Calculate mean National temperature
to.summ  <- setdiff(names(prec), c("region", "d_region", "entidad"))
national <- prec %>% 
  summarise_at(to.summ, mean) %>% 
  mutate(d_region = "Nacional", region = 0, entidad = "Nacional") %>% 
  select(region, d_region, entidad, everything())

# Append national data to state data
prec <- rbind(prec, national)

# Pivot data & manage dates: Mean weighted precipitation by region
prec <- prec %>% 
  pivot_longer(cols = !c(region, d_region, entidad),
               names_to = "date",
               values_to = "prec") %>% 
  group_by(region, d_region, date) %>% 
  summarise(prec = sum(prec), .groups = 'drop') %>% 
  separate(date, into = c("year", "mes"), sep = "-") %>% 
  select(d_region, region, everything()) %>% 
  select(-region) %>% 
  pivot_wider(
    id_cols = c(year, mes),
    names_from = d_region,
    values_from = prec) %>% 
  mutate(fecha = as.Date(paste(year, mes, 01, sep = "-"))) %>% 
  select(-c(year, mes)) %>% 
  select(fecha, everything())

# Center data [subtract mean and divide by standard deviation] (if required)
if (center_dta){
  rname <- names(prec)
  prec  <- mutate(prec, across(!fecha, ~ scale(.x, scale = TRUE)))
  names(prec) <- rname
}



## Precipitation norm & deviations ---------------------------------------------

prec.norms <- vector("list", length = length(ma.means))
names(prec.norms) <- paste0("MA", ma.means)

cat(" ** Computing precipitation normals, deviations, and anomalies \n")
for(ma.mean0 in ma.means) {
  
  cat("   --", ma.mean0, "years norm \n")
  
  # Historical Precipitations norm by region: mean prec. in rolling windows
  # See section 2 of Khan et al. 2021. Long-term macroeconomic effects of climate 
  # change: A cross-country analysis. Energy Economics. 104.
  # Estimate mean in rolling windows
  byseq <- "-1 month"
  sy <- year(head(prec$fecha, 1)); sm <- month(head(prec$fecha, 1))
  ey <- year(tail(prec$fecha, 1)); em <- month(tail(prec$fecha, 1))
  rollwin   <- window.creator(ma.mean0, sy, em, ey, em)
  mean.prec <- lapply(split(rollwin, seq(nrow(rollwin))), function(x){
    # Rolling window to filter
    st <- paste(x[1], x[2], "01", sep = "-")
    en <- paste(x[3], x[4], "01", sep = "-")
    # Estimate mean of window
    dat <- prec %>% filter(fecha >= st & fecha <= en) %>% select(-fecha)
    dat <- apply(dat, 2, mean, na.rm = TRUE)
    return(dat)
  })
  
  # Append results and manage dates
  mean.prec <- as.data.frame(do.call(rbind, mean.prec)) %>% 
    mutate(
      fecha = rev(seq.Date(from=as.Date(end_date), by=byseq, length.out=nrow(rollwin)))
    ) %>% 
    select(fecha, everything()) %>% 
    filter(fecha >= as.Date(start_date))
  
  # Manage region names
  names(mean.prec) <- tolower(make.names(names(mean.prec), unique = TRUE))
  names(mean.prec) <- stri_trans_general(str = names(mean.prec), id = "Latin-ASCII") # no accent
  names(mean.prec) <- gsub("x.", "", names(mean.prec))
  names(mean.prec) <- gsub("cd..de.meco", "cdmx", names(mean.prec))
  
  # Final touches before merging with observed Precipitations
  if (data_freq == "Quarterly"){
    mean.prec    <- to_quarterly(mean.prec)
  }
  mean.prec <- mean.prec %>% 
    pivot_longer(cols = !fecha, names_to = "region", values_to = "mean.precip")
  
  # ---------------- #
  
  # Manage observed Precipitations for estimation
  prect <- prec %>% 
    filter(fecha >= as.Date(start_date) & fecha <= as.Date(end_date))
  
  # Region names as in INPC data
  names(prect) <- tolower(make.names(names(prect),unique = TRUE))
  names(prect) <- stri_trans_general(str = names(prect), id = "Latin-ASCII") #no accent
  names(prect) <- gsub("x.", "", names(prect))
  names(prect) <- gsub("cd..de.meco", "cdmx", names(prect))
  
  # Pivot data and create season variable (create dummies of Faccia et al 2021)
  if( data_freq  == "Quarterly" ){
    prect <- prect %>% 
      to_quarterly() %>% # data to quarterly frequency
      pivot_longer(cols = !fecha, names_to = "region", values_to = "precip") %>% 
      mutate(
        year=year(fecha), quartr=quarter(fecha), season=season.decider(quartr, 4)
      )
  } else {
    prect <- prect %>% 
      pivot_longer(cols = !fecha, names_to = "region", values_to = "precip") %>% 
      mutate(
        year = year(fecha), month = month(fecha), day = day(fecha),
        season = season.decider(month, 12)
      )
  }
  prect <- select(prect, fecha, season, everything())
  
  # Merge historical mean Precipitation by region with observed Precipitations
  prect <- full_join(prect, mean.prec, by = c("fecha", "region"))
  
  # Precipitation deviations from historical norm
  prect  <- prect %>%
    arrange(region, fecha) %>% 
    mutate(deviation.precip = precip - mean.precip) %>% 
    select(fecha, year, quartr, season, region, everything())
  
  
  
  ## Precipitation anomalies [à la Khan] ---------------------------------------
  
  # Khan et al (2021) multiplies the deviation from the historical norm by 
  # 2/(m+1), where "m" is the size of the rolling window used to estimate the norm 
  prect <- prect %>% 
    mutate(
      deviation.precip     = (2/(ma.mean0+1)) * deviation.precip,
      abs.deviation.precip = abs(deviation.precip)
    ) %>% 
    mutate( 
      pos.dev.precip = case_when( # Precipitation positive
        deviation.precip > 0  ~ deviation.precip,
        deviation.precip <= 0 ~ 0
      ),
      neg.dev.precip = case_when( # Precipitation negative
        deviation.precip < 0  ~ (-1)*deviation.precip,
        deviation.precip >= 0 ~ 0
      )
    )
  
  # Store in list
  prec.norms[[paste0("MA", ma.mean0)]] <- prect
}
cat("\n ** Precipitation data done! \n\n")



# ## EMDAT data ------------------------------------------------------------------
# 
# ## Load data
# 
# # Load: main  EMDATA data
# fname  <- "EMDAT-DisastrousEventsMexico.xlsx"
# fpath  <- file.path(inputPath, "Climate", fname)
# emdat0 <- read.xlsx(fpath)
# 
# # Load: helpers. From the location variable, use the extracted states
# # extracted with chatGPT
# fname  <- "EMDAT-Extracted_Mexican_States.csv"
# fpath  <- file.path(inputPath, "Helpers", fname)
# state0 <- read.csv(fpath)
# 
# 
# ## Manage data
# 
# # Physical events to use 
# events.to.use <- c("Hydrological","Meteorological","Climatological")
# 
# # Manage -- states (helpers)
# state <- state0 %>% 
#   filter(disaster.subgroup %in% events.to.use) %>% 
#   select(-disaster.subgroup)
# 
# # Manage -- main data
# emdat <- emdat0 %>% 
#   filter(Disaster.Subgroup %in% events.to.use) %>% 
#   rename_with(
#     ~ tolower(gsub("\\.{2}","\\.",gsub(",","",gsub("\\('000\\.US\\$\\)","USD",.x))))
#   ) %>% 
#   full_join(state, by = c("disno.","location")) %>% 
#   select(states, start.year, start.month, disaster.subgroup, total.affected) %>% 
#   separate_rows(states, sep = ",\\s*") %>%  # split on commas
#   mutate(states = str_trim(states)) %>%     # tidy white space
#   filter(!is.na(states) & states != "") %>% # remove empties
#   mutate(
#     states = gsub("Mexico", "Estado De Mexico", states),
#     states = gsub("Distrito Federal", "Ciudad De Mexico", states)
#   ) %>% 
#   rename(entidad = states, year = start.year, mes = start.month) %>% 
#   rename_with(~ paste0("emdat.", .x), .cols = !c(entidad,year,mes)) %>% 
#   select(-ends_with("poblacion"))
# 
# # Merge Mexican regions
# emdat <- full_join(regions, emdat, by = "entidad") 
# 
# # Remove either 7 or 4 regions
# to.rm <- ifelse(no_regions == "4", 7, 4)
# to.rm <- paste0(c("region_", "d_region_"), to.rm)
# emdat <- select(emdat, -all_of(to.rm))
# names(emdat)[1:2] <- c("region", "d_region")
# 
# # Manage data
# disasters <- unique(emdat$emdat.disaster.subgroup)
# disasters <- disasters[-which(disasters == "Climatological")]
# emdat <- lapply(disasters, function(sb) {
#   # General management
#   ds <- emdat %>%
#     filter(emdat.disaster.subgroup == sb) %>%
#     select(-emdat.disaster.subgroup, -region, -poblacion) %>%
#     mutate(fecha = as.Date(paste(year, mes, 01, sep = "-")),
#            .before = everything()) %>%
#     select(-c(year, mes)) %>%
#     group_by(fecha, d_region) %>%
#     dplyr::summarise(
#       emdat.total.affected = mean(emdat.total.affected,na.rm=TRUE), .groups="drop"
#     ) %>%
#     mutate(
#       emdat.total.affected=ifelse(is.nan(emdat.total.affected),NA,emdat.total.affected),
#     ) %>%
#     rename(region = d_region) %>%
#     pivot_wider(id_cols = fecha, names_from = region,
#                 values_from = emdat.total.affected) %>%
#     complete(fecha = seq.Date(as.Date(start_date), as.Date(end_date), "1 month"))
#   # Manage region names: as in INPC data
#   reg <- tolower(make.names(names(ds), unique = TRUE))
#   reg <- stri_trans_general(str = reg, id = "Latin-ASCII") # removes accent
#   reg <- gsub("x.", "", reg)
#   reg <- gsub("cd..de.meco", "cdmx", reg)
#   names(ds) <- reg
#   # Data to quarterly frequency (if requested)
#   if( data_freq  == "Quarterly" ) ds <- to_quarterly(ds)
#   # Remove NaN values and pivot longer
#   values.name <- paste0("emdat.", substr(tolower(sb),1,5), ".tot.aff")
#   ds %>%
#     mutate(across(!fecha, ~ifelse(is.nan(.x), NA, .x))) %>%
#     pivot_longer(
#       cols = !fecha,
#       names_to = "region",
#       values_to = values.name
#     ) %>%
#     relocate(region, .after = fecha) %>%
#     arrange(region, !!sym(values.name), fecha)
# }) %>% Reduce(merge, .)

  


## Export data -----------------------------------------------------------------

# Temperature
fname <- paste0("temp_", no_regions, "region_", toupper(climate_db), ".xlsx")
write.xlsx(temp.norms, file.path(outputPath, fname))

# Precipitation
fname <- paste0("precip_", no_regions, "region_", toupper(climate_db), ".xlsx")
write.xlsx(prec.norms, file.path(outputPath, fname))

# # EMDAT
# fname <- paste0("disas_", no_regions, "region_EMDAT.xlsx")
# write.xlsx(emdat, file.path(outputPath, fname))

cat(" >> WEATHER ANOMALIES DATA DONE!! \n\n")

## Clean memory
rm(list = ls())
