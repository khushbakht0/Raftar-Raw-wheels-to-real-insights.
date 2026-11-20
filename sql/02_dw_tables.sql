DROP TABLE IF EXISTS project_dw.fact_listing_observation CASCADE;
DROP TABLE IF EXISTS project_dw.dim_vehicle CASCADE;
DROP TABLE IF EXISTS project_dw.dim_city CASCADE;
DROP TABLE IF EXISTS project_dw.dim_source CASCADE;
DROP TABLE IF EXISTS project_dw.dim_date CASCADE;

CREATE TABLE project_dw.dim_date (
    date_key    INTEGER PRIMARY KEY,
    full_date   DATE NOT NULL UNIQUE,
    day         SMALLINT NOT NULL,
    month       SMALLINT NOT NULL,
    month_name  TEXT NOT NULL,
    quarter     SMALLINT NOT NULL,
    year        SMALLINT NOT NULL
);

CREATE TABLE project_dw.dim_vehicle (
    vehicle_key   SERIAL PRIMARY KEY,
    vehicle_bk    TEXT NOT NULL UNIQUE,
    make          TEXT NOT NULL,
    model         TEXT NOT NULL,
    model_year    SMALLINT,
    variant       TEXT NOT NULL,
    body_type     TEXT NOT NULL,
    engine_cc     INTEGER CHECK (engine_cc IS NULL OR engine_cc > 0),
    fuel_type     TEXT NOT NULL,
    transmission  TEXT NOT NULL
);

CREATE TABLE project_dw.dim_city (
    city_key   SERIAL PRIMARY KEY,
    city_bk    TEXT NOT NULL UNIQUE,
    city_name  TEXT NOT NULL,
    province   TEXT NOT NULL
);

CREATE TABLE project_dw.dim_source (
    source_key     SERIAL PRIMARY KEY,
    source_name    TEXT NOT NULL UNIQUE,
    source_url     TEXT,
    access_method  TEXT NOT NULL,
    terms_notes    TEXT
);

CREATE TABLE project_dw.fact_listing_observation (
    listing_observation_key  SERIAL PRIMARY KEY,
    source_listing_id        TEXT NOT NULL UNIQUE,
    vehicle_key              INTEGER NOT NULL REFERENCES project_dw.dim_vehicle (vehicle_key),
    city_key                 INTEGER NOT NULL REFERENCES project_dw.dim_city (city_key),
    source_key               INTEGER NOT NULL REFERENCES project_dw.dim_source (source_key),
    observation_date_key     INTEGER NOT NULL REFERENCES project_dw.dim_date (date_key),
    extract_date_key         INTEGER NOT NULL REFERENCES project_dw.dim_date (date_key),
    last_updated_date_key    INTEGER NOT NULL REFERENCES project_dw.dim_date (date_key),
    asking_price_pkr         NUMERIC(18,2) NOT NULL CHECK (asking_price_pkr > 0),
    mileage_km               INTEGER CHECK (mileage_km IS NULL OR mileage_km >= 0),
    listing_count            INTEGER NOT NULL DEFAULT 1 CHECK (listing_count = 1),
    load_date                DATE NOT NULL DEFAULT CURRENT_DATE
);
