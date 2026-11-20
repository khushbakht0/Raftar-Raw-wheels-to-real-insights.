import io
import os
import sys
import json
import time
import psycopg2
from clean_listings import clean

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL = os.path.join(ROOT, "sql")
CSV = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "data", "raw", "pakwheels_csv.zip")
DB = os.getenv("PGDATABASE", "raftar_dw")
CONN = dict(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"),
            user=os.getenv("PGUSER", "postgres"), password=os.getenv("PGPASSWORD", ""))

RAW_COLS = ["source_row_number", "ad_url", "title", "location", "model_year", "price", "mileage",
            "engine_type", "transmission", "registered_in", "color", "assembly", "engine_capacity",
            "body_type", "ad_last_updated"]
CLEAN_COLS = ["source_row_number", "source_listing_id", "title_clean", "make", "model", "variant", "model_year",
              "asking_price_pkr", "mileage_km", "fuel_type", "transmission", "body_type", "area", "city",
              "province", "last_updated_date", "vehicle_bk", "city_bk"]
CLEAN_COLS.insert(CLEAN_COLS.index("mileage_km") + 1, "engine_cc")
REJECT_COLS = ["source_row_number", "source_listing_id", "title_clean", "make", "city", "province",
               "reject_reason", "raw_price"]


def create_database():
    conn = psycopg2.connect(dbname="postgres", **CONN)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB,))
    if not cur.fetchone():
        cur.execute(f"CREATE DATABASE {DB}")
        print(f"created database {DB}")
    conn.close()


def run_sql(cur, name):
    with open(os.path.join(SQL, name), encoding="utf-8") as f:
        cur.execute(f.read())
    print(f"ran {name}")


def copy_df(cur, df, table, cols):
    buf = io.StringIO()
    df[cols].to_csv(buf, index=False, header=False, na_rep="")
    buf.seek(0)
    cur.copy_expert(f"COPY {table} ({', '.join(cols)}) FROM STDIN WITH (FORMAT csv, NULL '')", buf)
    print(f"loaded {len(df)} rows into {table}")


def main():
    t0 = time.time()
    create_database()
    raw, ok, rej, stats = clean(CSV)
    conn = psycopg2.connect(dbname=DB, **CONN)
    cur = conn.cursor()
    run_sql(cur, "00_create_schemas.sql")
    run_sql(cur, "01_staging_tables.sql")
    copy_df(cur, raw, "project_staging.raw_listings", RAW_COLS)
    copy_df(cur, ok, "project_staging.stg_listing_clean", CLEAN_COLS)
    copy_df(cur, rej, "project_staging.stg_listing_reject", REJECT_COLS)
    for name in ["02_dw_tables.sql", "03_load_dimensions.sql", "04_load_fact.sql",
                 "05_data_quality_checks.sql", "06_reporting_views.sql"]:
        run_sql(cur, name)
    conn.commit()

    cur.execute("SELECT category, check_name, expected, actual, status FROM project_reporting.dq_results ORDER BY check_id")
    rows = cur.fetchall()
    for tbl in ["project_staging.raw_listings", "project_staging.stg_listing_clean", "project_staging.stg_listing_reject",
                "project_dw.dim_date", "project_dw.dim_vehicle", "project_dw.dim_city", "project_dw.dim_source",
                "project_dw.fact_listing_observation"]:
        cur.execute(f"SELECT COUNT(*) FROM {tbl}")
        stats.setdefault("table_counts", {})[tbl] = cur.fetchone()[0]
    conn.close()

    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    with open(os.path.join(ROOT, "docs", "pipeline_results.json"), "w") as f:
        json.dump({"stats": stats, "dq": [list(map(str, r)) for r in rows]}, f, indent=1, default=str)
    passed = sum(1 for r in rows if r[4] == "PASS")
    failed = sum(1 for r in rows if r[4] == "FAIL")
    info = sum(1 for r in rows if r[4] == "INFO")
    print(f"DQ: {passed} pass, {failed} fail, {info} info | done in {time.time() - t0:.1f}s")
    for r in rows:
        if r[4] == "FAIL":
            print("FAIL:", r)


if __name__ == "__main__":
    main()
