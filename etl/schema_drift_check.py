import json, os, sys, zipfile
import pandas as pd, psycopg2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP = os.path.join(ROOT, "data", "raw", "pakwheels_csv.zip")
BASE = os.path.join(ROOT, "etl", "schema_baseline.json")

def csv_cols():
    with zipfile.ZipFile(ZIP) as z:
        n = next(x for x in z.namelist() if x.lower().endswith(".csv"))
        with z.open(n) as f:
            return list(pd.read_csv(f, nrows=0, encoding_errors="replace").columns)

def dw_cols():
    c = psycopg2.connect(dbname=os.getenv("PGDATABASE", "raftar_dw"),
        host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"),
        user=os.getenv("PGUSER", "postgres"), password=os.getenv("PGPASSWORD", ""))
    cur = c.cursor()
    cur.execute("""SELECT table_name, column_name, data_type FROM information_schema.columns
                   WHERE table_schema='project_dw' ORDER BY table_name, ordinal_position""")
    out = {}
    for t, col, dt in cur.fetchall():
        out.setdefault(t, []).append(f"{col}:{dt}")
    c.close()
    return out

now = {"csv": csv_cols(), "dw": dw_cols()}
if not os.path.exists(BASE):
    json.dump(now, open(BASE, "w"), indent=1)
    print("Baseline saved. Run again after any change.")
    sys.exit(0)

old, drift = json.load(open(BASE)), False
o, n = old["csv"], now["csv"]
if set(o) != set(n) or o != n:
    drift = True
    print("CSV drift | added:", sorted(set(n) - set(o)), "| removed:", sorted(set(o) - set(n)),
          "| reordered:", set(o) == set(n) and o != n)
for t in sorted(set(old["dw"]) | set(now["dw"])):
    if old["dw"].get(t) != now["dw"].get(t):
        drift = True
        print(f"DW drift in {t}:", old["dw"].get(t), "->", now["dw"].get(t))
print("DRIFT DETECTED" if drift else "No drift")
sys.exit(1 if drift else 0)