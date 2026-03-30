
# ============================================================================ #
#             Quarterly indicator of state's economic activity
#                           BY GEOGRAPHIC REGIONS
#
#
##  ** Note 1: OUTPUT of this script is EXPORTED to:
#          "./Data/Preprocessed"
#  ** Note 2: OUTPUT of this script is USED in:
#          "./Code/02_Merge_INPC-Climate_data.R"
# ============================================================================ #


## Preamble --------------------------------------------------------------------

load("scripts/Functions/Hyper-Parameters_Scripts.RData")
cat(" =================================================\n","\n",
    "           MANAGING PRODUCTION DATA               \n",
    "\n","=================================================\n\n")


## Auxiliary functions ---------------------------------------------------------

source("scripts/Functions/99_utils.R")



## Open data -------------------------------------------------------------------

inputPath  <- file.path(dataPath, "Raw")
outputPath <- file.path(dataPath, "Preprocessed")

## Cities, states, and regions
fname   <- "CiudadesxRegion.csv"
regions <- read.csv(file.path(inputPath, "Helpers", fname))

## Population (Censo 2020)
fname <- "Poblacion_Entidades_Censo2020.xlsx"
fpath <- file.path(inputPath, "Helpers", fname)
population <- read.xlsx(fpath, sheet = "02")

## ITAEE
fname  <- "ITAEE_Index_Base2018-2.xlsx"
itaee0 <- read.xlsx(file.path(inputPath, "Economic_Activity", fname))


## GDP - States
fname <- "PIBE_Base2018.xlsx"
gdp.0 <- read.xlsx(file.path(inputPath, "Economic_Activity", fname))

## GDP - National
fname <- "PIB_Base2018.xlsx"
pib.0 <- read.xlsx(file.path(inputPath, "Economic_Activity", fname))



## Manage regions & population data --------------------------------------------

## Regions

# Manage dates
start_date <- as.yearqtr(as.Date(start_date))
end_date   <- as.yearqtr(as.Date(end_date))

# Clean data
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

# Add national region
national <- data.frame(region_7 = 0, d_region_7 = "Nacional", region_4 = 0, 
                       d_region_4 = "Nacional", entidad = "Nacional")
regions <- rbind(regions, national)


## Population

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

# Get total population (in millions)
tot.popul  <- sum(population$poblacion)



## Manage ITAEE data -----------------------------------------------------------

# Manage raw data
itaee <- itaee0 %>% 
  slice(-c(1:3)) %>% 
  row_to_names(row_number = 1) %>% 
  rename_with(~stri_trans_general(make.names(tolower(.x)), id = "Latin-ASCII")) %>% 
  rename(entidad = area.geografica, index = indicador) %>% 
  mutate(
    entidad = gsub("^[0-9]{2}\\s", "", entidad),
    entidad = stri_trans_general(entidad, id = "Latin-ASCII"),
    entidad = gsub("Michoacan de Ocampo", "Michoacan", entidad),
    entidad = gsub("Coahuila de Zaragoza", "Coahuila", entidad),
    entidad = gsub("Veracruz de Ignacio de la Llave","Veracruz", entidad),
    entidad = gsub("Mexico", "Estado De Mexico", entidad),
    entidad = gsub("Ciudad de Estado De Mexico","Ciudad De Mexico", entidad),
    index = paste(
      "itaee",
      tolower(as.vector(str_match(index, "Total|primarias|secundarias|terciarias"))),
      sep = "."
      )
    ) %>% 
  filter(!is.na(entidad)) %>% 
  pivot_longer(cols = !c(index,entidad), names_to = "date", values_to = "itaee") %>%
  pivot_wider(id_cols = c(date,entidad), names_from = index, values_from = itaee) %>%
  mutate(
    date = as.yearqtr(str_replace_all(date, c("X" = "", "\\." = "Q"))),
    across(.cols = !c(date,entidad), ~ as.numeric(.x))
    ) %>% 
  filter(date >= as.yearqtr(start_date) & date <= as.yearqtr(end_date))

# Seasonal adjust data (if needed)
if (sead_adjst) {
  itaee <- lapply(sort(unique(itaee$entidad)), function(r){
    cat("             ", toupper(r), "\n")
    to.seas <- filter(itaee, entidad == r)
    if (data_freq == "Quarterly") {
      seas.st <- str_split_1(head(as.character(to.seas$date), 1), " Q")
    } else {
      seas.st <- str_split_1(head(as.character(to.seas$date), 1), "-")[1:2]
    }
    seas.fq <- ifelse(data_freq == "Quarterly", 4, 12)
    to.merg <- select(to.seas, date, entidad)
    to.seas <- to.seas %>%
      select(-c(date, entidad)) %>%
      ts(start = seas.st, frequency = seas.fq)
    to.seas <- ajuste_estacional(to.seas)$final
    cat("-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -\n")
    return(cbind(to.merg, to.seas))
  })
  itaee <- do.call(rbind, itaee)
}
  

# Merge ITAEE with regions
itaee <- full_join(regions, itaee, by = "entidad")

# Remove either 4 or 7 regions
if(no_regions != 32){
  to.rm <- ifelse(no_regions == "4", 7, 4)
  itaee <- select(itaee, -all_of(paste0(c("region_", "d_region_"), to.rm)))
  names(itaee)[1:2] <- c("region", "d_region")
} else {
  to.rm <- c("region_", "d_region_")
  itaee <- itaee %>% 
    select(-starts_with(to.rm)) %>% 
    arrange(date, entidad) %>% 
    group_by(entidad) %>%
    mutate(region=cur_group_id(), d_region=entidad, .before=everything()) %>% 
    ungroup()
}

# Standardize regions' names
itaee <- itaee %>% 
  mutate(
    d_region = tolower(d_region),
    d_region = stri_trans_general(str = d_region, id = "Latin-ASCII"),
    d_region = gsub("[.]", "", d_region),
    d_region = gsub(" ", ".", d_region),
    d_region = gsub("cd.de.mexico", "cdmx", d_region)
  ) %>% 
  filter(d_region != "nacional")



## Manage GDP data -------------------------------------------------------------

# Manage raw data
gdp.s <- gdp.0 %>% 
  slice(-c(1:3)) %>% 
  row_to_names(row_number = 1) %>% 
  rename_with(~stri_trans_general(make.names(tolower(.x)), id = "Latin-ASCII")) %>% 
  rename(entidad = area.geografica, index = indicador) %>% 
  mutate(
    entidad = gsub("^[0-9]{2}\\s", "", entidad),
    entidad = stri_trans_general(entidad, id = "Latin-ASCII"),
    entidad = gsub("Michoacan de Ocampo", "Michoacan", entidad),
    entidad = gsub("Coahuila de Zaragoza", "Coahuila", entidad),
    entidad = gsub("Veracruz de Ignacio de la Llave","Veracruz", entidad),
    entidad = gsub("Mexico", "Estado De Mexico", entidad),
    entidad = gsub("Ciudad de Estado De Mexico","Ciudad De Mexico", entidad),
    index = paste(
      "gdp",
      tolower(as.vector(str_match(index, "Total|primarias|secundarias|terciarias"))),
      sep = "."
    )
  ) %>% 
  filter(!is.na(entidad)) %>% 
  pivot_longer(cols = !c(index,entidad), names_to = "date", values_to = "gdp") %>%
  pivot_wider(id_cols = c(date,entidad), names_from = index, values_from = gdp) %>%
  mutate(
    date=as.yearqtr(as.Date(paste(str_replace_all(date,c("X"="")),"12-01",sep="-"))),
    entidad = gsub("Estados Unidos Mexicanos", "Nacional", entidad),
    across(.cols = !c(date,entidad), ~ as.numeric(.x))
  ) %>% 
  filter(date >= as.yearqtr(start_date) & date <= as.yearqtr(end_date)) 


## Complete each year (4 quarters by year) [based on dates of ITAEE]
gdp.s <- lapply(sort(unique(gdp.s$entidad)), function(x) {
  # Prepare full date sequence
  d.index <- as.yearqtr(seq(year(head(gdp.s$date,1)),year(tail(itaee$date,1))+1,by=1/4))
  d.index <- head(d.index, -1)
  # Complete date data frame
  dt <- gdp.s %>% filter(entidad == x) %>% select(-date)
  dt <- zoo(dt, order.by = unique(gdp.s$date))
  dt <- merge(dt, zoo(, d.index)) %>% 
    as.data.frame() %>% 
    rownames_to_column("date") %>% 
    relocate(date, .after = "entidad") %>% 
    fill(entidad, .direction = "down") 
})
gdp.s <- do.call(rbind, gdp.s) %>% 
  mutate(date = as.yearqtr(date)) %>% 
  mutate(across(.cols = starts_with("gdp"), ~ as.numeric(.x))) %>% 
  filter(entidad != "Nacional") %>% 
  filter(!is.na(entidad))


## Fill quarterly GDP using ITAEE's rate of change
gdp.s <- lapply(unique(gdp.s$entidad), function(x) {
  # Filter state of interest
  prod.s <- filter(itaee, entidad == x)
  data.s <- filter(gdp.s, entidad == x)
  data.s <- inner_join(data.s,select(prod.s,date,starts_with("itaee")),by=c("date"))
  # Fill by total GDP or by economic activity
  variables <- c("total","primarias","secundarias","terciarias")
  fill0 <- lapply(variables, function(y) {
    itaee.v <- paste("itaee", y, sep = ".")
    gdp.v   <- paste("gdp", y, sep = ".")
    # ITAEE quarterly growth
    d.itaee <- data.s[, itaee.v]
    d.itaee <- embed(d.itaee, 2)
    d.itaee <- d.itaee[,1]/d.itaee[,2]
    d.itaee <- data.frame(date=tail(data.s$date,length(d.itaee)), d.itaee=d.itaee)
    # Join ITAEE with GDP
    fill <- left_join(
      select(data.s, any_of(c("date", gdp.v))), d.itaee, by = "date"
    )
    names(fill) <- c("date", "gdp", "itaee")
    # Fill GDP using quarterly change of ITAEE
    new <- vector("numeric", length = nrow(fill))
    for (t in 1:nrow(fill)) {
      itd <- fill[t+1, "itaee"] # ITAEE from t + 1
      if(t %in% which(!is.na(fill$gdp))) {
        gdp <- fill[t, "gdp"] # GDP from t
        new[t+1] <- gdp    # From INEGI if it is not NA    
      } else {
        gdp <- new[t] # GDP from t
        new[t+1] <- gdp * itd # GDP_{t+1} using D%.ITAEE_{t+1} * GDP_{t}
      }
    }
    new <- head(new[-1], -1)
    new <- c(new, mean(tail(new, 4)))
    # Replace filled GDP in data frame
    fill <- fill %>% 
      mutate(gdp = new) %>% 
      rename_with(~paste(.x, y, sep="."), .cols = !date) %>% 
      select(-starts_with("itaee"))
  })
  fill <- Reduce(merge, fill0)
  # Merge with main data
  fill <- inner_join(
    select(data.s, -starts_with("gdp")), fill, by = "date"
  ) %>% 
    select(-starts_with("itaee"))
  return(fill)
})
gdp.s <- do.call(rbind, gdp.s)

# Dates as columns (to merge regions and calculate GDP per capita)
gdp.s.w <- gdp.s %>%
  pivot_longer(cols = !c(entidad,date), names_to = "itaee", values_to = "x") %>%
  pivot_wider(id_cols = c(entidad,itaee), names_from = date, values_from = x)

# Merge GDP with regions
regions2 <- full_join(regions,population,by="entidad") %>% filter(entidad!="Nacional")
gdp.s.w  <- full_join(regions2, gdp.s.w, by = "entidad")
gdp.s <- gdp.s.w
rm(gdp.s.w, regions2)

# Remove either 4 or 7 regions
if(no_regions != 32){
  to.rm <- ifelse(no_regions == "4", 7, 4)
  gdp.s <- select(gdp.s, -all_of(paste0(c("region_", "d_region_"), to.rm)))
  names(gdp.s)[1:2] <- c("region", "d_region")
} else {
  to.rm <- c("region_", "d_region_")
  gdp.s <- gdp.s %>% 
    select(-starts_with(to.rm)) %>% 
    arrange(entidad) %>% 
    group_by(entidad) %>%
    mutate(region=cur_group_id(), d_region=entidad, .before=everything()) %>% 
    ungroup()
}


# Standardize regions' names
gdp.s <- gdp.s %>% 
  mutate(
    d_region = tolower(d_region),
    d_region = stri_trans_general(str = d_region, id = "Latin-ASCII"),
    d_region = gsub("[.]", "", d_region),
    d_region = gsub(" ", ".", d_region),
    d_region = gsub("cd.de.mexico", "cdmx", d_region)
  ) %>% 
  filter(entidad != "Nacional")

# Calculate GDP per capita by states
# Aggregate states' GDP per capita by region
gdp.s <- gdp.s %>% 
  mutate(poblacion = poblacion / 1000000) %>% # because GDP is in millions 
  group_by(region, d_region, itaee) %>% 
  summarise( # aggregate GDP by region
    across(c("poblacion", starts_with("20")), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>% 
  mutate(across(starts_with("20"), ~ .x / poblacion)) %>% # calculate GDP per capita
  select(-poblacion)

# GDP as columns (date and state/region as in panel)
gdp.s <- gdp.s %>% 
  pivot_longer(cols=!c(region,d_region,itaee),names_to="date",values_to="x") %>% 
  pivot_wider(id_cols=c(region,d_region,date),names_from=itaee,values_from=x) %>% 
  mutate(date = as.yearqtr(date))



## Manage National GDP data ----------------------------------------------------

# Scale total population
tot.popul <- tot.popul/1000000 # because GDP is in millions

# Manage national GDP
pib.s <- pib.0 %>% 
  slice(-c(1:4)) %>% 
  rename_with( 
    ~ c("date","region","gdp.total","gdp.primarias","gdp.secundarias","gdp.terciarias")
    ) %>% 
  filter(!is.na(region)) %>% 
  separate(date, c("year","quarter"), "/") %>% 
  mutate(
    region   = 0, 
    d_region = "nacional",
    date     = as.yearqtr(paste(year, quarter, "01", sep = "-")),
    across(!c(d_region,region,date), ~ as.numeric(.x)/tot.popul), # GDP per capita
    .before = everything()
    ) %>% 
  select(-c(year, quarter))

cat("             NATIONAL\n")
stdate <- c(year(head(pib.s$date,1)), quarter(head(pib.s$date,1))) 
pib.sa <- ts(select(pib.s, starts_with("gdp")), start = stdate, frequency = 4)
pib.sa <- ajuste_estacional(pib.sa)$final
pib.s  <- cbind(select(pib.s,-starts_with("gdp")), pib.sa)
cat("-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -\n")



## Final regional GDP per capita data set --------------------------------------

# Append national with regional GDP per capita
gdp.s <- rbind(pib.s, gdp.s)
gdp.s <- select(gdp.s, region, everything())

# Interpolate data (if necessary)
if(data_freq == "Monthly") {
  # By state data (using time series)
  monthly <- lapply(unique(itaee$entidad), function(x){
    # data by state and helpers
    regns <- prod.s %>% filter(entidad == x)
    regns <- regns[1, 1:2]
    dat.0 <- prod.s %>% filter(entidad == x) %>% select(date, starts_with("itaee"))
    # remove yearqtr format
    dat.1 <- mutate(dat.0, date = as.Date(date) %m+% months(1))
    dat.2 <- mutate(dat.0, date = as.Date(date))
    # create a vector of dates to interpolate
    months <- lapply(dat.2$date, seq.Date, by = "month", length.out = 3)
    months <- data.frame(date = do.call(c, months))
    # left join date.frame to months to create NAs for interpolation
    monthly_data <- left_join(months, dat.1, by = "date")
    
    # interpolate data
    monthly_data$gdp.total       <- na.spline(monthly_data$gdp.total)
    monthly_data$gdp.primarias   <- na.spline(monthly_data$gdp.primarias)
    monthly_data$gdp.secundarias <- na.spline(monthly_data$gdp.secundarias)
    monthly_data$gdp.terciarias  <- na.spline(monthly_data$gdp.terciarias)
    
    # create entidad variable and merge with regions
    monthly_data$entidad  <- x
    monthly_data$region   <- regns$region
    monthly_data$d_region <- regns$d_region
    
    m.data <- monthly_data %>% 
      select(region, d_region, entidad, date, starts_with("itaee"), starts_with("gdp"))
    
    return(m.data)
  })
  prod.s <- do.call(rbind, monthly)
  rm(monthly)
  warning("DATA HAS BEEN INTERPOLATED TO BE MONTHLY, CAREFULL!!!!!!")
}

gdp.s <- gdp.s %>% 
  select(-region) %>% 
  rename(region = d_region)  



## Export data -----------------------------------------------------------------

vname <- ifelse(data_freq == "Quarterly", "-trimestral_", "-mensual_")
fname <- paste0("gdp-itaee", vname, no_regions, "region.csv")
write.csv(gdp.s, file.path(outputPath, fname), row.names = FALSE)
cat("\n")

## Clean memory
rm(list = ls())
