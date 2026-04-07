# Reproducible Pipeline for [Paper Title]

This repository provides a fully reproducible computational pipeline for the paper:

> **[Insert Paper Title Here]**

The workflow is containerized using Docker to ensure full reproducibility of the computational environment.

---

## 📦 Project Structure

```
.
├── MAIN.R
├── scripts/
├── Data/
│   ├── Raw/
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
  -v $(pwd):/home/rstudio/project \
  mexclim \
  Rscript MAIN.R
```

### Outputs

- Tables → `Results/Tables/`
- Figures → `Results/Figures/`
- Processed data → `Data/Preprocessed/`

---

## 💻 Interactive Mode (RStudio)

Launch an RStudio session:

```bash
docker rm -f mexclimacro-rstudio 2>/dev/null

docker run -d \
  --name mexclimacro-rstudio \
  -p 8787:8787 \
  -e PASSWORD=yourpassword \
  -v $(pwd):/home/rstudio/project \
  mexclim
```

Then open:

```
http://localhost:8787
```

### Login

- Username: `rstudio`
- Password: `yourpassword`

---

### ✅ Behavior (Important)

- RStudio **automatically opens in the project directory**
- No manual navigation required
- Files pane and working directory are correctly initialized
- This behavior is **baked into the Docker image**

---

### ⚠️ Note on Implementation

The working directory is configured via RStudio preferences inside the container, ensuring:

- Consistent behavior across systems
- No reliance on `.Rprofile`, environment variables, or manual setup
- Fully reproducible interactive sessions

---

## 🛑 Stopping the session

```bash
docker stop mexclimacro-rstudio
docker rm mexclimacro-rstudio
```

---

## 🔁 Reproducibility

This project ensures reproducibility via:

- **Docker** → system dependencies and OS
- **renv** → exact R package versions (`renv.lock`)
- **Structured pipeline** → deterministic execution

---

## 📂 Data

- `Data/Raw/`: input data (must be provided manually if not included)
- `Data/Preprocessed/`: generated during execution

---

## 🧠 Pipeline

`MAIN.R` orchestrates execution by calling scripts in `scripts/`.

Each script is:

- modular
- idempotent
- reproducible

---

## 📬 Contact

[Your Name]  
[Your Institution]  
[Your Email]
