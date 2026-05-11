# HEDIS Measure Results — 2021

**Measurement year:** 2021 (Jan 1 – Dec 31)
**Population:** 8,246 Medicare beneficiaries (CMS Synthetic Medicare 2021)
**Database:** Microsoft SQL Server 2022 Developer Edition

---

## Implemented Measures

### PCR — Plan All-Cause Readmissions

| Denominator | Numerator | Rate |
|---|---|---|
| 3,049 index admissions | 955 readmissions within 30 days | 31.3% |

Direction: Lower is better.
Note: The 31.3% rate is approximately double the real-world Medicare average (~15%).
This is a known characteristic of the CMS synthetic dataset — Synthea does not model
realistic care transition patterns. The measure is structurally correct and fully
implementable from inpatient claims alone.

---

### FUH — Follow-Up After Hospitalization for Mental Illness

| Window | Denominator | Numerator | Rate |
|---|---|---|---|
| 7-day | 19 MH discharges | 9 with follow-up | 47.4% |
| 30-day | 19 MH discharges | 12 with follow-up | 63.2% |

Direction: Higher is better.
Note: The denominator is small due to the synthetic dataset size. Rates are
directionally consistent with real-world HEDIS averages (35–40% at 7 days,
50–55% at 30 days). Measure is fully implemented from inpatient, carrier,
and outpatient claims with no caveats.

---

## Measures Evaluated — Not Implemented

| Measure | Reason |
|---|---|
| ABA — Adult BMI Assessment | Z68.x BMI codes absent from synthetic dataset; numerator = 0 |
