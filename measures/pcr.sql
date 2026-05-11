-- =============================================================================
-- Measure:     PCR — Plan All-Cause Readmissions
-- Description: Tracks the rate of unplanned inpatient readmissions within
--              30 days of a prior inpatient discharge.
-- Denominator: All inpatient discharges in 2021 (index admissions).
--              CLM_LINE_NUM = 1 selects the header-level record per claim.
-- Numerator:   Index admissions followed by an unplanned inpatient readmission
--              within 30 days of discharge. The 30-day window opens the day
--              after discharge (strict greater than on discharge date).
-- Data sources: inpatient
-- Measurement year: 2021
-- Direction:   Lower is better
-- Output:      One row per index admission. readmitted_30_day = 1 if the
--              member was readmitted within 30 days, 0 otherwise.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Index admissions (denominator)
-- One record per inpatient discharge in 2021
-- -----------------------------------------------------------------------
index_admissions AS (
    SELECT
        BENE_ID,
        CONVERT(date, CLM_FROM_DT, 106)  AS admit_dt,
        CONVERT(date, CLM_THRU_DT, 106)  AS discharge_dt
    FROM inpatient
    WHERE CLM_LINE_NUM = 1
      AND CONVERT(date, CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
),

-- -----------------------------------------------------------------------
-- Step 2: Readmissions
-- Index admissions with any subsequent inpatient stay within 30 days
-- -----------------------------------------------------------------------
readmissions AS (
    SELECT DISTINCT i.BENE_ID, i.admit_dt
    FROM index_admissions i
    JOIN inpatient r
        ON  i.BENE_ID = r.BENE_ID
        AND r.CLM_LINE_NUM = 1
        AND CONVERT(date, r.CLM_FROM_DT, 106) > i.discharge_dt
        AND CONVERT(date, r.CLM_FROM_DT, 106) <= DATEADD(day, 30, i.discharge_dt)
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    i.BENE_ID,
    i.admit_dt,
    i.discharge_dt,
    CASE WHEN r.BENE_ID IS NOT NULL THEN 1 ELSE 0 END AS readmitted_30_day
FROM index_admissions i
LEFT JOIN readmissions r
    ON  i.BENE_ID = r.BENE_ID
    AND i.admit_dt = r.admit_dt
ORDER BY i.BENE_ID, i.admit_dt;
