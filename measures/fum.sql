-- =============================================================================
-- Measure:     FUM — Follow-Up After Emergency Department Visit for Mental Illness
-- Description: Tracks whether members with an ED visit for a mental health
--              condition receive outpatient follow-up within 7 and 30 days.
-- Denominator: Members aged 6+ with an ED visit in 2021 that had a principal
--              mental illness diagnosis (ICD-10 F20-F99), excluding visits
--              that resulted in an inpatient admission on the same day or
--              the next day.
-- Numerator:   Two rates:
--                7-day  — member has an outpatient or carrier visit within
--                         7 days after the ED visit.
--                30-day — member has an outpatient or carrier visit within
--                         30 days after the ED visit.
-- Data sources: beneficiary, outpatient, carrier, inpatient
-- Measurement year: 2021
-- Direction:   Higher is better
-- Output:      One row per qualifying ED visit. followup_7_day and
--              followup_30_day are 1 if the member received follow-up.
--
-- NOTE on ED identification:
--   ED visits are identified via revenue center codes 0450-0459 and 0981
--   on outpatient claims. The outpatient table records one row per line
--   (CLM_LINE_NUM > 1 for service-line detail), so we deduplicate to one
--   ED encounter per member-date.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Age-eligible population (6+, alive at year end)
-- -----------------------------------------------------------------------
age_eligible AS (
    SELECT BENE_ID
    FROM beneficiary
    WHERE BENE_DEATH_DT IS NULL
      AND FLOOR(DATEDIFF(day, CONVERT(date, BENE_BIRTH_DT, 106), '2021-12-31') / 365.25) >= 6
),

-- -----------------------------------------------------------------------
-- Step 2: ED visits with mental health principal diagnosis in 2021
-- -----------------------------------------------------------------------
ed_mh_visits AS (
    SELECT DISTINCT o.BENE_ID, CONVERT(date, o.CLM_FROM_DT, 106) AS ed_dt
    FROM outpatient o
    INNER JOIN age_eligible a ON o.BENE_ID = a.BENE_ID
    WHERE CONVERT(date, o.CLM_FROM_DT, 106) BETWEEN '2021-01-01' AND '2021-12-31'
      AND o.REV_CNTR IN ('0450','0451','0452','0453','0454','0455',
                         '0456','0457','0458','0459','0981')
      AND o.PRNCPAL_DGNS_CD LIKE 'F%'
      AND SUBSTRING(o.PRNCPAL_DGNS_CD, 2, 2) BETWEEN '20' AND '99'
),

-- -----------------------------------------------------------------------
-- Step 3: Exclude ED visits followed by same/next-day inpatient admission
-- (those members were admitted from ED — FUH applies, not FUM)
-- -----------------------------------------------------------------------
ed_with_inpatient AS (
    SELECT DISTINCT e.BENE_ID, e.ed_dt
    FROM ed_mh_visits e
    INNER JOIN inpatient i
        ON  e.BENE_ID = i.BENE_ID
        AND i.CLM_LINE_NUM = 1
        AND CONVERT(date, i.CLM_FROM_DT, 106) BETWEEN e.ed_dt AND DATEADD(day, 1, e.ed_dt)
),
qualifying_ed AS (
    SELECT e.BENE_ID, e.ed_dt
    FROM ed_mh_visits e
    LEFT JOIN ed_with_inpatient x
        ON e.BENE_ID = x.BENE_ID AND e.ed_dt = x.ed_dt
    WHERE x.BENE_ID IS NULL
),

-- -----------------------------------------------------------------------
-- Step 4: Follow-up visit pool (carrier + outpatient)
-- -----------------------------------------------------------------------
followup_visits AS (
    SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) AS svc_dt FROM carrier
    UNION ALL
    SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) FROM outpatient
),

-- -----------------------------------------------------------------------
-- Step 5: 7-day numerator
-- -----------------------------------------------------------------------
followup_7 AS (
    SELECT DISTINCT q.BENE_ID, q.ed_dt
    FROM qualifying_ed q
    INNER JOIN followup_visits f ON q.BENE_ID = f.BENE_ID
    WHERE f.svc_dt > q.ed_dt
      AND f.svc_dt <= DATEADD(day, 7, q.ed_dt)
),

-- -----------------------------------------------------------------------
-- Step 6: 30-day numerator
-- -----------------------------------------------------------------------
followup_30 AS (
    SELECT DISTINCT q.BENE_ID, q.ed_dt
    FROM qualifying_ed q
    INNER JOIN followup_visits f ON q.BENE_ID = f.BENE_ID
    WHERE f.svc_dt > q.ed_dt
      AND f.svc_dt <= DATEADD(day, 30, q.ed_dt)
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    q.BENE_ID,
    q.ed_dt,
    CASE WHEN f7.BENE_ID  IS NOT NULL THEN 1 ELSE 0 END AS followup_7_day,
    CASE WHEN f30.BENE_ID IS NOT NULL THEN 1 ELSE 0 END AS followup_30_day
FROM qualifying_ed q
LEFT JOIN followup_7  f7  ON q.BENE_ID = f7.BENE_ID  AND q.ed_dt = f7.ed_dt
LEFT JOIN followup_30 f30 ON q.BENE_ID = f30.BENE_ID AND q.ed_dt = f30.ed_dt
ORDER BY q.BENE_ID, q.ed_dt;
