SELECT 'raw_listings' AS table_name, COUNT(*) AS rows FROM project_staging.raw_listings
UNION ALL
SELECT 'stg_listing_clean', COUNT(*) FROM project_staging.stg_listing_clean
UNION ALL
SELECT 'stg_listing_reject', COUNT(*) FROM project_staging.stg_listing_reject;
--Reason for Rejected rows 1407
SELECT reject_reason, COUNT(*) AS count
FROM project_staging.stg_listing_reject
GROUP BY reject_reason
ORDER BY count DESC;


SELECT source_listing_id, make, model, model_year, variant, asking_price_pkr, mileage_km, city, province, vehicle_bk, city_bk
FROM project_staging.stg_listing_clean
LIMIT 10;

SELECT * FROM project_reporting.dq_results ORDER BY check_id;
