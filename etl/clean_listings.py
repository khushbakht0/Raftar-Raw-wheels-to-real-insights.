import re
import json
import pandas as pd

KNOWN_PROVINCES = [
    ("Federally Administered Tribal Areas", "FATA"),
    ("Northern Areas", "Gilgit-Baltistan"),
    ("Azad Kashmir", "Azad Kashmir"),
    ("Balochistan", "Balochistan"),
    ("Punjab", "Punjab"),
    ("Sindh", "Sindh"),
    ("KPK", "Khyber Pakhtunkhwa"),
    ("Islamabad", "Islamabad Capital Territory"),
]
TWO_WORD_MODELS = {("Wagon", "R"), ("Land", "Cruiser"), ("Ek", "Wagon"), ("Ek", "Space"),
                   ("N", "Wgn"), ("N", "Box"), ("N", "One"), ("N", "Wagon"), ("C", "Class"), ("E", "Class"), ("S", "Class"), ("A", "Class"), ("Range", "Rover")}
MIN_PRICE, MAX_PRICE = 50_000, 500_000_000
MIN_CC, MAX_CC = 500, 8000
MIN_YEAR, MAX_YEAR = 1950, 2022
MAX_MILEAGE = 1_000_000


def squash(s):
    return re.sub(r"\s+", " ", s).strip() if isinstance(s, str) else s


def parse_price(p):
    if not isinstance(p, str):
        return None
    m = re.search(r"([\d.,]+)", p)
    if not m or "call" in p.lower():
        return None
    n = float(m.group(1).replace(",", ""))
    if "crore" in p.lower():
        return round(n * 10_000_000)
    if "lac" in p.lower():
        return round(n * 100_000)
    return round(n)


def parse_title(t):
    t = squash(re.sub(r"\s+for sale in.*$", "", t if isinstance(t, str) else ""))
    yr = re.search(r"\b(19|20)\d{2}$", t)
    body = t[: yr.start()].strip() if yr else t
    w = body.split()
    if not w:
        return t, None, None, None
    if body.startswith("Alfa Romeo"):
        make, w = "Alfa Romeo", w[2:]
    elif body.startswith("Mercedes Benz"):
        make, w = "Mercedes-Benz", w[2:]
    elif body.startswith("Land Rover"):
        make, w = "Land Rover", w[2:]
    elif body.startswith("Range Rover"):
        make = "Land Rover"
    else:
        make, w = w[0], w[1:]
    if not w:
        return t, make, "Unknown", "Unspecified"
    if len(w) > 1 and (w[0], w[1]) in TWO_WORD_MODELS:
        model, rest = w[0] + " " + w[1], w[2:]
    else:
        model, rest = w[0], w[1:]
    return t, make, model, " ".join(rest) or "Unspecified"


def parse_location(loc):
    if not isinstance(loc, str) or not loc.strip():
        return None, "Unknown", "Unknown"
    s = squash(loc)
    area = s.rsplit(",", 1)[0].strip() if "," in s else None
    seg = s.rsplit(",", 1)[-1].strip()
    for raw, prov in KNOWN_PROVINCES:
        if seg == raw or seg.endswith(" " + raw):
            city = seg[: -len(raw)].strip() or raw
            city = re.sub(r"\s+A\.?K\.?$", "", city, flags=re.I)
            return area, city.title(), prov
    city = "Unknown" if seg.lower() == "other" else seg.title()
    return area, city, "Unknown"


def clean(raw_path):
    raw = pd.read_csv(raw_path, dtype=str)
    raw = raw.rename(columns={"Unnamed: 0": "source_row_number"})
    raw["source_row_number"] = raw["source_row_number"].astype(int)
    stats = {"raw_rows": len(raw)}

    for c in ["title", "location", "price", "mileage", "engine_type", "transmission", "engine_capacity", "body_type"]:
        s = raw[c].dropna()
        stats[f"whitespace_fixed_{c}"] = int((s != s.map(squash)).sum())

    df = pd.DataFrame({"source_row_number": raw["source_row_number"]})
    df["source_listing_id"] = raw["ad_url"].str.extract(r"-(\d+)$")[0]
    parsed = raw["title"].map(parse_title)
    df["title_clean"] = parsed.str[0]
    df["make"] = parsed.str[1]
    df["model"] = parsed.str[2]
    df["variant"] = parsed.str[3]
    stats["title_suffix_removed"] = int(raw["title"].fillna("").str.contains(r"\sfor sale in").sum())

    yr = pd.to_numeric(raw["model_year"], errors="coerce")
    stats["model_year_null"] = int(yr.isna().sum())
    stats["model_year_out_of_range"] = int(((yr < MIN_YEAR) | (yr > MAX_YEAR)).sum())
    df["model_year"] = yr.where((yr >= MIN_YEAR) & (yr <= MAX_YEAR)).astype("Int64")

    pr = raw["price"].map(parse_price)
    stats["price_lacs"] = int(raw["price"].fillna("").str.contains("lac").sum())
    stats["price_crore"] = int(raw["price"].fillna("").str.contains("crore").sum())
    stats["price_plain_pkr"] = int(raw["price"].fillna("").str.match(r"^PKR [\d,]+$").sum())
    stats["price_call_for_price"] = int(raw["price"].fillna("").str.contains("Call").sum())
    stats["price_null"] = int(raw["price"].isna().sum())
    df["asking_price_pkr"] = pr

    mil = pd.to_numeric(raw["mileage"].str.replace(r"[^\d]", "", regex=True), errors="coerce")
    stats["mileage_null"] = int(mil.isna().sum())
    stats["mileage_over_max"] = int((mil > MAX_MILEAGE).sum())
    stats["mileage_under_100"] = int((mil < 100).sum())
    df["mileage_km"] = mil.where(mil <= MAX_MILEAGE).astype("Int64")

    cap = raw["engine_capacity"].fillna("")
    is_kwh = cap.str.contains("kWh", case=False)
    cc = pd.to_numeric(cap.where(~is_kwh, "").str.replace(r"[^\d]", "", regex=True), errors="coerce")
    stats["engine_kwh_rows"] = int(is_kwh.sum())
    stats["engine_cc_out_of_range"] = int(((cc < MIN_CC) | (cc > MAX_CC)).sum())
    stats["engine_cc_null"] = int(cc.isna().sum() - is_kwh.sum())
    df["engine_cc"] = cc.where((cc >= MIN_CC) & (cc <= MAX_CC)).astype("Int64")

    fuel = raw["engine_type"].map(squash).str.title()
    stats["fuel_null_before"] = int(fuel.isna().sum())
    fuel = fuel.where(~is_kwh, "Electric")
    df["fuel_type"] = fuel.fillna("Unknown")

    df["transmission"] = raw["transmission"].map(squash).str.title().fillna("Unknown")
    df["body_type"] = raw["body_type"].map(squash).fillna("Unknown")
    stats["transmission_null"] = int(raw["transmission"].isna().sum())
    stats["body_type_null"] = int(raw["body_type"].isna().sum())

    loc = raw["location"].map(parse_location)
    df["area"] = loc.str[0]
    df["city"] = loc.str[1]
    df["province"] = loc.str[2]
    stats["location_null"] = int(raw["location"].isna().sum())
    stats["province_unknown"] = int((df["province"] == "Unknown").sum())

    dt = pd.to_datetime(raw["ad_last_updated"], format="%b %d, %Y", errors="coerce")
    stats["last_updated_null"] = int(dt.isna().sum())
    df["last_updated_date"] = dt.dt.date

    yr_txt = df["model_year"].astype("string").fillna("NA")
    cc_txt = df["engine_cc"].astype("string").fillna("NA")
    df["vehicle_bk"] = (df["make"].fillna("Unknown") + "|" + df["model"].fillna("Unknown") + "|" + yr_txt + "|"
                        + df["variant"].fillna("Unspecified") + "|" + df["body_type"] + "|" + cc_txt + "|"
                        + df["fuel_type"] + "|" + df["transmission"])
    df["city_bk"] = df["city"] + "|" + df["province"]

    df["reject_reason"] = None
    dup = df["source_listing_id"].duplicated(keep="first") & df["source_listing_id"].notna()
    df.loc[dup, "reject_reason"] = "DUPLICATE_ID"
    nop = df["reject_reason"].isna() & df["asking_price_pkr"].isna()
    df.loc[nop, "reject_reason"] = "NO_PRICE"
    bad = df["reject_reason"].isna() & ((df["asking_price_pkr"] < MIN_PRICE) | (df["asking_price_pkr"] > MAX_PRICE))
    df.loc[bad, "reject_reason"] = "INVALID_PRICE"
    noid = df["reject_reason"].isna() & df["source_listing_id"].isna()
    df.loc[noid, "reject_reason"] = "NO_SOURCE_ID"
    stats["rejected"] = df["reject_reason"].value_counts().to_dict()
    stats["rejected_total"] = int(df["reject_reason"].notna().sum())

    ok = df[df["reject_reason"].isna()].drop(columns=["reject_reason"]).copy()
    rej = df[df["reject_reason"].notna()][["source_row_number", "source_listing_id", "title_clean", "make", "city", "province", "reject_reason"]].copy()
    rej["raw_price"] = raw.loc[rej.index, "price"]
    ok["asking_price_pkr"] = ok["asking_price_pkr"].astype("int64")
    stats["clean_rows"] = len(ok)
    content_cols = ["title_clean", "area", "city", "model_year", "asking_price_pkr", "mileage_km", "engine_cc", "fuel_type", "transmission"]
    stats["possible_content_duplicates"] = int(ok.duplicated(subset=content_cols, keep="first").sum())
    stats["distinct_vehicle_bk"] = int(ok["vehicle_bk"].nunique())
    stats["distinct_city_bk"] = int(ok["city_bk"].nunique())

    ex = raw.sample(6, random_state=7)
    stats["examples"] = {
        "location": [(a, parse_location(a)[1] + " / " + parse_location(a)[2]) for a in ex["location"].tolist()],
        "price": [(a, parse_price(a)) for a in ex["price"].tolist()],
        "title": [(a, parse_title(a)[0]) for a in raw["title"].sample(4, random_state=3).tolist()],
    }
    return raw, ok, rej, stats


if __name__ == "__main__":
    import sys
    _, ok, rej, st = clean(sys.argv[1])
    print(json.dumps({k: v for k, v in st.items() if k != "examples"}, indent=1, default=str))
    print(ok.groupby(["make"]).size().sort_values(ascending=False).head(60).to_dict())
    print(ok.groupby(["make", "model"]).size().sort_values(ascending=False).head(50).to_dict())
    print(ok.groupby(["province"]).size().to_dict(), ok.city.nunique())
    print(ok.city.value_counts().tail(25).to_dict())
    print(ok.fuel_type.value_counts().to_dict())
    print(ok.asking_price_pkr.describe())
