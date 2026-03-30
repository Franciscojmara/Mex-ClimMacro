
## ========================================================================== ##
#                        Summary data: Excel/Latex tables                            #
#                    Climate anomalies vs Macroeconomy                         #
#                           Mexican regions panel                              #
## ========================================================================== ##

# NOTE: Data used in this script is generated from the R script: 
#    "./Code/10_DescriptivePlots_Economic-Climate_Regions.R"


## Prettify for excel ----------------------------------------------------------

# Manage
pretty.xlsx <- sum.table %>%
  group_by(var) %>% 
  mutate(var = ifelse(row_number() == 1, as.character(var), NA)) %>% 
  ungroup()
names(pretty.xlsx)[1] <- ""

# Export 
fname <- paste0("Summary_INPC-GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_MA", mname, ".xlsx")
write.xlsx(pretty.xlsx, file.path(resuPath, fname))



## Prettify for latex ----------------------------------------------------------

# Manage
pretty.tex <- sum.table %>% 
  group_by(var) %>% 
  mutate(
    gpo = cur_group_id(),
    var = as.character(var),
    var = case_when(
      var == "Precipitation anomalies" ~ "$\\Tilde{P}_{it}(m)$",
      var == "Temperature anomalies" ~ "$\\Tilde{T}_{it}(m)$",
      TRUE ~ var
      ),
    var = paste0("\\multirow{",no_regions,"}{8em}{",var,"}")
  ) %>% 
  ungroup() %>% 
  group_by(gpo) %>%
  mutate(var = ifelse(row_number() == 1, var, NA)) %>% 
  ungroup() %>% 
  filter(row_number() != n()) %>% 
  select(-gpo)
names(pretty.tex) <- c("", "Region", "Mean", "Standard deviation", "Percentile 25th",
                       "Percentile 50th", "Percentile 75th")

# Add \midrule command
n <- nrow(pretty.tex)
breaks <- seq(8, n, by = 8)
breaks <- breaks[breaks < n]   # avoid placing rule after last row
addtorow <- list(
  pos = as.list(breaks),
  command = rep("\\midrule\n", length(breaks))
)


fname <- paste0("Summary_INPC-GDP-", climate_db, "_", data_freq, "_", no_regions,
                "Regiones_MA", mname, ".tex")
fpath <- file.path(resuPath, "Latex.Tables")
if(!dir.exists(fpath)) dir.create(fpath, recursive = TRUE)

# Export results as a latex formatted table
print(xtable(pretty.tex),
      NA.string = "",
      only.contents = T,
      include.colnames = T,
      include.rownames = F, 
      add.to.row = addtorow,
      sanitize.text.function = identity,
      booktabs = TRUE, 
      comment = FALSE,
      file = file.path(fpath, fname)
      )
