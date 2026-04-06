
## ========================================================================== ##
#                       Time series plots and maps                             #
#                    Climate anomalies vs CPI and GDP                          #
#                          Mexican regions panel                               #
## ========================================================================== ##

# NOTE: Data used in this script is generated from the R script: 
#    "./Code/02_Merge_Macro-Climate-data_Regions.R"


## ========================================================================== ##
## Preamble -----------------------------------------------------------------
## ========================================================================== ##

load("scripts/Functions/Hyper-Parameters_Scripts.RData")
cat(" =================================================\n","\n",
    "    DESCRIPTIVE FIGURES: CLIMATE & INFLATION     \n",
    "\n","=================================================\n\n")



## ========================================================================== ##
## Auxiliary functions -----------------------------------------------------
## ========================================================================== ##

# Miscellaneous functions
source("scripts/Functions/99_utils.R")

# For plots
source("scripts/Functions/99_plots.R")



## ========================================================================== ##
## Load & manage data -------------------------------------------------------
## ========================================================================== ##

## Load data -- Climate and inflation data
mname <- ifelse(climate_db == "CONAGUA", 15, 30)
vname <- ifelse(sead_adjst, "ae-", "-")
cname <- ifelse(center_dta, "-Centered", "")
dname <- toupper(climate_db)
fname <- paste0("INPC", vname, "Climate-", dname, "_", data_freq, "_", 
                no_regions, "Regions", cname, ".xlsx")
fpath <- file.path(dataPath, fname)
inpc.clim0 <- read.xlsx(fpath, sheet = paste("MA.mean", mname, sep = "-"))

## Load data -- Mexico polygon
fpath   <- file.path(dataPath, "Mexico_Map")
mex.map <- st_read(fpath, layer = "mexican-states", quiet = TRUE)
mex.reg <- read.csv(file.path(dataPath, "Mexico_Map/CiudadesxRegion.csv"))


## Manage data -- Climate and inflation data

# Date variable
start_date <- as.Date(start_date)
end_date   <- as.Date(end_date)
if (data_freq == "Monthly") {
  inpc.clim <- inpc.clim0 %>% 
    mutate(date = as.Date(paste(year, month, "01", sep = "-"))) %>% 
    select(date, everything()) %>% 
    select(-c(year, month))
} else {
  inpc.clim <- inpc.clim0 %>% 
    mutate(quartr = quartr * 3) %>% # 4th quarter * 3 = 12 month
    mutate(date = as.Date(paste(year, quartr, "01", sep = "-"))) %>% 
    select(date, everything()) %>% 
    select(-c(year, quartr))
}
inpc.clim <- na.omit(inpc.clim)

## Manage data -- Mexico polygon (and regions)

# Manage states and regions
mex.reg <- mex.reg %>% 
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

# Remove either 7 or 4 regions
if(no_regions != 32){
  to.rm   <- ifelse(no_regions == "4", 7, 4)
  mex.reg <- select(mex.reg, -all_of(paste0(c("region_", "d_region_"), to.rm)))
  names(mex.reg)[1:2] <- c("region", "d_region")
} else {
  to.rm   <- c("region_", "d_region_")
  mex.reg <- select(mex.reg, -starts_with(to.rm))
  mex.reg <- mutate(mex.reg, region=1:32, d_region=entidad, .before=everything())
}

# Manage state names in map (to merge with regions)
mex.map$name <- stri_trans_general(str = mex.map$name, id = "Latin-ASCII")#no accents
mex.map$name <- gsub("Michoacan de Ocampo", "Michoacan", mex.map$name)
mex.map$name <- gsub("Coahuila de Zaragoza", "Coahuila", mex.map$name)
mex.map$name <- gsub("Veracruz de Ignacio de la Llave","Veracruz",mex.map$name)
mex.map$name <- gsub("Mexico", "Estado De Mexico", mex.map$name)
mex.map$name <- gsub("Ciudad de Estado De Mexico","Ciudad De Mexico",mex.map$name)
mex.map$name <- str_squish(mex.map$name) # remove white space start & end

# Add regions to mex.map
mex.map <- rename(mex.map, entidad = name)
mex.map <- full_join(mex.map, mex.reg, by = "entidad")

# Manage regions name
if (no_regions != 32) {
  mex.map <- mex.map %>% 
    mutate(
      d_region = tolower(make.names(d_region, unique = TRUE)),
      d_region = stri_trans_general(str = d_region, id = "Latin-ASCII"),#no accent
      d_region = gsub("x.", "", d_region),
      d_region = gsub("cd..de.meco", "cdmx", d_region),
      d_region = gsub(".[1-9]$", "", d_region)
    )
} else {
  mex.map <- mex.map %>% 
    mutate(
      d_region = tolower(make.names(d_region, unique = TRUE)),
      d_region = stri_trans_general(str = d_region, id = "Latin-ASCII"),#no accent
      d_region = gsub("meco", "mexico", d_region),
      d_region = gsub("tlaala", "tlaxcala", d_region),
      d_region = gsub("oaca", "oaxaca", d_region),
      d_region = gsub("michoaxacan", "michoacan", d_region)
    )
}


## Data to use in all plots and tables

# Inflation data
ifreq <- ifelse(data_freq == "Quarterly", 4, 12)
idata <- lapply(unique(inpc.clim$region), function(x){
  # date for ts object and helpers to calculate inflation
  qmfunc <- get(ifelse(data_freq == "Quarterly", "quarter", "month"))
  endate <- tail(inpc.clim[, "date"], 1)
  endate <- c(year(endate), qmfunc(endate))
  datesq <- unique(inpc.clim$date)
  # data as time series
  cpi <- filter(inpc.clim, region == x) %>% 
    select(
      headline, core, food, nonfood, services, agriculture, energy, starts_with("gdp")
      ) %>% 
    rename_with(~ paste0("d.", .x), starts_with("gdp"))
  cpi <- ts(cpi, end = endate, frequency = ifreq)
  # CPI inflation
  inf <- calculate.inflation(cpi, var = infvar, dfrequency = ifreq, approx = TRUE)
  mutate(as.data.frame(inf), date=tail(datesq,nrow(inf)), region=x, .before=headline)
}) %>% do.call(rbind, .) 

# GDP/Climate data
cdata <- inpc.clim %>% 
  select(date, region, starts_with("gdp"), starts_with("temp"), starts_with("precip"), 
         starts_with("deviation")) %>%
  select(-ends_with("_or")) %>% 
  mutate(across(starts_with("gdp"), ~ .x/1000)) # units to thousands pesos (for shortness)



# ---------------------------------------------------------------------------- #
#                             Summary statistics 
# ---------------------------------------------------------------------------- #

regionsP <- unique(inpc.clim$region)[!(grepl("nacional",unique(inpc.clim$region)))]
inpc_var <- c("headline","core","food","nonfood","services","agriculture","energy")

## Summary statistics table ----------------------------------------------------

# Table
sum.table <- inner_join(idata, cdata, by = c("date", "region"))  %>% 
  select(region, headline, gdp.total, starts_with("dev")) %>% 
  mutate(region = Vectorize(region.titles)(region)) %>% 
  pivot_longer(cols = !region, names_to = "var", values_to = "x") %>% 
  group_by(var, region) %>% 
  summarise(
    mean = mean(x, na.rm = TRUE),
    stdv = sd(x, na.rm = TRUE),
    p25  = quantile(x, probs = 0.25, na.rm = TRUE),
    p50  = quantile(x, probs = 0.50, na.rm = TRUE),
    p75  = quantile(x, probs = 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>% 
  mutate(
    across(
      where(is.numeric),
      ~ case_when(
        var %in% c("gdp.total", "headline") ~ sprintf("%.2f", round(.x, 2)),
        var %in% c("deviation.temp", "deviation.precip") ~ sprintf("%.4f", round(.x, 4)),
        TRUE ~ as.character(.x)
      )
    ),
    var = Vectorize(var.titles)(var)
  )

# Table: Set region as factor and order "nacional" at the top
regs <- c("National", setdiff(unique(sum.table$region), "National"))
vars <- c("Total real GDP per capita", "Headline inflation", "Temperature anomalies", 
          "Precipitation anomalies")
sum.table$region <- factor(sum.table$region, levels = regs)
sum.table$var    <- factor(sum.table$var, levels = vars)
sum.table <- sum.table[order(sum.table$var, sum.table$region), ]

# Table: export - Cleaned and formatted table to xlsx/tex formats
if(no_regions != 32) source("scripts/Functions/50_Summary_Tables.R")



# ---------------------------------------------------------------------------- #
#                   Time series of macroeconomic variables
# ---------------------------------------------------------------------------- #

## Time series of inflation ---------------------------------------------------

## Plot price inflation -- National headline inflation 

# Plot: data
pdata.r <- idata %>% select(date, region, headline) %>% filter(region != "nacional") 
pdata.n <- idata %>% select(date, region, headline) %>% filter(region == "nacional") 

# Plot: helpers
ybreaks <- seq(0, 2.5, 0.5)
xbreaks <- seq.Date(
  start_date %m+% months(ifelse(infvar == "y", 12, 3)), end_date, by = "4 year"
)

# Plot: figure
(p <- ggplot() +
  geom_line(aes(date, headline, group=region), data=pdata.r, linewidth=0.75,
            color=alpha("#868686",0.70)) +
  geom_line(aes(date, headline), data=pdata.n, linewidth=0.75, color="#182B47") +
  labs(x = "", y = "Percent change") + 
  scale_x_date(breaks = xbreaks, date_labels = "%Y", expand = c(0,0)) +
  scale_y_continuous(breaks = ybreaks) +
  coord_cartesian(ylim = c(head(ybreaks, 1), tail(ybreaks, 1))) +
  theme_plots() + 
  theme(legend.position = "none"))

# Plot: export
fname <- paste0("TimeSeries_National-Inflation-HEADLINE_",data_freq,"_",no_regions, 
                "Regions.pdf")
fpath <- file.path(figsPath, "Inflation")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
fpath <- file.path(fpath, fname)
if(no_regions != 32) ggsave(fpath, p, width=15, height=9, units="cm", dpi=300)


## Plot price inflation -- All series, all regions (intended for appendix)
for (i in inpc_var) {
  
  # Plot: data
  pdata <- select(idata, any_of(c("date", "region", i)))
  names(pdata)[3] <- "inflation"
  
  regs <- c("nacional", setdiff(unique(pdata$region), "nacional"))
  pdata$region <- factor(pdata$region, levels = regs)
  
  # Plot: helpers
  # pregions <- str_to_title(gsub("[.]", " ", unique(idata$region)))
  xbreaks <- seq.Date(
    start_date %m+% months(ifelse(infvar == "y", 12, 3)), end_date, by = "4 year"
  )
  if (!(i %in% c("energy", "agriculture", "food"))) {
    ybreaks <- seq(-1, 4, 1) 
  } else if (i == "energy" | i == "agriculture") {
    ybreaks <- seq(-10, 15, 5) 
  } else if (i == "food") {
    ybreaks <- seq(-1, 4, 1) 
  }

  # Plot: figure
  (p <- ggplot() +
      geom_line(aes(date, inflation), data = subset(pdata, region == "nacional"),
                linewidth = 0.75, color = "#000000") +
      geom_line(aes(date, inflation, color = region), data = pdata, linewidth = 0.75) +
      geom_hline(yintercept = 0, linewidth = 0.4) +
      labs(x = "", y = "Percent change") + 
      coord_cartesian(ylim = c(head(ybreaks, 1), tail(ybreaks, 1))) +
      scale_y_continuous(breaks = ybreaks) + 
      scale_x_date(breaks = xbreaks, date_labels = "%Y", expand = c(0,0)) +
      scale_color_manual(values = pfill0, labels = plvls0) +
      theme_plots() + 
      theme(legend.position = "none"))
  
  if (i == "headline") {
    p <- p + 
      guides(color = guide_legend(ncol = 2)) + 
      theme(
        legend.key.size = unit(0.35,"cm"),
        legend.text=element_text(size=10),
        legend.spacing.y = unit(0.01, 'cm'),
        legend.position = "inside",
        legend.position.inside = c(0.35, 0.78)
      )
  }
  
  # Plot: export
  fname <- paste0("TimeSeries_Regional-Inflation-", toupper(i), "_", data_freq, "_", 
                  no_regions, "Regions.pdf")
  fpath <- file.path(figsPath, "Inflation", fname)
  if(no_regions != 32) ggsave(fpath, p, width=15, height=9, units="cm", dpi=300)
}



## Time series of GDP per capita -----------------------------------------------

## Plot real GDP per capita -- National total

# Plot: data
pdata.r <- idata %>% select(date, region, d.gdp.total) %>% filter(region != "nacional") 
pdata.n <- idata %>% select(date, region, d.gdp.total) %>% filter(region == "nacional") 

# Plot: helpers
ybreaks <- seq(-15, 15, 5) 
xbreaks <- seq.Date(
  start_date %m+% months(ifelse(infvar == "y", 12, 3)), end_date, by = "4 year"
)

# Plot: figure
(p <- ggplot() +
    geom_line(aes(date, d.gdp.total, group=region), data=pdata.r, linewidth=0.75,
              color=alpha("#868686",0.75)) +
    geom_line(aes(date, d.gdp.total), data=pdata.n, linewidth=0.75, color="#182B47") +
    labs(x = "", y = "Percent change") + # "Thousands of pesos, 2018 prices" 
    scale_x_date(breaks = xbreaks, date_labels = "%Y", expand = c(0,0)) +
    scale_y_continuous(breaks = ybreaks) +
    coord_cartesian(ylim = c(head(ybreaks, 1), tail(ybreaks, 1))) +
    theme_plots() + 
    theme(legend.position = "none"))

# Plot: export
fname <- paste0("TimeSeries_National-GDP-TOTAL-PerCapita_", data_freq, ".pdf")
fpath <- file.path(figsPath, "GDP")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
fpath <- file.path(fpath, fname)
if(no_regions != 32) ggsave(fpath, p, width=15, height=9, units="cm", dpi=300)


## Plot real GDP per capita -- Sector and region total

# Iterate by type of GDP
for (pvar0 in c("total","primarias","secundarias","terciarias")) {
  # Plot: data
  pvar  <- paste("d.gdp", pvar0, sep = ".")
  pdata <- select(idata, any_of(c("date", "region", pvar)))
  names(pdata)[3] <- "gdp"
  
  regs <- c("nacional", setdiff(unique(pdata$region), "nacional"))
  pdata$region <- factor(pdata$region, levels = regs)

  # Plot: helpers
  xbreaks <- seq.Date(
    head(cdata$date,1) %m+% months(3), tail(cdata$date,1), by="4 year"
  )
  if (pvar0 == "total") {
    ybreaks <- seq(-15, 15, 5) # seq(0, 500, 100)
  } else if (pvar0 == "primarias") {
    ybreaks <- seq(-27, 27, 9) # seq(0, 25, 5)
  } else if (pvar0 == "secundarias") {
    ybreaks <- seq(-15, 15, 5) # seq(0, 125, 25)
  } else {
    ybreaks <- seq(-15, 15, 5) # seq(0, 400, 100)
  } 
  
  # Plot: figure
  (p <- ggplot() + 
      geom_line(aes(date, gdp), data = subset(pdata, region == "nacional"),
                linewidth = 0.75, color = "#000000") +
      geom_line(aes(date, gdp, color = region), data = pdata, linewidth = 0.75) +
      labs(x = "", y = "Percent change") + 
      scale_color_manual(values = pfill0, labels = plvls0) +
      scale_x_date(breaks = xbreaks, date_labels = "%Y", expand = c(0,0)) +
      scale_y_continuous(breaks = ybreaks) +
      coord_cartesian(ylim = c(head(ybreaks,1), tail(ybreaks,1))) +
      theme_plots() + 
      theme(legend.position = "none"))
  if (pvar0 == "total") {
    p <- p + 
      guides(color = guide_legend(ncol = 3)) + 
      theme(
        legend.key.size = unit(0.35,"cm"),
        legend.text=element_text(size=10),
        legend.spacing.y = unit(0.01, 'cm'),
        legend.position = "inside",
        legend.position.inside = c(0.38, 0.80)
      )
  }
  
  # Plot: export
  fname <- paste0("TimeSeries_Regional-GDP-", gsub("^D\\.GDP\\.", "", toupper(pvar)),
                  "-PerCapita_", data_freq, "_", no_regions, "Regions.pdf")
  fpath <- file.path(figsPath, "GDP", fname)
  if(no_regions != 32) ggsave(fpath, p, width=15, height=9, units="cm", dpi=300)
}



# ---------------------------------------------------------------------------- #
#             Time series & distributions of climate variables
# ---------------------------------------------------------------------------- #


## Time series of temperature anomalies ----------------------------------------

# Plot: data
pdata <- cdata %>% 
  select(date, region, deviation.temp) %>% 
  group_by(region) %>% 
  mutate(deviation.temp = deviation.temp - dplyr::lag(deviation.temp)) %>% 
  slice(-1) %>% 
  ungroup() 

regs <- c("nacional", setdiff(unique(pdata$region), "nacional"))
pdata$region <- factor(pdata$region, levels = regs)

# Plot: helpers
ybreaks   <- seq(-0.1, 0.1, 0.05)
dtebreaks <- seq.Date(
  head(inpc.clim$date,1) %m+% months(3), tail(inpc.clim$date,1), by="4 year"
)

# Plot: Population-weighted temperature deviations
for(tp in c("national", "regional")) {
  
  # Base plot depending on the type of plot
  if(tp == "national") {
    p <- ggplot() +
      geom_line(aes(date, deviation.temp, group=region), data=pdata, linewidth=0.75,
                color=alpha("#868686",0.75)) +
      geom_line(aes(date, deviation.temp), data = subset(pdata, region == "nacional"), 
                linewidth=0.75, color="#182B47") 
  } else {
    p <- ggplot() + 
      geom_line(aes(date, deviation.temp), data = subset(pdata, region == "nacional"), 
                linewidth=0.75, color="#000000") +
      geom_line(aes(date, deviation.temp, color=region), data=pdata, linewidth=0.75) +
      scale_color_manual(values = pfill0, labels = plvls0) 
  }
  # Add format to plot
  (
    p <- p +
      geom_hline(yintercept = 0, linewidth = 0.5) +
      labs(x = "", y = expression(Delta * tilde(T)[it](m))) +
      scale_x_date(breaks = dtebreaks, date_labels = "%Y", expand = c(0, 0)) +
      scale_y_continuous(breaks = ybreaks) +
      coord_cartesian(ylim = c(head(ybreaks, 1), tail(ybreaks, 1))) +
      theme_plots() +
      theme(
        legend.key.size = unit(0.5,"cm"),
        legend.text=element_text(size=10),
        legend.position = "inside",
        legend.position.inside = c(0.50, 0.15)
      )
  )
  
  # Plot: export
  tname <- str_to_sentence(tp)
  fname <- paste0("TimeSeries_", tname, "-TEMPDEV-", climate_db, "_", data_freq)
  fpath <- file.path(figsPath, "Climate")
  if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
  if(tp == "regional") {
    fname <- paste(fname, paste0(no_regions, "Regiones"), sep = "_")
  }
  fpath <- file.path(fpath, paste(fname, "pdf", sep = "."))
  if(no_regions != 32) ggsave(fpath, p, width = 15, height = 09, units = "cm")
}



## Time series of precipitation anomalies --------------------------------------

# Plot: data
pdata <- cdata %>% 
  select(date, region, deviation.precip) %>% 
  group_by(region) %>% 
  mutate(deviation.precip = deviation.precip - dplyr::lag(deviation.precip)) %>% 
  slice(-1) %>% 
  ungroup() 

regs <- c("nacional", setdiff(unique(pdata$region), "nacional"))
pdata$region <- factor(pdata$region, levels = regs)

# Plot: helpers
ybreaks   <- seq(-4, 4, 2)
dtebreaks <- seq.Date(
  head(inpc.clim$date,1) %m+% months(3), tail(inpc.clim$date,1), by="4 year"
)

# Plot: Population-weighted precipitation deviations
for(tp in c("national", "regional")) {
  
  # Base plot depending on the type of plot
  if(tp == "national") {
    p <- ggplot() +
      geom_line(aes(date, deviation.precip, group=region), data=pdata, linewidth=0.75,
                color=alpha("#868686",0.75)) +
      geom_line(aes(date, deviation.precip), data = subset(pdata, region == "nacional"), 
                linewidth=0.75, color="#182B47") 
  } else {
    p <- ggplot() + 
      geom_line(aes(date, deviation.precip), data = subset(pdata, region == "nacional"), 
                linewidth=0.75, color="#000000") +
      geom_line(aes(date, deviation.precip, color=region), data=pdata, linewidth=0.75) +
      scale_color_manual(values = pfill0, labels = plvls0) 
  }
  # Add format to plot
  (
    p <- p +
      geom_hline(yintercept = 0, linewidth = 0.5) +
      labs(x = "", y = expression(Delta * tilde(P)[it](m))) +
      scale_x_date(breaks = dtebreaks, date_labels = "%Y", expand = c(0, 0)) +
      scale_y_continuous(breaks = ybreaks) +
      coord_cartesian(ylim = c(head(ybreaks, 1), tail(ybreaks, 1))) +
      theme_plots() +
      theme(legend.position = "none")
  )
  
  # Plot: export
  tname <- str_to_sentence(tp)
  fname <- paste0("TimeSeries_", tname, "-PRECIPDEV-", climate_db, "_", data_freq)
  fpath <- file.path(figsPath, "Climate")
  if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
  if(tp == "regional") {
    fname <- paste(fname, paste0(no_regions, "Regiones"), sep = "_")
  }
  fpath <- file.path(fpath, paste(fname, "pdf", sep = "."))
  if(no_regions != 32) ggsave(fpath, p, width = 15, height = 09, units = "cm")
}



## Distributions population-weighted weather anomalies -------------------------

for (cvar in c("deviation.temp", "deviation.precip")) {
  
  ## Data to plot: select variables of interest and pivot data
  pdata <- inpc.clim %>%
    select(date, region, season, all_of(cvar)) %>% 
    pivot_wider(id_cols = c(date, season), 
                names_from = region, 
                values_from = all_of(cvar)) %>% 
    select(-date) %>% 
    mutate(season = factor(season,levels = rev(c("invierno","primavera","verano",
                                                 "otono"))))
  pdata$season <- dplyr::recode(pdata$season, verano = "Summer", primavera = "Spring", 
                         otono = "Autumn", invierno = "Winter")
  
  ## Plot
  for (region in names(pdata)[-1]) {
    # Plot: Helpers
    fill.pal <- hcl.colors(20, "BluGrn") 
    
    # Plot: Data
    pdat <- select(pdata, any_of(c("season", region)))
    names(pdat)[2] <- "region0" 
    
    # Plot: Figure
    p <- ggplot(pdat, aes(x = region0, y = season, fill = after_stat(x))) + 
      geom_density_ridges_gradient(linewidth = 0.5) +
      scale_fill_viridis(option = "G") +
      labs(x = "", y = "") +
      theme_ridges(line_size = 0.025, grid = FALSE) +
      theme(
        plot.title = element_text(size = 16),
        axis.text.x = element_text(color = "#000000", size = 11, angle = 0, 
                                   hjust = 0.5,vjust = 0.4),
        axis.text.y = element_text(color = "#000000", size = 11, angle = 0),
        legend.position = "none"
      )
    
    # Export figure
    vname <- ifelse(grepl("temp", cvar), "TemperatureDev", "PrecipitationDev")
    subdir<- ifelse(grepl("temp", cvar), "Temp-Distrib", "Precip-Distrib")
    fname <- paste0("Dist-",vname,"_",no_regions, "R-",
                    toupper(region.titles.plot(region)),"_",data_freq,"_MA",mname,".pdf")
    fpath <- file.path(figsPath, file.path("Climate", subdir))
    if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
    fpath <- file.path(fpath, fname)
    if(no_regions != 32) ggsave(fpath, p, width=16, height=9, units="cm", dpi=300)
  }
}



# ---------------------------------------------------------------------------- #
#                                 Regions Map
# ---------------------------------------------------------------------------- #

## Map regions -----------------------------------------------------------------

# Plot: data
pdata <- mex.map

# Plot: Figure
(p1 <- ggplot(pdata) +
    geom_sf(aes(fill = d_region)) + 
    scale_fill_manual(values = pfill0, labels = plvls0) +
    maps_theme() +
    theme(
      legend.text = element_text(size = 5),
      legend.key.size = unit(0.35, 'cm'),
      legend.position = c(0.8, 0.65)
    )
)

# Plot: export
fpath <- file.path(figsPath, "Maps")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)
fpath <- file.path(fpath, paste0("Map-Mexico_", no_regions, "Regions.pdf"))
if(no_regions != 32) ggsave(fpath, plot=p1, width=15, height=12, units="cm", dpi=300)



## Clean memory ----------------------------------------------------------------
rm(list = ls())
