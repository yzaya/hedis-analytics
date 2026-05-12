-- =============================================================================
-- Measure:     COL — Colorectal Cancer Screening
-- Description: Tracks whether eligible members received a recommended
--              colorectal cancer screening during the measurement year or
--              within the look-back window.
-- Denominator: Members aged 45-75 as of Dec 31, 2021, alive at year end.
-- Numerator:   Members with a qualifying colorectal screening procedure
--              in 2020 or 2021 (HCPCS):
--                45378, 45380, 45385          — colonoscopy
--                G0328, 82270, 82274          — FOBT / FIT
-- Data sources: beneficiary, carrier, outpatient
-- Measurement year: 2021
-- Direction:   Higher is better
-- Output:      One row per eligible member. screened = 1 if any qualifying
--              screening claim found in 2020-2021, 0 otherwise.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Age-eligible population (45-75, alive at end of 2021)
-- -----------------------------------------------------------------------
eligible AS (
    SELECT BENE_ID
    FROM beneficiary
    WHERE BENE_DEATH_DT IS NULL
      AND FLOOR(DATEDIFF(day, CONVERT(date, BENE_BIRTH_DT, 106), '2021-12-31') / 365.25)
          BETWEEN 45 AND 75
),

-- -----------------------------------------------------------------------
-- Step 2: Screening claims in measurement year or year prior
-- HEDIS allows a 1-year look-back for COL screening recency.
-- -----------------------------------------------------------------------
screening_claims AS (
    SELECT DISTINCT BENE_ID
    FROM (
        SELECT BENE_ID, HCPCS_CD
        FROM carrier
        WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2020-01-01' AND '2021-12-31'
        UNION ALL
        SELECT BENE_ID, HCPCS_CD
        FROM outpatient
        WHERE CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2020-01-01' AND '2021-12-31'
    ) h
    WHERE h.HCPCS_CD IN ('45378','45380','45385','G0328','82274','82270')
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    e.BENE_ID,
    CASE WHEN s.BENE_ID IS NOT NULL THEN 1 ELSE 0 END AS screened
FROM eligible e
LEFT JOIN screening_claims s ON e.BENE_ID = s.BENE_ID
ORDER BY e.BENE_ID;
