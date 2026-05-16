# Reproducibility package for *The effects of temperature and rainfall anomalies on macroeconomic variables: The case of Mexico*

This repository provides a fully reproducible computational pipeline for the [paper](https://arxiv.org/pdf/2507.14420):

**The effects of temperature and rainfall anomalies on macroeconomic variables: The case of Mexico**  
*Lenin Arango-Castillo (Bank of Mexico)*\
*Francisco J. Martínez-Ramírez (Bank of Mexico)*

> This paper measures the effects of temperature and precipitation anomalies on Mexican headline inflation and total GDP per capita using two different approaches. We use data from all states in Mexico aggregated in seven geographical regions. We estimate the effects on inflation using Panel Local Projections method, while the effects on GDP per capita, using the Panel Autoregressive Distributed Lag Model. Our results indicate that neither temperature or precipitation anomalies have a statistically significant effect on GDP per capita, headline inflation, or their components.


The workflow is fully containerized using [**`Docker`**](https://docs.docker.com/get-started/docker-overview/), and uses [**`renv`**](https://rstudio-github-io.translate.goog/renv/index.html?_x_tr_sl=en&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=tc) to guarantee reproducibility of the R environment.

## Table of Contents

- [1. Project Structure](#1-project-structure)
- [2. Pipeline Overview](#2-pipeline-overview)
  - [a) Preamble and Global Configuration](#a-preamble-and-global-configuration)
  - [b) Data construction](#b-data-construction)
  - [c) Descriptive and Econometric Analysis](#c-descriptive--econometric-analysis)
- [3. Raw Data](#3-raw-data)
- [4. Setup](#4-setup)
  - [4.1 Clone the repository](#41-clone-the-repository)
  - [4.2 Install Docker (one-time)](#42-install-docker-one-time)
  - [4.3 Build the project environment (one-time)](#43-build-the-project-environment-one-time)
  - [4.4 Run the Full Pipeline](#44-run-the-full-pipeline)
    - [Interactive Mode (recommended)](#a-interactive-mode-recommended)
    - [Batch Mode](#b-batch-mode)
    - [Switching between modes](#switching-between-modes)
    - [Stop the environment](#stop-the-environment)
    - [Reproducibility](#reproducibility)
- [5. Citation](#5-citation)
- [6. Contact](#6-contact)


---

## 1. Project Structure

[Back to top](#table-of-contents)


```
.
├── MAIN.R
├── scripts/
│   ├── Functions/
│   ├── 00_Preamble.R
│   ├── 01_Manage_Climate_Regions.R
│   ├── 01_Manage_INPC_Regions.R
│   ├── 01_Manage_ITAEE-GDP_Regions.R
│   ├── 02_Merge_Macro-Climate-data_Regions.R
│   ├── 10_DescriptivePlots_Economic-Climate_Regions.R
│   ├── 11_IRF-LP_Economic-Climate_Regions.R
│   └── 12_ARDL_Economic-Climate_Regions.R
├── Data/
│   ├── Raw/
│   │   ├── Climate/
│   │   ├── Inflation/
│   │   ├── Economic_Activity/
│   │   └── Helpers/
│   └── Preprocessed/
├── Results/
│   ├── Figures/
│   └── Tables/
├── renv.lock
├── renv/
├── entrypoint.sh
├── docker-compose.yml
├── Dockerfile
└── README.md
```

---

#  2. Pipeline Overview

[Back to top](#table-of-contents)


The pipeline is orchestrated by the R script: `MAIN.R`. Located in the main directory of the project. From this file, the scripts from `scripts/` are called.

## a) Preamble and Global Configuration

The file `scripts/00_Preamble.R` is executed at the beginning of the pipeline and is central to reproducibility and consistency. It performs the following tasks:

- Loads all required R packages
- Defines global paths used across scripts
- Creates necessary directories if they do not exist:
  - `Data/Preprocessed/`
  - `Results/Tables/`
  - `Results/Figures/`
- Defines and stores hyperparameters used in:
  - Data construction
  - Model estimation

---

## b) Data construction

After cloning the repository, the raw data files are downloaded so you can construct the main data set from the beginning. Regardless, the main data set is still included in the repo. Although the raw climate data is also downloaded when cloning the repo, the pipeline still connects to the World Bank API and downloads the data. The macroeconomic data is only loaded on the scripts, there is no downloading step. 

The scripts that construct the main data set are those numbered "01" and "02" inside the `scripts/` directory:

- `01_Manage_Climate_Regions.R`
- `01_Manage_INPC_Regions.R`
- `01_Manage_ITAEE-GDP_Regions.R`
- `02_Merge_Macro-Climate-data_Regions.R`

The "01" scripts load the raw data from `Data/Raw` and will perform some data cleaning and preprocessing, for instance, seasonal adjustments, climate normal computations, climate anomalies construction, and further transformations (see section 3 of the paper for details on the variables used). The script "02" will load the preprocessed data, constructed in the "01" scripts, from the `Data/Preprocessed` directory and will merge all the macroeconomic and climate variables used in the study to construct the final data set, which will be stored directly on `Data/`.

## c) Descriptive & Econometric Analysis

The econometric analysis is done using the data set generated in the `02_Merge_Macro-Climate-data_Regions.R` script. The descriptive analysis is done in the script that starts with "10", while the econometric analysis: local-projections and the ARDL model are done in scripts "11" and "12", respectively. As in the data construction pipeline, some specifications for the analysis can be changed from the preamble script.

The scripts used in the analysis are:

- `10_DescriptivePlots_Economic-Climate_Regions.R`
- `11_IRF-LP_Economic-Climate_Regions.R`
- `12_ARDL_Economic-Climate_Regions.R`

Outputs are automatically saved in:

```
Results/
├── Tables/
└── Figures/
```

---

# 3. Raw Data

[Back to top](#table-of-contents)


The repository contains the raw data files needed to construct the main data set. Below, there is a brief description of the type of data and its source, along with the location of the files within the repository.

### a) Climate Data
- Source: Climate Research Unit (CRU), University of East Anglia (via [World Bank](https://climateknowledgeportal.worldbank.org/))
- Coverage: 1901–2024  
- Location: `Data/Raw/Climate/`

### b) Inflation Data
- Source: [CPI-INEGI](https://www.inegi.org.mx/programas/inpc/2018a/) (Consumer Price Index components)
- Location: `Data/Raw/Inflation/`

### c) GDP Data
- Source: [ITAEE-INEGI](https://www.inegi.org.mx/programas/itaee/2018/)
- Source: [GDP-INEGI](https://www.inegi.org.mx/programas/pibent/2018/) 
- Location: `Data/Raw/Economic_Activity/`

### d) Auxiliary Data
- Regional classification of Mexican states/cities
- Used to compute population-weighted regional aggregates  
- Location: `Data/Raw/Helpers/`

> IMPORTANT: Raw data may need to be manually provided depending on repository distribution.

---

# 4. Setup

## 4.1 Clone the repository

[Back to top](#table-of-contents)


In the terminal, use the following command:

```bash
git clone https://github.com/Franciscojmara/Mex-ClimMacro
cd Mex-ClimMacro
```

> **Windows users:** You can run these commands using **Git Bash**, **PowerShell**, or **VSCode terminal**.  
> If you don’t have Git, intall it [here](https://git-scm.com/download/win).

To clone this repository, you’ll need to authenticate with GitHub using either a Personal Access Token (PAT) or an SSH key.

### Github authentication (PAT or SSH)

#### Option 1 (recommended): Personal Access Token (HTTPS)
a) Generate a PAT in GitHub (**Settings → Developer settings → Personal access tokens**).
b) Use your GitHub username and the PAT as your password when cloning via HTTPS.
c) (Optional) Configure a credential helper to store it securely.

Full guide [here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)


#### Option 2: SSH Key
a) Generate an SSH key (`ssh-keygen`) and add it to your SSH agent.
b) Add the public key to your GitHub account (**Settings → SSH and GPG keys**).
c) Clone using the SSH URL (`git@github.com:...`).

Full guide [here](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)


## 4.2 Install Docker (one-time)

[Back to top](#table-of-contents)


Download and install [**Docker Desktop**](https://www.docker.com/products/docker-desktop/). After installing, open Docker Desktop and make sure it is running.

> **Windows users:** Docker Desktop is the recommended installation. Enable **WSL** if prompted during setup and restart your computer if required. We recommend to download [WSL2](https://learn.microsoft.com/en-us/windows/wsl/about#what-is-wsl-2), although it is not necessary to reproduce the environment.

### Install Docker from the Terminal (optional)
If you prefer installing Docker via the terminal instead of downloading Docker Desktop, you can use the following commands (Linux):

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin

sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $USER
```

> **Windows equivalent:** Not required when using Docker Desktop. All Docker commands below work from **PowerShell**, **Git Bash**, or **VSCode terminal** once Docker Desktop is running.

After running the last command, restart your terminal.

Test the installation:
```bash
docker --version
docker compose version
```

## 4.3 Build the project environment (one-time)

[Back to top](#table-of-contents)


```bash
docker compose build --no-cache
```

> **Windows users:** Run this command from PowerShell, Git Bash, or VSCode terminal, and ensure Docker Desktop is running.

This step prepares everything needed to run the project (R, packages, dependencies).  
It may take a few minutes the first time.


## 4.4 Run the Full Pipeline

[Back to top](#table-of-contents)


Inside the container, the pipeline will generate `.xlsx`, `.csv`, `.tex`, and `.pdf` files that will be exported into the following directories in the host machine, inside the main project directory.

- Tables: `Results/Tables/`
- Figures: `Results/Figures/`
- Processed data: `Data/Preprocessed/`

There are two modes for running the project's pipeline: interactive and batch.

---

### a) Interactive Mode (recommended)

This mode allows you to run the project's pipeline script by script, or even line by line. To do this, one must launch an R session in browser using `docker compose`.

First, from the terminal, launch RStudio using Docker:

```bash
docker compose up -d rstudio
```

And then go to 

http://localhost:8787

> This works the same on Windows, macOS, and Linux.  
> If the port 8787 is busy, you can change it modifying the `Dockerfile` and `docker-compose.yml` files, and then rebuilding the image, as in [step 4.3](#43-build-the-project-environment-one-time).

From the RStudio session, you can now open the `MAIN.R` script and inspect the project's source code. See the [Pipeline Overview](#4-pipeline-overview) section for more information.

---

### b) Batch Mode

If you are only interested in reproducing the whole project without inspection, you can do it in batch. In this mode, the data, figures, and tables generated inside the pipeline will be exported to their respective local directories in the host machine, that is, the analysis will be performed inside the virtual machine, but the results (data, tables, and figures) are exported to a local directory inside the host.

In the terminal (Windows, macOS, and Linux), run the full pipeline:

```bash
docker compose run --rm batch
```

---

### Switching between modes

You can switch between interactive and batch modes at any time:

- Use RStudio → `docker compose up -d rstudio`
- Run pipeline:
  - inside RStudio: `source("MAIN.R")`
  - or terminal: `docker compose run --rm batch`

No rebuilding is required.

---

### Stop the environment

```bash
docker compose down
```

---

### Reproducibility

This project guarantees reproducibility through:

- **Docker**: system dependencies and OS
- **renv**: exact R package versions (`renv.lock`)
- **Deterministic pipeline**: controlled script execution via `MAIN.R`

---

# 5. Citation

Please cite this project as:

> Arango-Castillo, L. and Martinez-Ramirez, F. J. (2026). The effects of temperature and rainfal anomalies on macroeconomic variables: The case of Mexico. ArXiv Working Paper 2507.14420, ArXiv.

```tex
@techreport{mexclim2026,
  title={{The effects of temperature and rainfall anomalies on macroeconomic variables: The case of Mexico}},
  author={Arango-Castillo, Lenin and Martinez-Ramirez, Francisco J.},
  institution={ArXiv},
  year={2026},
  number={2507.14420},
  type={ArXiv Working Paper},
  url={https://arxiv.org/abs/2507.14420}
}
```
---

# 6. Contact

[Back to top](#table-of-contents)


Lenin Arango-Castillo – larangoc@banxico.org.mx  
Francisco J. Martínez-Ramírez – franciscomr@banxico.org.mx  
