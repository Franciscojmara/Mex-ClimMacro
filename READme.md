# Reproducibility package for *The effects of temperature and rainfall anomalies on macroeconomic variables: The case of Mexico*

This repository provides a fully reproducible computational pipeline for the [paper](https://arxiv.org/pdf/2507.14420):

> **The effects of temperature and rainfall anomalies on macroeconomic variables: The case of Mexico**  
> Lenin Arango-Castillo (Bank of Mexico)  
> Francisco J. Martínez-Ramírez (Bank of Mexico)

This project combines **climate data and inflation data** to estimate the impact of weather shocks on inflation using econometric techniques such as **Local Projections (LP)** and **panel ARDL models**.

The workflow is fully containerized using **Docker** and uses [**`renv`**](https://rstudio-github-io.translate.goog/renv/index.html?_x_tr_sl=en&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=tc) to guarantee reproducibility of the R environment.

---

## Project Structure

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
├── Dockerfile
└── README.md
```

---

# Setup

## 1. Clone the repository

```bash
git clone https://github.com/Franciscojmara/Mex-ClimMacro
cd Mex-ClimMacro
```

### Github authentication (PAT or SSH)

To clone this repository, you’ll need to authenticate with GitHub using either a Personal Access Token (PAT) or an SSH key.

#### Option 1 (recommended): Personal Access Token (HTTPS)
1. Generate a PAT in GitHub (**Settings → Developer settings → Personal access tokens**).
2. Use your GitHub username and the PAT as your password when cloning via HTTPS.
3. (Optional) Configure a credential helper to store it securely.

Full guide: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

---

#### Option 2: SSH Key
1. Generate an SSH key (`ssh-keygen`) and add it to your SSH agent.
2. Add the public key to your GitHub account (**Settings → SSH and GPG keys**).
3. Clone using the SSH URL (`git@github.com:...`).

Full guide: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

### Outputs

Inside the image, the pipeline will generate `.xlsx`, `.csv`, `.tex`, and `.pdf` files that will be exported into the following directories.

- Tables: `Results/Tables/`
- Figures: `Results/Figures/`
- Processed data: `Data/Preprocessed/`


## 2. Build the Docker image

```bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t mexclim .
```

Using the ---build-arg, ensures that the container has the permissions to write files in the host machine (only if mounting directories). The files that the programs will export are the paper's tables and figures.

#### IMPORTANT caveat
This works on Linux / WSL / macOS. On Windows (non-WSL), $(id -u) won’t work, so you can fallback to:

```bash
docker build -t mexclim .
```

---

## 3. Run the Full Pipeline

### ▶️ Batch Mode

```bash
docker run --rm \
  -v $(pwd)/Data:/home/rstudio/project/Data \
  -v $(pwd)/Results:/home/rstudio/project/Results \
  mexclim \
  Rscript MAIN.R
```

### 💻 Interactive Mode (RStudio)

This mode is designed for **inspection and interaction with outputs**. An RStudio session will be launched on port 8787. Modify the command acordignly if said port is busy.

```bash
docker run -d \
  --name mexclim-rstudio \
  -p 8787:8787 \
  -e DISABLE_AUTH=true \
  -v $(pwd)/Data:/home/rstudio/project/Data \
  -v $(pwd)/Results:/home/rstudio/project/Results \
  mexclim
```

Open in browser:

```
http://localhost:8787
```

### Permission issues (if encountered)

If you see a "Permission denied" error when writing outputs, run:

```bash
sudo chown -R $USER:$USER Data Results
```

### Reproducibility

This project guarantees reproducibility through:

- **Docker** → system dependencies and OS
- **renv** → exact R package versions (`renv.lock`)
- **Deterministic pipeline** → controlled script execution via `MAIN.R`

---

# Raw Data

The repository contains the raw data files needed to construct the main data set. Below, there is a brief description of the type of data and its source, along with the location of the files within the repository.

### Climate Data
- Source: Climate Research Unit (CRU), University of East Anglia (via World Bank)
- Coverage: 1901–2024  
- Location: `Data/Raw/Climate/`
 
### Inflation Data
- Source: INEGI (Consumer Price Index components)
- Location: `Data/Raw/Inflation/`

### Auxiliary Data
- Regional classification of Mexican states/cities
- Used to compute population-weighted regional aggregates  
- Location: `Data/Raw/Helpers/`

> IMPORTANT: Raw data may need to be manually provided depending on repository distribution.

---

#  Pipeline Overview

The pipeline is orchestrated by:

```
MAIN.R
```

## Preamble and Global Configuration

The file:

```
scripts/00_Preamble.R
```

is executed at the beginning of the pipeline and is central to reproducibility and consistency.

It performs the following tasks:

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

## Data construction

After cloning the repository, the raw data files are downloaded so you can construct the main data set from the beginning. Regardless, the main data set is still included in the repo. Although the raw climate data is also downloaded when cloning the repo, the pipeline still connects to the World Bank API and downloads the data. The macroeconomic data is only loaded on the scripts, there is no downloading step. 

The scripts that construct the main data set are those numbered "01" and "02" inside the `scripts/` directory:

- `01_Manage_Climate_Regions.R`
- `01_Manage_INPC_Regions.R`
- `01_Manage_ITAEE-GDP_Regions.R`
- `02_Merge_Macro-Climate-data_Regions.R`

The "01" scripts load the raw data from `Data/Raw` and will perform some data cleaning and preprocessing, for instance, seasonal adjustments, climate normal computations, climate anomalies construction, and further transformations (see section 3 of the paper for details on the variables used). The script "02" will load the preprocessed data, constructed in the "01" scripts, from the `Data/Preprocessed` directory and will merge all the macroeconomic and climate variables used in the study to construct the final data set, which will be stored directly on `Data/`.


## Descriptive & Econometric Analysis

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

# 📬 Contact

Lenin Arango-Castillo – larangoc@banxico.org.mx  
Francisco J. Martínez-Ramírez – franciscomr@banxico.org.mx  
