# House Price MLOps — Ames

Production-oriented MLOps project built from the Kaggle Ames House Prices dataset.

## Documentation

The documentation is intentionally split into two parts so that **data/ML reasoning** is not mixed with **software/MLOps engineering**:

1. `docs/01-data-science-journey.md` — dataset understanding, missing values, data-quality checks, EDA, outliers, feature engineering, train/validation design, model comparison, and final modeling decisions.
2. `docs/02-mlops-engineering-journey.md` — extraction of the notebook into `src/`, tests, coverage, FastAPI, logging/correlation IDs, serialization, Docker, Docker Hub, Git/GitHub workflow, bugs and fixes, and final Module 1 status.
3. `reports/module-1.md` — concise Module 1 evidence/report with measured results and remaining evidence items.

## Quick Start

```powershell
uv sync
uv run pytest tests/ --cov=house_price_mlops --cov-fail-under=70
docker compose up --build
```

API docs: `http://localhost:8000/docs`

## Published Image

`m0hamedseleem/house-price-mlops:latest`
