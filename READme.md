# Reproducible Pipeline for *The Effect of Weather Effects on Inflation*

This repository provides a fully reproducible computational pipeline for the paper:

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
│   ├── 00_Preamble.R
│   ├── Functions/
│   ├── 01_*.R
│   ├── 02_*.R
│   ├── 10_*.R
│   ├── 11_*.R
│   └── 12_*.R
├── Data/
│   ├── Raw/
│   │   ├── Climate/
│   │   ├── Inflation/
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

## ⚙️ Requirements

- Docker (>= 20.x)

---

## 🚀 Setup

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/yourrepo.git
cd yourrepo
```

---

### 2. Build the Docker image

```bash
docker build -t mexclim .
```

---

## ▶️ Run the Full Pipeline (Batch Mode)

```bash
docker run --rm \
  -v $(pwd)/Data/Preprocessed:/home/rstudio/project/Data/Preprocessed \
  -v $(pwd)/Results/Tables:/home/rstudio/project/Results/Tables \
  -v $(pwd)/Results/Figures:/home/rstudio/project/Results/Figures \
  mexclim \
  Rscript MAIN.R
```

### Outputs

- Tables → `Results/Tables/`
- Figures → `Results/Figures/`
- Processed data → `Data/Preprocessed/`

---

## 📁 Output Directories (Important)

The following directories must exist locally for Docker volume mounting:

- `Data/Preprocessed/`
- `Results/Tables/`
- `Results/Figures/`

They can be created with:

```bash
mkdir -p Data/Preprocessed Results/Tables Results/Figures
```

---

## 💻 Interactive Mode (RStudio)

This mode is designed for **inspection and interaction with outputs**, without requiring the full repository to be mounted.

Only the directories that **store outputs and processed data** are mounted:

```bash
docker rm -f mexclimacro-rstudio 2>/dev/null

docker run -d \
  --name mexclimacro-rstudio \
  -p 8787:8787 \
  -e DISABLE_AUTH=true \
  -v $(pwd)/Data/Preprocessed:/home/rstudio/project/Data/Preprocessed \
  -v $(pwd)/Results/Tables:/home/rstudio/project/Results/Tables \
  -v $(pwd)/Results/Figures:/home/rstudio/project/Results/Figures \
  mexclim
```

Open in browser:

```
http://localhost:8787
```
---

### ✅ Behavior (Important)

- RStudio opens directly in the project directory inside the container
- Only **relevant output folders are mounted**
- Prevents accidental modification of source code
- Ideal for:
  - Exploring results
  - Exporting tables/figures
  - Running additional analysis on processed data

---

## 🔁 Reproducibility

This project guarantees reproducibility through:

- **Docker** → system dependencies and OS
- **renv** → exact R package versions (`renv.lock`)
- **Deterministic pipeline** → controlled script execution via `MAIN.R`

---

## 📂 Data

### Raw Data Sources

#### Climate Data
- Source: Climate Research Unit (CRU), University of East Anglia (via World Bank)
- Coverage: 1901–2024  
- Location:
  ```
  Data/Raw/Climate/
  ```

#### Inflation Data
- Source: INEGI (Consumer Price Index components)
- Location:
  ```
  Data/Raw/Inflation/
  ```

#### Auxiliary Data
- Regional classification of Mexican states/cities
- Used to compute population-weighted regional aggregates  
- Location:
  ```
  Data/Raw/Helpers/
  ```

> ⚠️ Raw data may need to be manually provided depending on repository distribution.

---

## 🧠 Pipeline Overview

The pipeline is orchestrated by:

```
MAIN.R
```

---

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

## 📬 Contact

Lenin Arango-Castillo – larangoc@banxico.org.mx  
Francisco J. Martínez-Ramírez – franciscomr@banxico.org.mx  
