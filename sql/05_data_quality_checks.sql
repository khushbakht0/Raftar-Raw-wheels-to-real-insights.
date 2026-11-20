DROP TABLE IF EXISTS project_reporting.dq_results CASCADE;

CREATE TABLE project_reporting.dq_results (
    check_id    SERIAL PRIMARY KEY,
    category    TEXT NOT NULL,
    check_name  TEXT NOT NULL,
    expected    TEXT NOT NULL,
    actual      NUMERIC NOT NULL,
    status      TEXT NOT NULL CHECK (status IN ('PASS','FAIL','INFO'))
);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Reconciliation', 'Raw rows = clean rows + rejected rows (control total)', '= 0 (difference)', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT ABS((SELECT COUNT(*) FROM project_staging.raw_listings) - (SELECT COUNT(*) FROM project_staging.stg_listing_clean) - (SELECT COUNT(*) FROM project_staging.stg_listing_reject))) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Reconciliation', 'Clean staging rows = fact rows', '= 0 (difference)', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT ABS((SELECT COUNT(*) FROM project_staging.stg_listing_clean) - (SELECT COUNT(*) FROM project_dw.fact_listing_observation))) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Reconciliation', 'Total asking price in staging = total in fact (control total, not revenue)', '= 0 (difference)', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT ABS((SELECT SUM(asking_price_pkr) FROM project_staging.stg_listing_clean) - (SELECT SUM(asking_price_pkr) FROM project_dw.fact_listing_observation))) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Reconciliation', 'Rows in reject table (all reasons)', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_staging.stg_listing_reject) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with NULL asking_price_pkr', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE asking_price_pkr IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with NULL vehicle_key', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE vehicle_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with NULL city_key', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE city_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with NULL source_listing_id', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE source_listing_id IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with missing mileage', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE mileage_km IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with unknown last-updated date', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE last_updated_date_key = -1) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with missing model year', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key WHERE v.model_year IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with unknown body type', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key WHERE v.body_type = 'Unknown') AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with unknown fuel type', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key WHERE v.fuel_type = 'Unknown') AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with missing engine cc', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key WHERE v.engine_cc IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'Fact rows with unknown city or province', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f JOIN project_dw.dim_city c ON c.city_key = f.city_key WHERE c.city_name = 'Unknown' OR c.province = 'Unknown') AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Asking price <= 0', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE asking_price_pkr <= 0) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Asking price below PKR 50,000', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE asking_price_pkr < 50000) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Asking price above PKR 500,000,000', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE asking_price_pkr > 500000000) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Negative mileage', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE mileage_km < 0) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Mileage above 1,000,000 km', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE mileage_km > 1000000) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Mileage under 100 km (likely placeholder, kept as is)', 'informational', n, 'INFO'
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE mileage_km < 100) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Model year outside 1950-2022', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle WHERE model_year < 1950 OR model_year > 2022) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Engine cc outside 500-8000', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle WHERE engine_cc < 500 OR engine_cc > 8000) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Accuracy', 'Last-updated date later than extract date', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE last_updated_date_key > extract_date_key) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Validity', 'Transmission not Automatic / Manual / Unknown', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle WHERE transmission NOT IN ('Automatic','Manual','Unknown')) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Validity', 'Fuel not Petrol / Diesel / Hybrid / Electric / Unknown', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle WHERE fuel_type NOT IN ('Petrol','Diesel','Hybrid','Electric','Unknown')) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Validity', 'Province outside the expected list', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_city WHERE province NOT IN ('Punjab','Sindh','Khyber Pakhtunkhwa','Balochistan','Islamabad Capital Territory','Azad Kashmir','Gilgit-Baltistan','FATA','Unknown')) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Validity', 'listing_count not equal to 1', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE listing_count <> 1) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Validity', 'Text with leading/trailing spaces in dim_city', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_city WHERE city_name <> TRIM(city_name)) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Validity', 'Text with leading/trailing spaces in dim_vehicle make/model', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle WHERE make <> TRIM(make) OR model <> TRIM(model)) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Uniqueness', 'Duplicate source_listing_id in fact', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM (SELECT source_listing_id FROM project_dw.fact_listing_observation GROUP BY source_listing_id HAVING COUNT(*) > 1) t) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Uniqueness', 'Duplicate vehicle_bk in dim_vehicle', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM (SELECT vehicle_bk FROM project_dw.dim_vehicle GROUP BY vehicle_bk HAVING COUNT(*) > 1) t) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Uniqueness', 'Duplicate city_bk in dim_city', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM (SELECT city_bk FROM project_dw.dim_city GROUP BY city_bk HAVING COUNT(*) > 1) t) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Uniqueness', 'Duplicate dates in dim_date', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM (SELECT full_date FROM project_dw.dim_date GROUP BY full_date HAVING COUNT(*) > 1) t) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Uniqueness', 'Extra rows sharing vehicle + city + price + mileage (possible repeat ads, kept)', 'informational', n, 'INFO'
FROM (SELECT COALESCE(SUM(c - 1), 0) FROM (SELECT COUNT(*) AS c FROM project_dw.fact_listing_observation GROUP BY vehicle_key, city_key, asking_price_pkr, mileage_km HAVING COUNT(*) > 1) t) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows without matching dim_vehicle', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f LEFT JOIN project_dw.dim_vehicle d ON d.vehicle_key = f.vehicle_key WHERE d.vehicle_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows without matching dim_city', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f LEFT JOIN project_dw.dim_city d ON d.city_key = f.city_key WHERE d.city_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows without matching dim_source', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f LEFT JOIN project_dw.dim_source d ON d.source_key = f.source_key WHERE d.source_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows without matching dim_date (observation)', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f LEFT JOIN project_dw.dim_date d ON d.date_key = f.observation_date_key WHERE d.date_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows without matching dim_date (extract)', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f LEFT JOIN project_dw.dim_date d ON d.date_key = f.extract_date_key WHERE d.date_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows without matching dim_date (last updated)', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation f LEFT JOIN project_dw.dim_date d ON d.date_key = f.last_updated_date_key WHERE d.date_key IS NULL) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Fact rows pointing to the Unknown vehicle member', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation WHERE vehicle_key = -1) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Dimension rows never used by any fact (vehicle)', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle v LEFT JOIN project_dw.fact_listing_observation f ON f.vehicle_key = v.vehicle_key WHERE f.vehicle_key IS NULL AND v.vehicle_key <> -1) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Integrity', 'Dimension rows never used by any fact (city)', '= 0', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_city c LEFT JOIN project_dw.fact_listing_observation f ON f.city_key = c.city_key WHERE f.city_key IS NULL AND c.city_key <> -1) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Size', 'Fact rows (minimum 10,000)', '>= 10000', n, CASE WHEN n >= 10000 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.fact_listing_observation) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Size', 'dim_vehicle rows (minimum 100)', '>= 100', n, CASE WHEN n >= 100 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_vehicle) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Size', 'dim_city rows (minimum 100)', '>= 100', n, CASE WHEN n >= 100 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_city) AS t(n);

INSERT INTO project_reporting.dq_results (category, check_name, expected, actual, status)
SELECT 'Size', 'dim_date rows (minimum 100)', '>= 100', n, CASE WHEN n >= 100 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) FROM project_dw.dim_date) AS t(n);
