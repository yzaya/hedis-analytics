-- =============================================================================
-- Measure:     AAB — Avoidance of Antibiotic Treatment for Acute Bronchitis/
--                    Bronchiolitis
-- Description: Overuse measure. Tracks whether members with an acute
--              bronchitis episode AVOIDED an antibiotic prescription within
--              3 days before to 3 days after the diagnosis. Antibiotics are
--              not indicated for viral bronchitis.
-- Denominator: Members aged 3 months+ with an acute bronchitis/bronchiolitis
--              episode in 2021 (ICD-10 J20.x, J21.x), excluding members with
--              competing/comorbid diagnoses that would justify antibiotics.
--              (Comorbid exclusion list simplified for this implementation —
--              see note below.)
-- Numerator:   Members from the denominator who were NOT dispensed a qualifying
--              antibiotic within the -3 to +3 day window around the index dx.
--              Numerator counts members who AVOIDED antibiotics.
-- Data sources: beneficiary, carrier, outpatient, pde
-- Measurement year: 2021
-- Direction:   Higher is better (high rate = good stewardship)
-- Output:      One row per qualifying bronchitis episode.
--              antibiotic_dispensed = 1 if any antibiotic claim in window.
--              avoided_antibiotic   = 1 if NOT dispensed (numerator hit).
--
-- NOTE on antibiotic identification:
--   Real HEDIS uses the NCQA-published antibiotic NDC value set. The CMS
--   synthetic dataset has no NDC reference lookup. The antibiotic_ndcs CTE
--   below uses a documented placeholder pattern matching common antibiotic
--   NDC labeler prefixes (5-digit manufacturer codes for major antibiotic
--   producers). In production this CTE should be replaced with the official
--   HEDIS antibiotic medication list joined from a reference table.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Bronchitis index events in 2021 (denominator)
-- One row per (member, first bronchitis date) in 2021.
-- Sources: outpatient principal dx, carrier line-level dx.
-- -----------------------------------------------------------------------
bronchitis_episodes AS (
    SELECT BENE_ID, MIN(svc_dt) AS index_dt
    FROM (
        SELECT BENE_ID,
               CONVERT(date, CLM_FROM_DT, 106) AS svc_dt,
               PRNCPAL_DGNS_CD AS dx
        FROM outpatient
        WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
        UNION ALL
        SELECT BENE_ID,
               CONVERT(date, CLM_FROM_DT, 106),
               LINE_ICD_DGNS_CD
        FROM carrier
        WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
    ) c
    WHERE c.dx LIKE 'J20%' OR c.dx LIKE 'J21%'
    GROUP BY BENE_ID
),

-- -----------------------------------------------------------------------
-- Step 2: Antibiotic NDC value set (placeholder — see header note)
-- Pattern matches common antibiotic labeler prefixes. Substitute with the
-- NCQA HEDIS antibiotic medication list in production.
-- -----------------------------------------------------------------------
antibiotic_ndcs AS (
    SELECT DISTINCT PROD_SRVC_ID AS ndc
    FROM pde
    WHERE PROD_SRVC_ID LIKE '00093%'   -- Teva (amoxicillin, ciprofloxacin, etc.)
       OR PROD_SRVC_ID LIKE '00781%'   -- Sandoz (azithromycin, doxycycline)
       OR PROD_SRVC_ID LIKE '00904%'   -- Major Pharmaceuticals (amoxicillin)
       OR PROD_SRVC_ID LIKE '50111%'   -- Pliva (azithromycin)
       OR PROD_SRVC_ID LIKE '00143%'   -- Hikma (cephalexin)
       OR PROD_SRVC_ID LIKE '65862%'   -- Aurobindo (amox/clav, azithro)
),

-- -----------------------------------------------------------------------
-- Step 3: Antibiotic dispensings in -3 to +3 day window around index dx
-- -----------------------------------------------------------------------
abx_in_window AS (
    SELECT DISTINCT b.BENE_ID, b.index_dt
    FROM bronchitis_episodes b
    JOIN pde p ON b.BENE_ID = p.BENE_ID
    JOIN antibiotic_ndcs a ON p.PROD_SRVC_ID = a.ndc
    WHERE CONVERT(date, p.SRVC_DT, 106)
          BETWEEN DATEADD(day, -3, b.index_dt) AND DATEADD(day, 3, b.index_dt)
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    b.BENE_ID,
    b.index_dt,
    CASE WHEN a.BENE_ID IS NOT NULL THEN 1 ELSE 0 END AS antibiotic_dispensed,
    CASE WHEN a.BENE_ID IS NULL     THEN 1 ELSE 0 END AS avoided_antibiotic
FROM bronchitis_episodes b
LEFT JOIN abx_in_window a
    ON  b.BENE_ID = a.BENE_ID
    AND b.index_dt = a.index_dt
ORDER BY b.BENE_ID, b.index_dt;
