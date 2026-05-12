-- =============================================================================
-- Measure:     IET — Initiation and Engagement of Substance Use Disorder
--                     Treatment
-- Description: Two-part measure. Tracks (a) whether members with a new SUD
--              diagnosis begin treatment promptly, and (b) whether they
--              continue with additional treatment encounters in the
--              following month.
-- Denominator: Members aged 13+ with a new SUD episode in 2021 (ICD-10
--              F10-F19) — defined as the first SUD diagnosis with no prior
--              SUD claim in the 60 days before the index date.
-- Numerator:
--   Initiation: At least one SUD treatment service within 14 days of the
--               index diagnosis (counts the index visit if it includes a
--               treatment HCPCS).
--   Engagement: At least two additional SUD treatment services within
--               34 days following the initiation date.
-- Data sources: beneficiary, inpatient, outpatient, carrier
-- Measurement year: 2021
-- Direction:   Higher is better
-- Output:      One row per member with new SUD episode in 2021. Columns:
--                index_dt, initiation_dt, initiated (0/1), engaged (0/1).
--
-- NOTE on SUD treatment identification:
--   Treatment is identified two ways: (1) HCPCS codes commonly used for
--   SUD services (H0001-H0050 series, 90791-90792 psychiatric eval,
--   90832-90838 psychotherapy, 99408-99409 SBIRT, 90853 group therapy);
--   (2) any subsequent claim with an F10-F19 diagnosis. Either pathway
--   qualifies. The official HEDIS spec uses a specific value set; the
--   pattern below is a reasonable approximation for claims-only data.
-- =============================================================================

USE hedis;

WITH

-- -----------------------------------------------------------------------
-- Step 1: Age-eligible population (13+, alive at year end)
-- -----------------------------------------------------------------------
age_eligible AS (
    SELECT BENE_ID
    FROM beneficiary
    WHERE BENE_DEATH_DT IS NULL
      AND FLOOR(DATEDIFF(day, CONVERT(date, BENE_BIRTH_DT, 106), '2021-12-31') / 365.25) >= 13
),

-- -----------------------------------------------------------------------
-- Step 2: All SUD diagnosis claims across the available history
-- -----------------------------------------------------------------------
sud_dx_all AS (
    SELECT BENE_ID, svc_dt FROM (
        SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) AS svc_dt, PRNCPAL_DGNS_CD AS dx FROM inpatient
        UNION ALL
        SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106), PRNCPAL_DGNS_CD FROM outpatient
        UNION ALL
        SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106), LINE_ICD_DGNS_CD FROM carrier
    ) d
    WHERE dx LIKE 'F1%'
      AND LEN(dx) >= 2
      AND SUBSTRING(dx, 2, 2) BETWEEN '10' AND '19'
),

-- -----------------------------------------------------------------------
-- Step 3: New SUD episodes in 2021 (first dx in 2021 with no SUD claim
-- in the prior 60 days)
-- -----------------------------------------------------------------------
sud_first_2021 AS (
    SELECT s.BENE_ID, MIN(s.svc_dt) AS index_dt
    FROM sud_dx_all s
    INNER JOIN age_eligible a ON s.BENE_ID = a.BENE_ID
    WHERE s.svc_dt BETWEEN '2021-01-01' AND '2021-12-31'
    GROUP BY s.BENE_ID
),
new_sud_episodes AS (
    SELECT f.BENE_ID, f.index_dt
    FROM sud_first_2021 f
    LEFT JOIN sud_dx_all prior
        ON  f.BENE_ID = prior.BENE_ID
        AND prior.svc_dt >= DATEADD(day, -60, f.index_dt)
        AND prior.svc_dt <  f.index_dt
    WHERE prior.BENE_ID IS NULL
),

-- -----------------------------------------------------------------------
-- Step 4: SUD treatment events — HCPCS-based or subsequent SUD dx claim
-- -----------------------------------------------------------------------
treatment_events AS (
    -- HCPCS-based SUD treatment in carrier/outpatient
    SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) AS svc_dt FROM carrier
    WHERE HCPCS_CD IN (
        'H0001','H0002','H0003','H0004','H0005','H0006','H0007','H0008',
        'H0009','H0010','H0011','H0012','H0013','H0014','H0015','H0016',
        'H0017','H0018','H0019','H0020','H0022','H0047','H0049','H0050',
        '90791','90792','90832','90834','90837','90838','90853',
        '99408','99409','G0396','G0397','G0443'
    )
    UNION ALL
    SELECT BENE_ID, CONVERT(date, CLM_FROM_DT, 106) FROM outpatient
    WHERE HCPCS_CD IN (
        'H0001','H0002','H0003','H0004','H0005','H0006','H0007','H0008',
        'H0009','H0010','H0011','H0012','H0013','H0014','H0015','H0016',
        'H0017','H0018','H0019','H0020','H0022','H0047','H0049','H0050',
        '90791','90792','90832','90834','90837','90838','90853',
        '99408','99409','G0396','G0397','G0443'
    )
    UNION ALL
    -- SUD dx on a subsequent claim also counts as a treatment encounter
    SELECT BENE_ID, svc_dt FROM sud_dx_all
),

-- -----------------------------------------------------------------------
-- Step 5: Initiation — any treatment event within 14 days of index dx
-- -----------------------------------------------------------------------
initiation AS (
    SELECT n.BENE_ID, n.index_dt, MIN(t.svc_dt) AS initiation_dt
    FROM new_sud_episodes n
    INNER JOIN treatment_events t
        ON  n.BENE_ID = t.BENE_ID
        AND t.svc_dt >= n.index_dt
        AND t.svc_dt <= DATEADD(day, 14, n.index_dt)
    GROUP BY n.BENE_ID, n.index_dt
),

-- -----------------------------------------------------------------------
-- Step 6: Engagement — 2+ additional treatment events within 34 days
-- after the initiation date (strict >, excluding the initiation event)
-- -----------------------------------------------------------------------
engagement_counts AS (
    SELECT i.BENE_ID, i.index_dt, COUNT(DISTINCT t.svc_dt) AS additional_events
    FROM initiation i
    INNER JOIN treatment_events t
        ON  i.BENE_ID = t.BENE_ID
        AND t.svc_dt >  i.initiation_dt
        AND t.svc_dt <= DATEADD(day, 34, i.initiation_dt)
    GROUP BY i.BENE_ID, i.index_dt
)

-- -----------------------------------------------------------------------
-- Member-level result
-- -----------------------------------------------------------------------
SELECT
    n.BENE_ID,
    n.index_dt,
    i.initiation_dt,
    CASE WHEN i.BENE_ID IS NOT NULL                            THEN 1 ELSE 0 END AS initiated,
    CASE WHEN COALESCE(e.additional_events, 0) >= 2            THEN 1 ELSE 0 END AS engaged
FROM new_sud_episodes n
LEFT JOIN initiation         i ON n.BENE_ID = i.BENE_ID AND n.index_dt = i.index_dt
LEFT JOIN engagement_counts  e ON n.BENE_ID = e.BENE_ID AND n.index_dt = e.index_dt
ORDER BY n.BENE_ID, n.index_dt;
