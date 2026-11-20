TRUNCATE project_dw.fact_listing_observation;
TRUNCATE project_dw.dim_vehicle RESTART IDENTITY CASCADE;
TRUNCATE project_dw.dim_city RESTART IDENTITY CASCADE;
TRUNCATE project_dw.dim_source RESTART IDENTITY CASCADE;
TRUNCATE project_dw.dim_date CASCADE;

-- dim_date: one row per day, plus Unknown member -1
INSERT INTO project_dw.dim_date VALUES (-1, DATE '1900-01-01', 1, 1, 'Unknown', 1, 1900);

INSERT INTO project_dw.dim_date (date_key, full_date, day, month, month_name, quarter, year)
SELECT TO_CHAR(d, 'YYYYMMDD')::INTEGER,
       d::DATE,
       EXTRACT(DAY FROM d),
       EXTRACT(MONTH FROM d),
       TRIM(TO_CHAR(d, 'Month')),
       EXTRACT(QUARTER FROM d),
       EXTRACT(YEAR FROM d)
FROM generate_series(DATE '2020-01-01', DATE '2023-12-31', INTERVAL '1 day') AS d;

-- dim_source: one row, the single CSV extract
INSERT INTO project_dw.dim_source (source_key, source_name, source_url, access_method, terms_notes)
VALUES (-1, 'Unknown', NULL, 'Unknown', NULL);

INSERT INTO project_dw.dim_source (source_name, source_url, access_method, terms_notes)
VALUES ('PakWheels used-car listings (Kaggle CSV extract, Oct 2022)', 'https://www.pakwheels.com',
        'Manual CSV download from Kaggle', 'Kaggle licence not verified, check before redistributing data');

-- dim_city
INSERT INTO project_dw.dim_city (city_key, city_bk, city_name, province)
VALUES (-1, 'Unknown|Unknown', 'Unknown', 'Unknown');

INSERT INTO project_dw.dim_city (city_bk, city_name, province)
SELECT DISTINCT city_bk, city, province
FROM project_staging.stg_listing_clean
WHERE city_bk <> 'Unknown|Unknown'
ORDER BY province, city;

-- dim_vehicle
INSERT INTO project_dw.dim_vehicle (vehicle_key, vehicle_bk, make, model, model_year, variant, body_type, engine_cc, fuel_type, transmission)
VALUES (-1, 'Unknown', 'Unknown', 'Unknown', NULL, 'Unspecified', 'Unknown', NULL, 'Unknown', 'Unknown');

INSERT INTO project_dw.dim_vehicle (vehicle_bk, make, model, model_year, variant, body_type, engine_cc, fuel_type, transmission)
SELECT DISTINCT vehicle_bk, make, model, model_year, variant, body_type, engine_cc, fuel_type, transmission
FROM project_staging.stg_listing_clean
ORDER BY make, model, model_year;
