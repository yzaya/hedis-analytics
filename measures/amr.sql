-- =============================================================================
-- Measure:     AMR — Asthma Medication Ratio
-- Description: Tracks whether members with persistent asthma have a ratio of
--              controller medications to total asthma medications of 0.50
--              or greater. A higher ratio indicates appropriate use of
--              maintenance controllers over short-acting relievers.
-- Denominator: Members aged 5-64 with persistent asthma (ICD-10 J45.x) in
--              2021 who had at least one asthma medication dispensed.
-- Numerator:   Members with AMR >= 0.50, where
--              AMR = controller_units / (controller_units + reliever_units)
-- Data sources: beneficiary, inpatient, outpatient, carrier, pde
-- Measurement year: 2021
-- Direction:   Higher is better
-- Output:      One row per denominator member with controller_units,
--              reliever_units, amr_ratio, and a binary on_target flag.
--
-- NOTE on medication classification:
--   Real HEDIS uses the NCQA-published asthma controller and reliever NDC
--   value sets. The CMS synthetic dataset has no NDC reference. The CTEs
--   controller_ndcs and reliever_ndcs below use documented labeler-prefix
--   placeholders for common manufacturers of fluticasone, budesonide,
--   beclomethasone (controllers) and albuterol, levalbuterol (relievers).
--   Replace these with the official HEDIS lists in production.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Age-eligible population (5-64, alive at year end)
-- -----------------------------------------------------------------------
age_eligible AS (
    SELECT BENE_ID
    FROM beneficiary
    WHERE BENE_DEATH_DT IS NULL
      AND FLOOR(DATEDIFF(day, CONVERT(date, BENE_BIRTH_DT, 106), '2021-12-31') / 365.25)
          BETWEEN 5 AND 64
),

-- -----------------------------------------------------------------------
-- Step 2: Members with a persistent asthma diagnosis in 2021
-- -----------------------------------------------------------------------
asthma_members AS (
    SELECT DISTINCT BENE_ID
    FROM (
        SELECT BENE_ID, PRNCPAL_DGNS_CD AS dx FROM inpatient
            WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
        UNION ALL
        SELECT BENE_ID, PRNCPAL_DGNS_CD FROM outpatient
            WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
        UNION ALL
        SELECT BENE_ID, LINE_ICD_DGNS_CD FROM carrier
            WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
    ) d
    WHERE dx LIKE 'J45%'
),

-- -----------------------------------------------------------------------
-- Step 3: Placeholder NDC value sets — replace with NCQA HEDIS lists
-- -----------------------------------------------------------------------
controller_ndcs AS (
    -- Inhaled corticosteroids: fluticasone, budesonide, beclomethasone, mometasone
    SELECT PROD_SRVC_ID AS ndc FROM pde
    WHERE PROD_SRVC_ID LIKE '00173%'  -- GSK (fluticasone, Flovent)
       OR PROD_SRVC_ID LIKE '00186%'  -- AstraZeneca (Pulmicort/budesonide)
       OR PROD_SRVC_ID LIKE '00085%'  -- Merck (Asmanex/mometasone)
       OR PROD_SRVC_ID LIKE '63402%'  -- Astellas (QVAR/beclomethasone)
),
reliever_ndcs AS (
    -- Short-acting beta-agonists: albuterol, levalbuterol
    SELECT PROD_SRVC_ID AS ndc FROM pde
    WHERE PROD_SRVC_ID LIKE '49502%'  -- Nephron (albuterol)
       OR PROD_SRVC_ID LIKE '00781%'  -- Sandoz (albuterol generic)
       OR PROD_SRVC_ID LIKE '00185%'  -- Eon Labs (albuterol)
       OR PROD_SRVC_ID LIKE '64980%'  -- Cipla (levalbuterol)
),

-- -----------------------------------------------------------------------
-- Step 4: PDE counts by drug class for each asthma member in 2021
-- -----------------------------------------------------------------------
controller_fills AS (
    SELECT p.BENE_ID, COUNT(*) AS units
    FROM pde p
    JOIN asthma_members a ON p.BENE_ID = a.BENE_ID
    WHERE p.PROD_SRVC_ID IN (SELECT ndc FROM controller_ndcs)
      AND CONVERT(date, p.SRVC_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
    GROUP BY p.BENE_ID
),
reliever_fills AS (
    SELECT p.BENE_ID, COUNT(*) AS units
    FROM pde p
    JOIN asthma_members a ON p.BENE_ID = a.BENE_ID
    WHERE p.PROD_SRVC_ID IN (SELECT ndc FROM reliever_ndcs)
      AND CONVERT(date, p.SRVC_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
    GROUP BY p.BENE_ID
),

-- -----------------------------------------------------------------------
-- Step 5: Denominator — asthma members with ANY asthma medication dispensed
-- -----------------------------------------------------------------------
denominator AS (
    SELECT DISTINCT a.BENE_ID
    FROM asthma_members a
    INNER JOIN age_eligible e ON a.BENE_ID = e.BENE_ID
    WHERE a.BENE_ID IN (SELECT BENE_ID FROM controller_fills)
       OR a.BENE_ID IN (SELECT BENE_ID FROM reliever_fills)
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    d.BENE_ID,
    COALESCE(c.units, 0)                                        AS controller_units,
    COALESCE(r.units, 0)                                        AS reliever_units,
    COALESCE(c.units, 0) + COALESCE(r.units, 0)                 AS total_units,
    CAST(COALESCE(c.units, 0) AS FLOAT)
        / NULLIF(COALESCE(c.units, 0) + COALESCE(r.units, 0), 0) AS amr_ratio,
    CASE
        WHEN CAST(COALESCE(c.units, 0) AS FLOAT)
             / NULLIF(COALESCE(c.units, 0) + COALESCE(r.units, 0), 0) >= 0.50
        THEN 1 ELSE 0
    END                                                          AS on_target
FROM denominator d
LEFT JOIN controller_fills c ON d.BENE_ID = c.BENE_ID
LEFT JOIN reliever_fills   r ON d.BENE_ID = r.BENE_ID
ORDER BY d.BENE_ID;
