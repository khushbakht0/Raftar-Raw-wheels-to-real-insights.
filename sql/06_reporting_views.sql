-- one view per Phase 1 business question, median via PERCENTILE_CONT, n = sample size

CREATE OR REPLACE VIEW project_reporting.vw_q1_price_by_make_model AS
SELECT v.make, v.model,
       COUNT(*) AS listings,
       MIN(f.asking_price_pkr) AS min_price,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.asking_price_pkr) AS median_price,
       MAX(f.asking_price_pkr) AS max_price
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
GROUP BY v.make, v.model;

CREATE OR REPLACE VIEW project_reporting.vw_q2_price_by_model_year AS
SELECT v.make, v.model, v.model_year,
       COUNT(*) AS listings,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.asking_price_pkr) AS median_price
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
WHERE v.model_year IS NOT NULL
GROUP BY v.make, v.model, v.model_year
HAVING COUNT(*) >= 10;

CREATE OR REPLACE VIEW project_reporting.vw_q3_price_by_mileage_band AS
SELECT v.make, v.model,
       CASE WHEN f.mileage_km IS NULL THEN '6 Unknown'
            WHEN f.mileage_km < 100 THEN '0 Under 100 km (placeholder?)'
            WHEN f.mileage_km < 25000 THEN '1 100 - 24,999 km'
            WHEN f.mileage_km < 50000 THEN '2 25,000 - 49,999 km'
            WHEN f.mileage_km < 100000 THEN '3 50,000 - 99,999 km'
            WHEN f.mileage_km < 150000 THEN '4 100,000 - 149,999 km'
            ELSE '5 150,000+ km' END AS mileage_band,
       COUNT(*) AS listings,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.asking_price_pkr) AS median_price
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
GROUP BY v.make, v.model, 3
HAVING COUNT(*) >= 10;

CREATE OR REPLACE VIEW project_reporting.vw_q4_price_by_city AS
SELECT v.make, v.model, c.province, c.city_name,
       COUNT(*) AS listings,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.asking_price_pkr) AS median_price
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
JOIN project_dw.dim_city c ON c.city_key = f.city_key
WHERE c.city_name <> 'Unknown'
GROUP BY v.make, v.model, c.province, c.city_name
HAVING COUNT(*) >= 10;

CREATE OR REPLACE VIEW project_reporting.vw_q5_price_by_transmission_fuel AS
SELECT v.make, v.model, v.model_year, v.transmission, v.fuel_type,
       COUNT(*) AS listings,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.asking_price_pkr) AS median_price
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
WHERE v.transmission <> 'Unknown' AND v.fuel_type <> 'Unknown' AND v.model_year IS NOT NULL
GROUP BY v.make, v.model, v.model_year, v.transmission, v.fuel_type
HAVING COUNT(*) >= 5;

CREATE OR REPLACE VIEW project_reporting.vw_q6_price_band_share AS
SELECT b.price_band,
       COUNT(*) AS listings,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM project_dw.fact_listing_observation), 2) AS pct_of_listings
FROM (SELECT CASE WHEN asking_price_pkr < 1000000 THEN '1 Under 10 lacs'
                  WHEN asking_price_pkr < 2000000 THEN '2 10 - 20 lacs'
                  WHEN asking_price_pkr < 3000000 THEN '3 20 - 30 lacs'
                  WHEN asking_price_pkr < 5000000 THEN '4 30 - 50 lacs'
                  WHEN asking_price_pkr < 10000000 THEN '5 50 lacs - 1 crore'
                  ELSE '6 1 crore and above' END AS price_band
      FROM project_dw.fact_listing_observation) b
GROUP BY b.price_band;

CREATE OR REPLACE VIEW project_reporting.vw_q7_listings_by_segment AS
SELECT v.body_type, v.fuel_type, v.transmission, COUNT(*) AS listings
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
GROUP BY v.body_type, v.fuel_type, v.transmission;

CREATE OR REPLACE VIEW project_reporting.vw_q8_quality_by_make AS
SELECT a.make, a.listings, a.missing_model_year, a.unknown_body_type, a.unknown_fuel,
       a.missing_mileage, a.mileage_under_100,
       COALESCE(r.rejected, 0) AS rejected_listings,
       a.missing_model_year + a.unknown_body_type + a.unknown_fuel + a.missing_mileage + COALESCE(r.rejected, 0) AS total_issues
FROM (SELECT v.make,
             COUNT(*) AS listings,
             SUM(CASE WHEN v.model_year IS NULL THEN 1 ELSE 0 END) AS missing_model_year,
             SUM(CASE WHEN v.body_type = 'Unknown' THEN 1 ELSE 0 END) AS unknown_body_type,
             SUM(CASE WHEN v.fuel_type = 'Unknown' THEN 1 ELSE 0 END) AS unknown_fuel,
             SUM(CASE WHEN f.mileage_km IS NULL THEN 1 ELSE 0 END) AS missing_mileage,
             SUM(CASE WHEN f.mileage_km < 100 THEN 1 ELSE 0 END) AS mileage_under_100
      FROM project_dw.fact_listing_observation f
      JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
      GROUP BY v.make) a
LEFT JOIN (SELECT make, COUNT(*) AS rejected FROM project_staging.stg_listing_reject GROUP BY make) r
       ON r.make = a.make;

CREATE OR REPLACE VIEW project_reporting.vw_q8_quality_by_city AS
SELECT a.province, a.city_name, a.listings, a.missing_model_year, a.unknown_body_type, a.unknown_fuel,
       a.missing_mileage, a.mileage_under_100,
       COALESCE(r.rejected, 0) AS rejected_listings,
       a.missing_model_year + a.unknown_body_type + a.unknown_fuel + a.missing_mileage + COALESCE(r.rejected, 0) AS total_issues
FROM (SELECT c.province, c.city_name,
             COUNT(*) AS listings,
             SUM(CASE WHEN v.model_year IS NULL THEN 1 ELSE 0 END) AS missing_model_year,
             SUM(CASE WHEN v.body_type = 'Unknown' THEN 1 ELSE 0 END) AS unknown_body_type,
             SUM(CASE WHEN v.fuel_type = 'Unknown' THEN 1 ELSE 0 END) AS unknown_fuel,
             SUM(CASE WHEN f.mileage_km IS NULL THEN 1 ELSE 0 END) AS missing_mileage,
             SUM(CASE WHEN f.mileage_km < 100 THEN 1 ELSE 0 END) AS mileage_under_100
      FROM project_dw.fact_listing_observation f
      JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
      JOIN project_dw.dim_city c ON c.city_key = f.city_key
      GROUP BY c.province, c.city_name) a
LEFT JOIN (SELECT city, province, COUNT(*) AS rejected FROM project_staging.stg_listing_reject GROUP BY city, province) r
       ON r.city = a.city_name AND r.province = a.province;

-- last_updated date, not a true capture date, so this is a coverage-limited trend
CREATE OR REPLACE VIEW project_reporting.vw_q9_price_by_last_updated_month AS
SELECT d.year, d.month, d.month_name,
       COUNT(*) AS listings,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.asking_price_pkr) AS median_price
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_date d ON d.date_key = f.last_updated_date_key
WHERE f.last_updated_date_key <> -1
GROUP BY d.year, d.month, d.month_name;

CREATE OR REPLACE VIEW project_reporting.vw_dq_summary AS
SELECT category,
       COUNT(*) AS checks,
       SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
       SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
       SUM(CASE WHEN status = 'INFO' THEN 1 ELSE 0 END) AS info
FROM project_reporting.dq_results
GROUP BY category;
