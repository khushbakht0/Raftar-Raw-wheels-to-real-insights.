-- 1. Orphans: fact rows with no matching dimension row (expect 0)
SELECT 'orphans vehicle' AS check_name, COUNT(*) AS result
FROM project_dw.fact_listing_observation f
LEFT JOIN project_dw.dim_vehicle d USING (vehicle_key) WHERE d.vehicle_key IS NULL
UNION ALL
SELECT 'orphans city', COUNT(*)
FROM project_dw.fact_listing_observation f
LEFT JOIN project_dw.dim_city d USING (city_key) WHERE d.city_key IS NULL
UNION ALL
SELECT 'orphans source', COUNT(*)
FROM project_dw.fact_listing_observation f
LEFT JOIN project_dw.dim_source d USING (source_key) WHERE d.source_key IS NULL
UNION ALL
-- 2. Duplicate business keys in dimensions (expect 0)
SELECT 'dup vehicle_bk', COUNT(*) FROM
  (SELECT vehicle_bk FROM project_dw.dim_vehicle GROUP BY 1 HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'dup city_bk', COUNT(*) FROM
  (SELECT city_bk FROM project_dw.dim_city GROUP BY 1 HAVING COUNT(*) > 1) x
UNION ALL
-- 3. Correct mapping: fact's vehicle_key must point to the dim row with the SAME business key as staging (expect 0)
SELECT 'wrong vehicle mapping', COUNT(*)
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_vehicle v ON v.vehicle_key = f.vehicle_key
JOIN project_staging.stg_listing_clean s ON s.source_listing_id = f.source_listing_id
WHERE s.vehicle_bk <> v.vehicle_bk
UNION ALL
SELECT 'wrong city mapping', COUNT(*)
FROM project_dw.fact_listing_observation f
JOIN project_dw.dim_city c ON c.city_key = f.city_key
JOIN project_staging.stg_listing_clean s ON s.source_listing_id = f.source_listing_id
WHERE s.city_bk <> c.city_bk
UNION ALL
-- 4. No rows lost or multiplied (expect 0)
SELECT 'fact vs staging row diff',
  (SELECT COUNT(*) FROM project_staging.stg_listing_clean)
  - (SELECT COUNT(*) FROM project_dw.fact_listing_observation);