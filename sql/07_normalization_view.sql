-- Read-only view: shows how much vehicle dim over-splits. Does not modify dim_vehicle.
CREATE OR REPLACE VIEW project_dw.v_dim_vehicle_norm AS
SELECT vehicle_key, make, model, model_year, engine_cc, body_type,
  TRIM(REGEXP_REPLACE(REGEXP_REPLACE(variant,
       '\s*(beige|black|grey|gray|brown|tan)\s+interior\s*$', '', 'i'),
       '\s+', ' ', 'g'))                                   AS variant_norm,
  CASE WHEN variant ~* 'hybrid' THEN 'Hybrid' ELSE fuel_type END AS fuel_norm,
  CASE WHEN variant ~* 'cvt|cruisetronic|automatic' THEN 'Automatic'
       ELSE transmission END                               AS trans_norm
FROM project_dw.dim_vehicle;

-- Before vs after normalization
SELECT (SELECT COUNT(*) FROM project_dw.dim_vehicle) AS before_rows,
       (SELECT COUNT(*) FROM (SELECT DISTINCT make, model, model_year, engine_cc, body_type,
              variant_norm, fuel_norm, trans_norm
        FROM project_dw.v_dim_vehicle_norm) x)        AS after_rows;