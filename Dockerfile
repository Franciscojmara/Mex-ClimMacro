FROM rocker/rstudio:4.5.3@sha256:8db0c9a28c6f7a74d98c3df5f93133e981ad6f0287d7973332932c5601997b60

# ---- System dependencies (sf, tidyverse, etc.) ----
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    gfortran \
    cmake \
    pkg-config \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libudunits2-0 \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpoppler-cpp-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff-dev \
    libjpeg-dev \
    libnlopt-dev \
    libabsl-dev \
    && rm -rf /var/lib/apt/lists/*

# ---- renv configuration ----
ENV RENV_CONFIG_SYMLINKS=FALSE
ENV RENV_CONFIG_CACHE_ENABLED=FALSE

# ---- Set working directory inside container ----
WORKDIR /home/rstudio/project

# ---- Install renv ----
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org')"

# ---- Copy renv.lock ----
COPY renv.lock renv.lock
COPY renv/ renv/

# ---- Restore R environment ----
RUN R -e "setwd('/home/rstudio/project'); \
          renv::consent(provided = TRUE); \
          renv::load(); \
          options(repos = c(CRAN='https://cloud.r-project.org')); \
          renv::restore(prompt = FALSE)"

# ---- Copy full project (Scripts/, Data/, MAIN.R, etc.) ----
COPY . .

# ----- Fix Permissions -----
RUN chown -R rstudio:rstudio /home/rstudio/project

# ---- Configure RStudio to start in project directory ----
RUN mkdir -p /home/rstudio/.config/rstudio && \
    echo '{ "initial_working_directory": "/home/rstudio/project" }' \
    > /home/rstudio/.config/rstudio/rstudio-prefs.json && \
    chown -R rstudio:rstudio /home/rstudio/.config

# ---- Enforce RStudio to read .Rprofile ----
ENV R_PROFILE=/home/rstudio/project/.Rprofile

# ---- Expose RStudio Server port ----
EXPOSE 8787

# ---- Default: interactive RStudio session ----
CMD ["/init"]