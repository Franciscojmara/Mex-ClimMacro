
# Main theme for all plots
theme_plots <- function(){
  theme_classic() +
    theme(
      panel.background = element_rect(fill="transparent", colour=NA_character_), 
      plot.background = element_rect(fill="transparent", colour=NA_character_), 
      panel.grid.major.y = element_line(color=alpha("#868686", 0.35), linewidth=0.5,
                                        linetype = 'longdash'),
      axis.line.y = element_blank(),
      axis.text.x = element_text(color = "#000000", size = 12, angle = 0, 
                                 hjust = 0.5,vjust = 0.4),
      axis.text.y = element_text(color = "#000000", size = 12, angle = 0),
      axis.ticks.x = element_line(colour = "#000000", linewidth = 0.5),
      axis.ticks.y = element_blank(),
      axis.ticks.length.x = unit(0.1,"cm"),
      axis.title = element_text(size = 16, angle = 90),
      plot.title = element_text(size = 16, hjust = 0.5),
      legend.title = element_blank(),
      legend.direction = "horizontal",
      legend.text = element_text(size = 12),
      legend.background = element_rect(fill='transparent'),
      legend.key.size = unit(1,"cm") 
    )
}

# Theme for box plots
theme_boxplot <- function(){
  theme_plots() +
    theme(
      axis.line.x  = element_line(linewidth=0.35),
      axis.ticks.x = element_line(colour = "#000000", linewidth = 0.5),
      axis.text.x  = element_text(angle = 90, size = 12, hjust = 1),
      axis.text.y  = element_text(angle = 00, size = 12),
      axis.title.y = element_text(size = 12),
      legend.position = "none"
    )
}

# Theme for maps
maps_theme <- function(){
  theme_bw() +
    theme(
      panel.border = element_blank(),
      panel.grid = element_blank(),
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      legend.key = element_rect(fill = NA, color = NA),
      legend.title = element_blank(),
      legend.text = element_text(size = 7),
      legend.key.size = unit(0.5, 'cm')
    )
}

# IRF plot theme
theme_irf <- function() {
  theme_classic() +
    theme(
      # plot panel options
      panel.background = element_rect(fill = "transparent", 
                                      colour = NA_character_), # no panel outline
      plot.background = element_rect(fill = "transparent",
                                     colour = NA_character_), # no plot outline
      panel.grid.major.y = element_line(color = alpha("#DDDDDD", 0.85),
                                        linewidth = 0.5, linetype = 'longdash'),
      panel.border = element_rect(colour = "black", fill=NA, linewidth=0.75),
      # panel.grid.major.y = element_blank(),
      # Axis text options
      axis.text.x = element_text(color = "#000000", size = 09, angle = 0, 
                                 hjust = 0.5,vjust = 0.4),
      axis.text.y = element_text(color = "#000000", size = 09, angle = 0),
      # Axis tick options
      axis.ticks = element_line(colour = "#000000", linewidth = 0.5),
      axis.ticks.length.y = unit(0.15,"cm"),
      axis.ticks.length.x = unit(0.15,"cm"),
      # Axis title options
      axis.title = element_text(size = 10, angle = 0),
      axis.title.y.right = element_text(size = 10),
      plot.title = element_text(size = 13, hjust = 0.5, vjust = 0.5),
      # legend options
      legend.title = element_blank(),
      legend.direction = "horizontal",
      legend.text = element_text(size = 09),
      legend.background = element_rect(fill='transparent'),
      legend.key.size = unit(1,"cm") 
    )
}

# Labels and colors for regions in plots
plvls0 <- c(
  "area.met.cdmx"  = "Mexico City",
  "centro.norte"   = "Center North",
  "centro.sur"     = "Center South",
  "centro"         = "Center",
  "frontera.norte" = "Northern Border",
  "noreste"        = "North East",
  "noroeste"       = "North West",
  "norte"          = "North",
  "sur"            = "South",
  "nacional"       = "National"
)
pfill0 <- c(
  "area.met.cdmx"  = "#8B008B", 
  "centro.sur"     = "#FF0000",
  "centro.norte"   = "#668555", 
  "sur"            = "#EBA55F", 
  "frontera.norte" = "#333F50",
  "noreste"        = "#E75480", 
  "noroeste"       = "#009999", 
  "norte"          = "#333F50",
  "centro"         = "#009999",
  "nacional"       = "#000000"
)