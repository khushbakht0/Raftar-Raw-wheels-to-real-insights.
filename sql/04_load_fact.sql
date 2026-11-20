TRUNCATE project_dw.fact_listing_observation RESTART IDENTITY;

-- business key -> surrogate key via joins
INSERT INTO project_dw.fact_listing_observation
    (source_listing_id, vehicle_key, city_key, source_key, observation_date_key, extract_date_key,
     last_updated_date_key, asking_price_pkr, mileage_km)
SELECT s.source_listing_id,
       v.vehicle_key,
       c.city_key,
       src.source_key,
       -1,
       20221010,
       COALESCE(d.date_key, -1),
       s.asking_price_pkr,
       s.mileage_km
FROM project_staging.stg_listing_clean s
JOIN project_dw.dim_vehicle v ON v.vehicle_bk = s.vehicle_bk
JOIN project_dw.dim_city c ON c.city_bk = s.city_bk
CROSS JOIN project_dw.dim_source src
LEFT JOIN project_dw.dim_date d ON d.full_date = s.last_updated_date
WHERE src.source_key > 0
ORDER BY s.source_row_number;
