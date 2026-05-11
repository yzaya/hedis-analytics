-- =============================================================================
-- Measure:     FUH — Follow-Up After Hospitalization for Mental Illness
-- Description: Tracks whether members discharged from an inpatient mental
--              illness stay receive outpatient follow-up within 7 and 30 days.
-- Denominator: Members aged 6+ discharged from an inpatient stay with a
--              principal mental illness diagnosis (ICD-10: F20–F99) in 2021.
--              CLM_LINE_NUM = 1 selects the header-level record per claim.
-- Numerator:   Two rates:
--              7-day  — members with any outpatient/carrier claim within
--                       7 days of discharge.
--              30-day — members with any outpatient/carrier claim within
--                       30 days of discharge.
--              Follow-up window opens the day after discharge (strict >).
-- Data sources: inpatient, carrier, outpatient
-- Measurement year: 2021
-- Direction:   Higher is better
-- Output:      One row per MH discharge. followup_7_day and followup_30_day
--              are 1 if the member received follow-up within the window, 0 otherwise.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Age-eligible population (6+, alive in 2021)
-- -----------------------------------------------------------------------
age_eligible AS (
    SELECT BENE_ID
    FROM beneficiary
    WHERE BENE_DEATH_DT IS NULL
      AND FLOOR(DATEDIFF(day, CONVERT(date, BENE_BIRTH_DT, 106), '2021-12-31') / 365.25) >= 6
),

-- -----------------------------------------------------------------------
-- Step 2: Mental illness inpatient discharges in 2021 (denominator)
-- Principal diagnosis must be F20–F99
-- -----------------------------------------------------------------------
mh_discharges AS (
    SELECT DISTINCT i.BENE_ID, CONVERT(date, i.CLM_THRU_DT, 106) AS discharge_dt
    FROM inpatient i
    INNER JOIN age_eligible a ON i.BENE_ID = a.BENE_ID
    WHERE i.CLM_LINE_NUM = 1
      AND CONVERT(date, i.CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
      AND i.PRNCPAL_DGNS_CD LIKE 'F%'
      AND SUBSTRING(i.PRNCPAL_DGNS_CD, 2, 2) BETWEEN '20' AND '99'
),

-- -----------------------------------------------------------------------
-- Step 3: All outpatient and carrier claims (follow-up visit pool)
-- -----------------------------------------------------------------------
followup_visits AS (
    SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) AS svc_dt FROM carrier
    UNION ALL
    SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) FROM outpatient
),

-- -----------------------------------------------------------------------
-- Step 4: 7-day numerator
-- -----------------------------------------------------------------------
followup_7 AS (
    SELECT DISTINCT d.BENE_ID
    FROM mh_discharges d
    INNER JOIN followup_visits f ON d.BENE_ID = f.BENE_ID
    WHERE f.svc_dt > d.discharge_dt
      AND f.svc_dt <= DATEADD(day, 7, d.discharge_dt)
),

-- -----------------------------------------------------------------------
-- Step 5: 30-day numerator
-- -----------------------------------------------------------------------
followup_30 AS (
    SELECT DISTINCT d.BENE_ID
    FROM mh_discharges d
    INNER JOIN followup_visits f ON d.BENE_ID = f.BENE_ID
    WHERE f.svc_dt > d.discharge_dt
      AND f.svc_dt <= DATEADD(day, 30, d.discharge_dt)
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    d.BENE_ID,
    d.discharge_dt,
    CASE WHEN f7.BENE_ID  IS NOT NULL THEN 1 ELSE 0 END AS followup_7_day,
    CASE WHEN f30.BENE_ID IS NOT NULL THEN 1 ELSE 0 END AS followup_30_day
FROM mh_discharges d
LEFT JOIN followup_7  f7  ON d.BENE_ID = f7.BENE_ID
LEFT JOIN followup_30 f30 ON d.BENE_ID = f30.BENE_ID
ORDER BY d.BENE_ID, d.discharge_dt;
