# Pipeline for *The effects of temperature and rainfall anomalies on macroeconomic variables: The case of Mexico*

This repository provides a fully reproducible computational pipeline for the [paper](https://arxiv.org/pdf/2507.14420):

> **The Effect of Weather Effects on Inflation**  
> Lenin Arango-Castillo (Bank of Mexico)  
> Francisco J. Martínez-Ramírez (Bank of Mexico)

This project combines **climate data and inflation data** to estimate the impact of weather shocks on inflation using econometric techniques such as **Local Projections (LP)** and **panel ARDL models**.

The workflow is fully containerized using **Docker** and uses **`renv`** to guarantee reproducibility of the R environment.

---

## 📦 Project Structure

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

# 🚀 Setup

## 1. Clone the repository

```bash
git clone https://github.com/Franciscojmara/Mex-ClimMacro
cd Mex-ClimMacro
```

### 📁 Outputs

Inside the image, the pipeline will generate `.xlsx`, `.csv`, `.tex`, and `.pdf` files that will be exported into the following directories.

- Tables → `Results/Tables/`
- Figures → `Results/Figures/`
- Processed data → `Data/Preprocessed/`

The directories must also exist locally for Docker volume mounting, that is, to get the paper results locally and not only inside the container. They can be created with:

```bash
mkdir -p Data/Preprocessed Results/Tables Results/Figures
```

## 2. Build the Docker image

```bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t mexclim .
```

Using the ---build-arg, ensures that the container has the permissions to write files in the host machine (only if mounting directories). The files that the programs will export are the paper's tables and figures.

#### ⚠️ Important caveat
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

This mode is designed for **inspection and interaction with outputs**. An RStudio session will be opened on port 8787. Modify the command acordignly if said port is busy.

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

#### ✅ Behavior (Important)

- RStudio opens directly in the project directory inside the container
- Only **relevant output folders are mounted**
- Prevents accidental modification of source code
- Ideal for:
  - Exploring results
  - Exporting tables/figures
  - Running additional analysis on processed data

#### 🔁 Reproducibility

This project guarantees reproducibility through:

- **Docker** → system dependencies and OS
- **renv** → exact R package versions (`renv.lock`)
- **Deterministic pipeline** → controlled script execution via `MAIN.R`

### ⚠️ Permission issues (if encountered)

If you see a "Permission denied" error when writing outputs, run:

```bash
sudo chown -R $USER:$USER Data Results
```

---

# 📂 Data

### Climate Data
- Source: Climate Research Unit (CRU), University of East Anglia (via World Bank)
- Coverage: 1901–2024  
- Location:
  ```
  Data/Raw/Climate/
  ```

### Inflation Data
- Source: INEGI (Consumer Price Index components)
- Location:
  ```
  Data/Raw/Inflation/
  ```

### Auxiliary Data
- Regional classification of Mexican states/cities
- Used to compute population-weighted regional aggregates  
- Location:
  ```
  Data/Raw/Helpers/
  ```

> ⚠️ Raw data may need to be manually provided depending on repository distribution.

---

# 🧠 Pipeline Overview

The pipeline is orchestrated by:

```
MAIN.R
```

## ⚙️ Preamble and Global Configuration

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

## 📊 Econometric Analysis

Main scripts:

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
