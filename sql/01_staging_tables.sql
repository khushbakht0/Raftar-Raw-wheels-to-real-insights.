DROP TABLE IF EXISTS project_staging.raw_listings CASCADE;
DROP TABLE IF EXISTS project_staging.stg_listing_clean CASCADE;
DROP TABLE IF EXISTS project_staging.stg_listing_reject CASCADE;

-- raw copy of the CSV, all text, description and car_features not loaded (privacy)
CREATE TABLE project_staging.raw_listings (
    source_row_number  INTEGER,
    ad_url             TEXT,
    title              TEXT,
    location           TEXT,
    model_year         TEXT,
    price              TEXT,
    mileage            TEXT,
    engine_type        TEXT,
    transmission       TEXT,
    registered_in      TEXT,
    color              TEXT,
    assembly           TEXT,
    engine_capacity    TEXT,
    body_type          TEXT,
    ad_last_updated    TEXT
);

CREATE TABLE project_staging.stg_listing_clean (
    source_row_number  INTEGER PRIMARY KEY,
    source_listing_id  TEXT NOT NULL,
    title_clean        TEXT,
    make               TEXT NOT NULL,
    model              TEXT NOT NULL,
    variant            TEXT NOT NULL,
    model_year         INTEGER,
    asking_price_pkr   NUMERIC(18,2) NOT NULL,
    mileage_km         INTEGER,
    engine_cc          INTEGER,
    fuel_type          TEXT NOT NULL,
    transmission       TEXT NOT NULL,
    body_type          TEXT NOT NULL,
    area               TEXT,
    city               TEXT NOT NULL,
    province           TEXT NOT NULL,
    last_updated_date  DATE,
    vehicle_bk         TEXT NOT NULL,
    city_bk            TEXT NOT NULL
);

CREATE TABLE project_staging.stg_listing_reject (
    source_row_number  INTEGER PRIMARY KEY,
    source_listing_id  TEXT,
    title_clean        TEXT,
    make               TEXT,
    city               TEXT,
    province           TEXT,
    reject_reason      TEXT NOT NULL,
    raw_price          TEXT
);
