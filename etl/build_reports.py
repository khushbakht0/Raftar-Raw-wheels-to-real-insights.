import os
import json
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "docs", "pipeline_results.json")))
S, DQ = res["stats"], res["dq"]
TC = S["table_counts"]

ss = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=ss["Heading1"], fontSize=17, textColor=colors.HexColor("#0b3d5c"), spaceAfter=4)
H2 = ParagraphStyle("H2", parent=ss["Heading2"], fontSize=12, textColor=colors.HexColor("#0b3d5c"), spaceBefore=10, spaceAfter=4)
B = ParagraphStyle("B", parent=ss["BodyText"], fontSize=9, leading=12)
SM = ParagraphStyle("SM", parent=B, fontSize=8, leading=10)
HD = ParagraphStyle("HD", parent=SM, textColor=colors.white, fontName="Helvetica-Bold")
TEAM = "Team: Rafia Mohsin (24L-2595) | Khushbakht Sohail (24L-2604) | Ayesha Farooqui (24L-2520)"


def n(x):
    return f"{int(x):,}"


def table(rows, widths, header=True, zebra=True):
    data = []
    for i, r in enumerate(rows):
        data.append([Paragraph(str(c), HD if (header and i == 0) else SM) for c in r])
    t = Table(data, colWidths=[w * cm for w in widths], repeatRows=1 if header else 0)
    st = [("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#b8c4cc")), ("VALIGN", (0, 0), (-1, -1), "TOP"),
          ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4)]
    if header:
        st.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0b3d5c")))
    if zebra:
        for i in range(1, len(rows)):
            if i % 2 == 0:
                st.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#f1f5f8")))
    t.setStyle(TableStyle(st))
    return t


def footer(c, d):
    c.saveState()
    c.setFont("Helvetica", 7.5)
    c.setFillColor(colors.grey)
    c.drawString(1.8 * cm, 1.1 * cm, "RAFTAR | DL3004 DWBI Final Project | Phase 2")
    c.drawRightString(A4[0] - 1.8 * cm, 1.1 * cm, f"Page {d.page}")
    c.restoreState()


def build(path, story):
    SimpleDocTemplate(path, pagesize=A4, leftMargin=1.8 * cm, rightMargin=1.8 * cm, topMargin=1.6 * cm,
                      bottomMargin=1.8 * cm).build(story, onFirstPage=footer, onLaterPages=footer)


def head(title, sub):
    return [Paragraph(f"RAFTAR | {title}", H1), Paragraph(sub, B), Paragraph(TEAM, SM), Spacer(1, 6)]


rej = S["rejected"]
raw_n, clean_n, rej_n = S["raw_rows"], S["clean_rows"], S["rejected_total"]

# ---------- Cleaning report ----------
c = head("Phase 2 Data Cleaning Report", "DL3004 | DWBI Final Project | Physical Data Warehouse Implementation and ETL Pipeline")
c.append(Paragraph("1. Source data", H2))
c.append(Paragraph(
    f"Real data: the PakWheels used-car listings CSV from Kaggle (October 2022 scrape), {n(raw_n)} rows and 17 columns. "
    "No synthetic data and no economic (CPI) data is used in this phase. All prices are advertised asking prices, never confirmed sale prices. "
    "The <b>description</b> and <b>car_features</b> columns are not loaded anywhere because descriptions can contain phone numbers "
    "(Phase 1 privacy rule). <b>color</b>, <b>assembly</b> and <b>registered_in</b> are kept in raw staging only; they are not in the Phase 1 star schema.", B))
c.append(Paragraph("2. Pipeline flow", H2))
c.append(table([
    ["Step", "What happens", "Tool"],
    ["1 Raw staging", f"CSV copied as-is into project_staging.raw_listings ({n(TC['project_staging.raw_listings'])} rows, all text columns)", "Python COPY"],
    ["2 Cleaning", "Trim and standardize text, parse price / mileage / engine / date, split title into make-model-variant and location into city-province, set NULL handling, flag rejects", "Python (pandas)"],
    ["3 Clean staging", f"Valid rows to stg_listing_clean ({n(clean_n)}), rejected rows with reason to stg_listing_reject ({n(rej_n)})", "Python COPY"],
    ["4 Dimensions", "INSERT ... SELECT DISTINCT into dim_vehicle, dim_city; dim_date from generate_series; dim_source one row; Unknown member (key -1) in each", "SQL"],
    ["5 Fact", "JOIN clean staging to dimensions on business keys, insert the surrogate keys into fact_listing_observation", "SQL"],
    ["6 Quality checks", f"{len(DQ)} SQL checks write to project_reporting.dq_results", "SQL"],
], [3, 11.2, 3]))
c.append(Paragraph("3. Row flow", H2))
c.append(table([
    ["Stage", "Rows", "Note"],
    ["Raw CSV rows", n(raw_n), "all rows loaded unchanged (except the two dropped columns)"],
    ["Rejected, NO_PRICE", n(rej.get("NO_PRICE", 0)), f"{n(S['price_call_for_price'])} 'Call for price' + {S['price_null']} fully empty rows (the 2 empty rows have no price and no ad id)"],
    ["Rejected, DUPLICATE_ID", n(rej.get("DUPLICATE_ID", 0)), "same ad id as an earlier row (checked before price)"],
    ["Rejected, INVALID_PRICE", n(rej.get("INVALID_PRICE", 0)), "price outside PKR 50,000 to 500,000,000"],
    ["Clean rows", n(clean_n), f"{raw_n:,} - {rej_n:,}"],
    ["Fact rows", n(TC["project_dw.fact_listing_observation"]), "one fact row per clean listing"],
], [4.5, 2.5, 10.2]))
c.append(Paragraph(
    f"Duplicate handling follows the Phase 1 rule: only the source ad id counts. The ad id is the number at the end of ad_url. "
    f"{n(S['possible_content_duplicates'])} clean rows look like repeats (same title, area, city, year, price, mileage, engine, fuel, transmission) "
    "but have different ad ids, so they are kept and reported as informational only, because two sellers can post identical ads.", B))

c.append(Paragraph("4. Cleaning rules and real before / after examples", H2))
ex = S["examples"]
loc_ex = "<br/>".join(f"'{a}' becomes {b}" for a, b in ex["location"][:3])
pr_ex = "<br/>".join(f"'{a}' becomes {b:,}" for a, b in ex["price"][:3] if b)
ti_ex = "<br/>".join(f"'{a}' becomes '{b}'" for a, b in ex["title"][:2])
rules = [
    ["Rule", "Before / after", "Rows affected"],
    ["Standardize text (trim, collapse spaces, consistent case)", loc_ex, f"location {n(S['whitespace_fixed_location'])}, title {n(S['whitespace_fixed_title'])}"],
    ["Split location into city and province (last part of the text)", "'DHA Defence, Lahore Punjab' gives city Lahore, province Punjab. KPK becomes Khyber Pakhtunkhwa, Islamabad becomes Islamabad Capital Territory, Northern Areas becomes Gilgit-Baltistan", f"{S['distinct_city_bk']} distinct city/province pairs; {S['province_unknown']} rows with unknown province"],
    ["Parse price text to a number", pr_ex + "<br/>'Call for price' becomes NULL and is rejected", f"lacs {n(S['price_lacs'])}, crore {n(S['price_crore'])}, plain PKR {S['price_plain_pkr']}, call for price {n(S['price_call_for_price'])}"],
    ["Parse mileage ('100,000 km' to 100000)", "digits only; values above 1,000,000 km would become NULL", f"{n(S['mileage_over_max'])} out of range; {n(S['mileage_under_100'])} raw values under 100 km are kept and reported (likely placeholders such as '1 km')"],
    ["Engine capacity: cc to number, kWh rows are electric", "'1300 cc' becomes 1300; '40.0 kWh' gives engine_cc NULL and fuel Electric. cc outside 500 to 8000 becomes NULL", f"kWh rows {S['engine_kwh_rows']}; cc out of range {S['engine_cc_out_of_range']}"],
    ["Split title into make / model / variant", ti_ex + "<br/>'Suzuki Wagon R VXL 2018' gives make Suzuki, model Wagon R, variant VXL", f"suffix ' for sale in ...' removed from {S['title_suffix_removed']} titles"],
    ["Model year to integer, validity 1950 to 2022", "'2007.0' becomes 2007", f"{n(S['model_year_out_of_range'])} out of range"],
    ["Date text to date", "'Oct 09, 2022' becomes 2022-10-09 (ad_last_updated)", f"{S['last_updated_null']} NULL"],
    ["Business keys for the DW", "vehicle_bk = make|model|year|variant|body|cc|fuel|transmission; city_bk = city|province. Used to join staging to dimensions", f"{n(S['distinct_vehicle_bk'])} vehicle keys, {S['distinct_city_bk']} city keys"],
]
c.append(table(rules, [4.6, 8.2, 4.4]))
c.append(Paragraph("5. NULL handling", H2))
c.append(table([
    ["Column", "Missing in raw", "Handling"],
    ["price", n(S["price_null"] + S["price_call_for_price"]), "row rejected (no price means no measure)"],
    ["model_year", n(S["model_year_null"]), "kept as NULL in dim_vehicle (not guessed)"],
    ["engine_type (fuel)", n(S["fuel_null_before"]), "'Unknown' (electric rows from kWh are set to Electric first)"],
    ["body_type", n(S["body_type_null"]), "'Unknown'"],
    ["transmission", n(S["transmission_null"]), "'Unknown' (only the empty rows)"],
    ["location", n(S["location_null"]), "city and province 'Unknown' (only the empty rows)"],
    ["ad_last_updated", n(S["last_updated_null"]), "date key -1 (Unknown member)"],
], [4, 3, 10.2]))
c.append(Paragraph("6. Assumptions and limits (please read before the viva)", H2))
for t in [
    "make and model are taken from the title: the first word is the make (Mercedes Benz, Land Rover, Alfa Romeo handled) and the next word is the model, with a short list of two-word models (Wagon R, Land Cruiser, C Class and similar). Everything after the model is the variant, so some models such as 'Corolla Axio' appear as Corolla + variant Axio.",
    "ad_last_updated is the date the ad was last updated, not the date the car was posted or captured. observation_date_key is therefore Unknown (-1), as the Phase 1 single-extract rule says. Almost all dates fall in Aug to Oct 2022.",
    "extract_date_key is 2022-10-10, taken from the timestamp of pakwheels.csv inside the zip file and consistent with the latest ad_last_updated. Please confirm it against the Kaggle dataset page.",
    "Electric is inferred from a kWh engine value (134 rows before rejects). A few of these may be plug-in hybrids (for example the BMW i8) because the source gives no fuel type for them.",
    "No CPI or any other economic data is loaded, so Fact_EconomicIndicator, Dim_EconomicIndicator, Dim_Geography and Q10 are not implemented (see the Data Quality Report).",
]:
    c.append(Paragraph("&bull; " + t, B))
build(os.path.join(ROOT, "reports", "Raftar_Phase2_Data_Cleaning_Report.pdf"), c)

# ---------- Quality report ----------
passed = sum(1 for r in DQ if r[4] == "PASS")
failed = sum(1 for r in DQ if r[4] == "FAIL")
info = sum(1 for r in DQ if r[4] == "INFO")
q = head("Phase 2 Data Quality Report", "DL3004 | DWBI Final Project | Physical Data Warehouse Implementation and ETL Pipeline")
q.append(Paragraph("1. Summary", H2))
q.append(Paragraph(
    f"{len(DQ)} SQL checks were run on the loaded PostgreSQL warehouse using the real PakWheels data: "
    f"<b>{passed} passed, {failed} failed, {info} informational</b>. Informational checks are counts we report but do not treat as errors (missing values that are real gaps in the source). "
    "Everything is stored in project_reporting.dq_results and can be re-run with sql/05_data_quality_checks.sql.", B))
cats = {}
for r in DQ:
    d = cats.setdefault(r[0], [0, 0, 0, 0])
    d[0] += 1
    d[{"PASS": 1, "FAIL": 2, "INFO": 3}[r[4]]] += 1
q.append(Spacer(1, 4))
q.append(table([["Category", "Checks", "Pass", "Fail", "Info"]] + [[k, v[0], v[1], v[2], v[3]] for k, v in cats.items()], [5, 2.5, 2.5, 2.5, 2.5]))
q.append(Paragraph("2. Warehouse row counts", H2))
q.append(table([["Table", "Rows"]] + [[k, n(v)] for k, v in TC.items()], [9, 4]))
q.append(Paragraph(
    "The brief asks for 100+ dimension records and 10,000+ fact records: dim_vehicle, dim_city and dim_date all exceed 100 and the fact table has "
    f"{n(TC['project_dw.fact_listing_observation'])} rows.", B))
q.append(Paragraph("3. Star schema as implemented (project_dw)", H2))
q.append(table([
    ["Table", "Surrogate key", "Business key / notes"],
    ["fact_listing_observation", "listing_observation_key (SERIAL)", "source_listing_id (ad id, unique); FKs vehicle_key, city_key, source_key, observation_date_key, extract_date_key, last_updated_date_key; measures asking_price_pkr, mileage_km, listing_count = 1"],
    ["dim_vehicle", "vehicle_key (SERIAL)", "vehicle_bk; make, model, model_year, variant, body_type, engine_cc, fuel_type, transmission"],
    ["dim_city", "city_key (SERIAL)", "city_bk; city_name, province (Province > City)"],
    ["dim_source", "source_key (SERIAL)", "source_name; source_url, access_method, terms_notes"],
    ["dim_date", "date_key (YYYYMMDD)", "full_date; day, month, month_name, quarter, year; 2020-01-01 to 2023-12-31"],
], [4, 4, 9.2]))
q.append(Paragraph("Every dimension has an explicit Unknown member with key -1. The fact load maps business keys to surrogate keys by joining staging to the dimensions (sql/04_load_fact.sql). Primary keys, foreign keys and CHECK constraints are defined in sql/02_dw_tables.sql.", B))
q.append(Paragraph("4. All check results", H2))
cols = {"PASS": "#1b7f3b", "FAIL": "#b00020", "INFO": "#8a6d00"}
rows = [["#", "Category", "Check", "Expected", "Actual", "Status"]]
for i, r in enumerate(DQ, 1):
    rows.append([i, r[0], r[1], r[2], n(float(r[3])), f"<font color='{cols[r[4]]}'><b>{r[4]}</b></font>"])
q.append(table(rows, [0.8, 2.5, 8, 2.3, 2, 1.4]))
q.append(Paragraph("5. What the informational counts mean", H2))
for t in [
    "Missing model year, body type, fuel and engine cc are real gaps in the source. They are kept as NULL or 'Unknown' and are not guessed, so Q2 and Q5 only use rows where the needed attribute is present.",
    "Mileage under 100 km: many ads show '1 km'. These are probably placeholders for 'not entered', but they are kept and shown as their own band in Q3 because the source does not prove they are wrong.",
    "Possible repeat ads: rows with identical vehicle, city, price and mileage but different ad ids. Phase 1 allows removal only by source id, so they stay in the fact.",
    "No row is lost: raw rows = clean rows + rejected rows, and clean rows = fact rows (both reconciliation checks pass). The price control total in staging equals the fact total (this is a control total of asking prices, not revenue).",
]:
    q.append(Paragraph("&bull; " + t, B))
q.append(Paragraph("6. Reporting views for the Phase 1 questions", H2))
q.append(table([
    ["Question", "View (project_reporting)", "Note"],
    ["Q1 price by make and model", "vw_q1_price_by_make_model", "median, min, max, listings"],
    ["Q2 median by model year within a model", "vw_q2_price_by_model_year", "groups with 10+ listings"],
    ["Q3 price by mileage band", "vw_q3_price_by_mileage_band", "10+ listings per group"],
    ["Q4 median price by city for the same model", "vw_q4_price_by_city", "10+ listings per group"],
    ["Q5 transmission / fuel within make-model-year", "vw_q5_price_by_transmission_fuel", "5+ listings per group"],
    ["Q6 share of listings per price band", "vw_q6_price_band_share", "pct of all fact rows"],
    ["Q7 segments with most listings", "vw_q7_listings_by_segment", "body type, fuel, transmission"],
    ["Q8 missing / invalid attributes", "vw_q8_quality_by_make, vw_q8_quality_by_city", "includes rejected rows"],
    ["Q9 price by period", "vw_q9_price_by_last_updated_month", "last-updated date; over 99.9% of rows are in Aug to Oct 2022, so only 3 months are meaningful"],
    ["Q10 listing prices vs CPI", "not implemented", "needs real PBS CPI data, which is not part of this submission"],
], [5.2, 6, 6]))
q.append(Paragraph("7. Differences from the Phase 1 design", H2))
for t in [
    "Fact key is named listing_observation_key (the data dictionary says ListingSnapshotKey, which does not match the other Phase 1 documents).",
    "asking_price_pkr is NOT NULL because rows without a valid price are rejected.",
    "A column last_updated_date_key was added to the fact, because the source has a real per-row 'ad last updated' date that is not an observation date. observation_date_key stays Unknown (-1) and extract_date_key is 2022-10-10.",
    "ListingURL is not stored; the numeric ad id (source_listing_id) is kept instead. load_date records the ETL load day.",
    "Fact_EconomicIndicator, Dim_EconomicIndicator and Dim_Geography are not built, so Q10 is not answered. No fake or estimated CPI was used. They can be added later by loading the real PBS monthly CPI series.",
]:
    q.append(Paragraph("&bull; " + t, B))
build(os.path.join(ROOT, "reports", "Raftar_Phase2_Data_Quality_Report.pdf"), q)
print("reports built")
