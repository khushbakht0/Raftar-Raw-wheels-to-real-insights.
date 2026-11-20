# Raftar 
Physical data warehouse + ETL on the **real PakWheels used-car listings CSV** (Kaggle, Oct 2022, 89,956 rows).
Team: Rafia Mohsin (24L-2595) | Khushbakht Sohail (24L-2604) | Ayesha Farooqui (24L-2520)

Prices are asking prices, not sales. No CPI / economic data is used (see "Not included").

```
pakwheels_csv.zip -> project_staging (raw, clean, reject) -> project_dw (star schema) -> project_reporting (views, dq_results)
```

## Run (Windows PowerShell)
```powershell
pip install -r requirements.txt
$env:PGHOST="localhost"; $env:PGPORT="5432"; $env:PGUSER="postgres"; $env:PGPASSWORD="<your password>"; $env:PGDATABASE="raftar_dw"
python etl/run_pipeline.py      # creates DB, schemas, loads, cleans, builds dims + fact, runs quality checks
python etl/build_reports.py     # rebuilds the two PDFs in reports/
```
Full refresh on every run (tables are dropped / truncated and reloaded), so it is safe to re-run.
The input is `data/raw/pakwheels_csv.zip`; pass another path as the first argument to use a different file.

## Deliverable map
| Phase 2 deliverable | File |
|---|---|
| PostgreSQL database SQL scripts | `sql/00_create_schemas.sql` (database is created in `etl/run_pipeline.py`) |
| Staging schema SQL | `sql/01_staging_tables.sql` |
| DW schema SQL | `sql/02_dw_tables.sql` |
| ETL scripts (Python + SQL) | `etl/clean_listings.py` (pandas cleaning), `etl/run_pipeline.py` (orchestration) |
| Dimension load scripts | `sql/03_load_dimensions.sql` |
| Fact load scripts | `sql/04_load_fact.sql` |
| Data quality checks | `sql/05_data_quality_checks.sql` (48 checks into `project_reporting.dq_results`) |
| Reporting views Q1-Q9 | `sql/06_reporting_views.sql` |
| Data Cleaning Report PDF | `reports/Raftar_Phase2_Data_Cleaning_Report.pdf` |
| Data Quality Report PDF | `reports/Raftar_Phase2_Data_Quality_Report.pdf` |

## Design notes
* Surrogate keys: `SERIAL` on every dimension (`dim_date` uses YYYYMMDD), Unknown member = key `-1`. Fact load joins clean staging to the dimensions on business keys (`vehicle_bk`, `city_bk`, `full_date`).
* Grain: one advertisement per source extract, unique on `source_listing_id` (ad id from the URL).
* Single extract: `observation_date_key = -1` (Unknown), `extract_date_key = 20221010`, and the source's real "ad last updated" date is in `last_updated_date_key` (added column).



## How to run (Windows CMD)

1. Install PostgreSQL and Python 3.12
2. `pip install -r requirements.txt`
3. `set PGPASSWORD=<your_postgres_password>`
4. `python etl\run_pipeline.py`
   Creates DB `raftar_dw`, runs all SQL scripts in order, loads data, runs DQ checks.
5. Expected: `DQ: 38 pass, 0 fail`

## Extra validation
- `sql/08_surrogate_key_validation.sql`: orphans, duplicate business keys and fact→dim mapping (all results must be 0)
- `sql/07_normalization_view.sql`: vehicle dimension fragmentation analysis
- `etl/schema_drift_check.py`: detects added, removed or changed columns in the source CSV and DW tables (run once for a baseline, again after changes)
* Differences from the Phase 1 dictionary: `listing_observation_key` name, `asking_price_pkr NOT NULL`, no `ListingURL`, extra `last_updated_date_key`.

## Not included
`Fact_EconomicIndicator`, `Dim_EconomicIndicator`, `Dim_Geography` and Q10: they need the real PBS monthly CPI series, which was not available. Nothing is simulated.
