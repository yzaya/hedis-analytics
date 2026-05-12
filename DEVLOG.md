# DEVLOG
Narrative log of decisions, problems encountered, and how they were solved.
Organized by phase and date.

---

## Phase 1 — Git and GitHub Setup
**Date: 2026-05-10**

### What was done
Set up version control for the project before any other tooling. Git was
initialized locally, the GitHub repository was created as private, and the
initial commit was pushed.

### Decisions made

**Git before MSSQL** — The original plan had MSSQL installation as Phase 1.
This was changed so that Git and GitHub are set up first. Reason: everything
that gets built should be tracked from the start, including the schema,
ETL scripts, and measure SQL files as they are written.

**Private repo** — The repository was created as private with the option to
make it public later. The project is intended as an interview submission, so
visibility will be reviewed before sharing the link.

**CONTEXT.md gitignored** — CONTEXT.md contains internal project context
including the interview target, personal website details, and server paths.
It was added to .gitignore to keep it out of the repo. A polished README
will serve as the public-facing project documentation.

**SSH over HTTPS** — SSH was chosen for the git protocol during gh auth login.
This avoids password prompts on every push. A new ED25519 key was generated
after the original key's passphrase was forgotten. The new key has no
passphrase, which is acceptable for a personal dev machine.

**SSH key titled "linux"** — When uploading the new public key to GitHub via
gh, it was titled "linux" to identify the machine it belongs to.

### Problems encountered

**gh CLI not installed** — The GitHub CLI (gh) was not installed. It was
installed via the official apt repository method. The install command kept
splitting across lines in the terminal, requiring the steps to be broken out
individually and the apt sources file to be written via nano.

**sudo not available in Claude Code session** — Commands requiring sudo could
not be run via the Claude Code ! prefix because sudo requires an interactive
terminal for password input. All commands were run in a separate terminal
instead. This is the established workflow for this project going forward.

**Forgotten SSH passphrase** — The existing ~/.ssh/github key had a passphrase
that was no longer known. A new ED25519 key was generated, overwriting the
old one, and uploaded to GitHub with the title "linux".

### State at end of phase
- Git repo initialized at /home/yzaya/Projects/hedis-analytics
- GitHub repo created: yzaya/hedis-analytics (private)
- Remote origin set to git@github.com:yzaya/hedis-analytics.git
- Initial commit pushed: [SETUP] Initialize project structure and gitignore
- Project directory structure in place: schema/, etl/, measures/, results/,
  docs/, data/raw/, data/processed/
- .gitignore excludes: CONTEXT.md, data/raw/, data/processed/

---

## Phase 2 — Install and Verify MSSQL Server
**Date: 2026-05-10**

### What was done
Installed Microsoft SQL Server 2022 Developer Edition and mssql-tools18
(sqlcmd) on Pop!_OS. Verified the instance is running and accepting
connections via a test query.

### Decisions made

**sqlcmd over Azure Data Studio** — Azure Data Studio was originally planned
as the SQL client. It was dropped in favor of sqlcmd for this project.
Reason: sqlcmd is sufficient for writing and running SQL files from the
terminal, keeps the setup leaner, and Azure Data Studio's download URL was
unreliable during setup. If a GUI becomes necessary it can be added later.
CONTEXT.md updated to reflect this.

### Problems encountered

**GPG key not applied to MSSQL repo** — The initial apt update failed because
the Microsoft signing key was not properly linked to the MSSQL repository.
Fixed by re-running gpg --dearmor to produce a separate keyring file and
updating the sources list entry with a signed-by reference.

**Azure Data Studio download failed** — The official update URL returned a
DNS resolution error. The Microsoft go.microsoft.com redirect returned an
HTML page instead of the .deb file. Installation was abandoned in favor of
sqlcmd only.

### State at end of phase
- SQL Server 2022 Developer Edition running on localhost
- Service enabled and starts automatically on boot
- sqlcmd 18.6.0002.1 installed and added to PATH via ~/.bashrc
- Test query confirmed: SELECT @@VERSION returns expected output
- Azure Data Studio not installed — sqlcmd used instead

---

## Phase 3 — Download CMS Synthetic Medicare Data
**Date: 2026-05-10**

### What was done
Downloaded all CMS synthetic Medicare data files from the CMS data portal
and stored them in data/raw/. Files are gitignored and will not be committed.

### Decisions made

**All FFS claims, not a subset** — Originally planned to download only
Carrier, Inpatient, and Outpatient. Decision changed to download all FFS
claim types (including DME, HHA, Hospice, SNF) to have a complete dataset.
Easier to have the data and not need it than to come back for it later.

**Beneficiary 2025, not 2024** — Originally planned measurement year was
2024. Changed to 2025 to use the most recent data available. CONTEXT.md
updated to reflect measurement year 2025.

**FFS data vintage is 2023** — The FFS claim files inside the zip are dated
April 2023. The beneficiary and PDE files are current (2025). This date
discrepancy should be reviewed in Phase 5 when we assess actual data coverage
against our measure definitions.

### State at end of phase
- All raw data files in /data/raw/ (gitignored)
- beneficiary_2025.csv — 3.2M
- carrier.csv          — 444M
- dme.csv              — 37M
- hha.csv              — 2.1M
- hospice.csv          — 4.4M
- inpatient.csv        — 34M
- outpatient.csv       — 321M
- pde.csv              — 87M
- snf.csv              — 9.5M
- Total: ~940MB unzipped

### Stretch goal noted
Docker containerization was considered — packaging SQL Server, the schema,
and ETL into a Docker image so anyone could pull and run the full project
without manual setup. Decided to finish the core project first and revisit
afterward. The COMMAND_LOG has everything needed to reproduce the SQL Server
setup from scratch if needed.

---

## Phase 4 — Load Data into SQL Server
**Date: 2026-05-10**

### What was done
Created the hedis database schema and loaded all 9 CMS CSV files into
SQL Server using the Python ETL script. Verified row counts after load.

### Decisions made

**VARCHAR sizing — widened after first run** — Initial schema used CHAR(1)
for single-character codes and VARCHAR(10) for date columns. The first ETL
run failed with "String data, right truncation" errors. Root causes identified
from the first data row: CMS dates are in "DD-Mon-YYYY" format (11 chars,
not 10), COUNTY_CD values can be 4 chars (not 3), and ENRL_SRC can be 3
chars (e.g. "CME"). Fixed by changing all CHAR(1) to VARCHAR(5), all
VARCHAR(10) to VARCHAR(15), and COUNTY_CD to VARCHAR(15). Tables were
dropped and recreated before re-running the ETL.

### Data observations

**Beneficiary has exactly 10,000 rows** — The round number is almost
certainly intentional. The CMS synthetic dataset is a controlled sample.
This should be reviewed in Phase 5 to understand whether 10,000 beneficiaries
provides sufficient population for all 10 candidate measures.

**Row counts after load:**
- beneficiary      10,000
- inpatient        58,066
- outpatient      575,092
- carrier       1,121,004
- dme             103,828
- hha               6,215
- hospice          12,107
- snf              12,548
- pde             515,520

### State at end of phase
- hedis database created in SQL Server
- All 9 tables created per schema/create_tables.sql
- All CMS CSV files loaded via etl/load_cms_data.py
- Row counts verified post-load
- Schema corrected for CMS date format and county code length

---

## Phase 5 Prep — Beneficiary File and Measurement Year Decision
**Date: 2026-05-10**

### What was done
After running exploratory queries in JupyterLab, the claims date range was
confirmed: all FFS tables span 01-Apr-2015 through 31-Oct-2022. The
beneficiary file was labeled 2025. This created a mismatch with the planned
measurement year of 2025.

Decision: change the measurement year to 2021. It is the most recent full
calendar year (Jan 1 – Dec 31) fully contained within the claims data window.

### Beneficiary file decision
The 2025 beneficiary file was replaced with the 2021 file. Reasons:

1. **BENE_DEATH_DT** — the 2025 file records deaths through 2025. Anyone who
   died between 2022 and 2025 would be incorrectly excluded from a 2021
   measurement year denominator. The 2021 file only records deaths through
   2021, which is correct for our measurement period.

2. **Enrollment status** — the 2021 file reflects who was enrolled in Medicare
   in 2021, which is the correct denominator population.

3. **Age** — AGE_AT_END_REF_YR is irrelevant regardless of which file is used.
   All measure queries will calculate age directly from BENE_BIRTH_DT.

### Data note
The 2021 beneficiary file has 8,246 rows vs 10,000 in the 2025 file. This is
expected — the enrolled population varies by year. The 2021 cohort is the
correct denominator for 2021 HEDIS measures.

### ETL update
etl/load_cms_data.py updated: beneficiary_2025.csv → beneficiary_2021.csv.
Beneficiary table truncated and reloaded. Row count verified: 8,246.

---

## Phase 5 — Measure Selection
**Date: 2026-05-10**

### What was done
Ran coverage checks in JupyterLab (testing/exploratory.ipynb) against the 10
original candidate measures, then evaluated 5 replacement candidates for the
measures that failed. Coverage checks examined three things for each measure:
(1) eligible population size by age/sex criteria, (2) ICD-10 diagnosis code
presence in 2021 claims, and (3) HCPCS/CPT procedure code presence in 2021
claims.

### Original 10 measures — results

**Kept (5):**
- COL — 4,860 eligible, 783 with colonoscopy/FOBT codes
- AAB — 7,817 eligible, 871 with bronchitis diagnosis
- ABA — 5,958 eligible, 453 with office visit codes
- AMR — 3,674 eligible, 333 with asthma diagnosis
- FUH — 8,123 eligible, 298 with mental illness diagnosis

**Dropped (5):**
- BCS — 2,071 eligible but only 7 members with mammography codes. Numerator
  would be effectively zero. Mammography HCPCS codes are sparse in the
  synthetic dataset.
- PPC — 0 members with delivery codes. Delivery CPT codes completely absent.
- URI — Only 46 members with URI diagnosis in 2021. Population too thin to
  produce a meaningful rate.
- CBP — 575 members with hypertension diagnosis, but measuring BP control
  requires actual blood pressure readings. This is clinical data from the EHR,
  not present in claims. Cannot implement the numerator.
- CDC — 716 members with diabetes diagnosis, but HbA1c test codes (83036,
  83037) are completely absent from carrier and outpatient across all years.
  Lab claims are not included in this synthetic dataset.

### Replacement candidates — results

Five replacement candidates were evaluated. All were selected for being purely
claims-based with no EHR or lab data requirement.

**Kept (3):**
- PCR — 3,049 inpatient index admissions in 2021, 955 readmissions within
  30 days (31.3%). Rate is higher than the real-world average (~15%) due to
  synthetic data characteristics, but the data is fully present and the
  measure is implementable.
- FUM — 205 members with mental health outpatient claims, 102 with mental
  health carrier claims in 2021. Natural complement to FUH which we are
  already implementing.
- IET — 370 members with new SUD diagnosis in 2021, 238 with follow-up within
  34 days. Strong coverage. SUD treatment initiation and engagement is a high-
  priority area in healthcare quality.

**Dropped (2):**
- LBP — 124 members with low back pain diagnosis (M54), but 0 members with
  lumbar imaging codes. Same pattern as BCS — the specific procedure codes
  are absent from the synthetic dataset.
- SAA — 0 members with schizophrenia-spectrum diagnosis (F20-F29). Codes are
  simply not present in the synthetic data, despite the broader mental illness
  category (F20-F99) being well represented for FUH and FUM.

### Current measure set — 7 confirmed
COL, AAB, AMR, FUH, PCR, FUM, IET

ABA was later attempted in Phase 6 and dropped — Z68.x BMI documentation codes
are absent from the synthetic dataset. See Phase 6 for details.

### Decisions made

**JupyterLab for exploratory queries** — All Phase 5 coverage checks were run
in JupyterLab via the exploratory notebook rather than sqlcmd. This keeps the
SQL visible and the results alongside the queries in one document.

**Measurement year confirmed as 2021** — All coverage queries filtered to
Jan 1 – Dec 31, 2021. Age calculated from BENE_BIRTH_DT as of Dec 31, 2021
throughout.

**Age calculation from BENE_BIRTH_DT** — All queries use
FLOOR(DATEDIFF(day, CONVERT(date, BENE_BIRTH_DT, 106), '2021-12-31') / 365.25)
rather than AGE_AT_END_REF_YR, which reflects the 2021 reference year of the
beneficiary file rather than a pre-calculated field.

### Notebook restructure (completed)
exploratory.ipynb was split into two purpose-specific notebooks. The original
file was left in place as a backup.

- testing/db_verification.ipynb — Phase 4 database verification queries:
  connection, row counts with expected values, beneficiary sample, age/sex
  distribution, claims date range check, inpatient dx codes, carrier HCPCS,
  PDE records.
- testing/measures.ipynb — Phase 5 measure coverage analysis: one section per
  measure (summary, coverage query, conclusion with numbers), preceded by a
  full landscape table of 18 implementable claims-based HEDIS measures.

### CBP correction
CBP (Controlling High Blood Pressure) was initially included in the claims-based
measures landscape table in measures.ipynb. It was removed after review.

Reason: the CBP numerator requires an actual blood pressure reading (< 140/90
mmHg). BP values are clinical data recorded in the EHR — they are not present
in claims. CBP cannot be implemented from claims data alone and does not belong
in a claims-only measures list. The CBP section and all associated cells were
deleted from measures.ipynb. The section remains in exploratory.ipynb (backup)
for reference.

### Conclusion corrections
All 14 conclusion cells in measures.ipynb had incorrect numbers. The conclusions
were written before the queries were actually run, using estimates carried over
from earlier exploratory work. The query outputs were correct throughout — the
conclusions simply did not reflect them.

Corrected numbers:

| Measure | Wrong | Correct |
|---|---|---|
| COL | 783 with screening codes | 724 |
| BCS | 7 with mammography codes | 2 |
| CDC | 716 with diabetes dx | 423 (age-eligible: 6,138) |
| AAB | 871 with bronchitis dx | 795 |
| AMR | 333 with asthma dx | 220 (157 with PDE) |
| FUH | 298 MH discharges | 19 (9 with 7-day follow-up) |
| URI | 46 with URI dx | 40 |
| ABA | 453 with office visit codes | 341 |

All conclusion cells and both summary tables updated to match query outputs.

### Alphabetical ordering
All measure content in measures.ipynb was sorted alphabetically by abbreviation:
landscape table, evaluated list, individual measure sections, and both summary
tables (confirmed and dropped). A stray section divider left over from the
original "Replacement Measure Candidates" header was also removed.

exploratory.ipynb moved to testing/archive/. .ipynb_checkpoints/ added to
.gitignore and removed from git tracking.

---

## Phase 6 — Measure Implementation
**Date: 2026-05-10**

### Measure selection
Three measures selected for Phase 6 implementation:

- **ABA** — Adult BMI Assessment
- **FUH** — Follow-Up After Hospitalization for Mental Illness
- **PCR** — Plan All-Cause Readmissions

Selected for domain variety (preventive, follow-up, utilization) and data source
variety (carrier/outpatient, inpatient/carrier, inpatient only). Starting with
ABA as the first implementation.

### ABA — Adult BMI Assessment (not implemented)
ABA was attempted first. The denominator built correctly — 341 members with
qualifying outpatient visits (ages 18-74). However, the numerator returned 0.
ICD-10 Z68.x BMI documentation codes are absent from the CMS synthetic dataset.
Synthea does not generate these codes, which is the same pattern observed with
BCS (mammography) and LBP (lumbar imaging) during Phase 5 coverage checks.

This should have been caught in Phase 5. The coverage check for ABA only
verified HCPCS visit codes — it did not check for Z68.x numerator codes.
Lesson: coverage checks need to verify both denominator and numerator code
availability. ABA was dropped. Conclusion documented in measures/aba.ipynb.

### PCR — Plan All-Cause Readmissions (implemented)
Fully implemented from inpatient claims. Denominator: 3,049 index admissions
in 2021. Numerator: 955 readmissions within 30 days. Rate: 31.3%.

The 31.3% rate is approximately double the real-world Medicare average (~15%).
This is a known characteristic of the synthetic data — Synthea does not model
realistic care transitions. The measure is structurally correct and would
produce a valid rate against real Medicare claims data.

Artifacts: measures/pcr.ipynb, measures/pcr.sql.

### FUH — Follow-Up After Hospitalization for Mental Illness (implemented)
Fully implemented from inpatient, carrier, and outpatient claims. No EHR data
required. Denominator: 19 members with a mental illness inpatient discharge
in 2021. Two rates produced:

- 7-day follow-up: 9 members (47.4%)
- 30-day follow-up: 12 members (63.2%)

The denominator is small due to the synthetic dataset size (8,246 members).
Rates are directionally consistent with real-world HEDIS averages of 35–40%
at 7 days and 50–55% at 30 days. This is the cleanest measure implemented —
no synthetic data limitations affect the numerator logic.

Artifacts: measures/fuh.ipynb, measures/fuh.sql.

### Member-level output and standalone SQL files
Both PCR and FUH produce member-level results — one row per index admission
(PCR) or MH discharge (FUH) with binary numerator flags. This format was
chosen over aggregate summaries because it supports downstream analysis and
demonstrates the measure at the member level, which is how health plans
actually use HEDIS data.

The standalone .sql files match the member-level output and can be run
directly via sqlcmd with no Python dependency. The notebooks include export
cells that write results to results/pcr_2021.csv and results/fuh_2021.csv
when run against the database.

### Results summary
results/summary.md created with a markdown table covering all implemented
measures and measures evaluated but not implemented.

---

## Phase 6 — Remaining Measure SQL (2026-05-11)

### What was done
Added SQL implementations for the five measures that passed Phase 5 coverage
but had not yet been built: COL, AAB, AMR, FUM, IET. Each measure now has a
standalone `.sql` file in `measures/` and a matching `.ipynb` with connection
cell, step-by-step query cells, conclusion, and export cell that writes
member-level CSV results to `results/`.

### Per-measure notes

**COL — Colorectal Cancer Screening**
Cleanest of the new five. HCPCS-based numerator (45378/45380/45385 for
colonoscopy, G0328/82270/82274 for FOBT/FIT) with a 2-year look-back window
(2020-2021). The Phase 5 single-year coverage check showed 724 members
screened in 2021 alone; the production query uses the 2-year window and
should produce a higher numerator.

**FUM — Follow-Up After ED Visit for Mental Illness**
Companion to FUH. ED visits identified via outpatient revenue center codes
0450-0459 and 0981 with a principal F20-F99 diagnosis. Excludes ED visits
that lead to an inpatient admission within 1 day (those cases roll up to
FUH). 7-day and 30-day follow-up numerators using the same UNION ALL pool
of carrier + outpatient claims as FUH.

**IET — Initiation and Engagement of SUD Treatment**
Two-part measure. Denominator is new SUD episodes in 2021 (first F10-F19
diagnosis with no SUD claim in the prior 60 days). Initiation = any
treatment within 14 days. Engagement = 2+ additional treatment events within
34 days after initiation. Treatment is identified two ways: (1) a list of
HCPCS codes commonly used for SUD services (H0001-H0050 series, 90791-90792,
90832-90838, 99408-99409, G0396/G0397, 90853); (2) any subsequent claim with
an F10-F19 diagnosis. Either pathway qualifies.

**AAB — Avoidance of Antibiotics for Acute Bronchitis**
Structural implementation with a documented NDC limitation. The HEDIS spec
uses NCQA's antibiotic NDC value set, which is not bundled with the CMS
synthetic data. The query uses a placeholder list of common antibiotic
labeler prefixes (Teva, Sandoz, Major Pharmaceuticals, Pliva, Hikma,
Aurobindo). The SQL header and notebook conclusion explicitly call out the
substitution point.

**AMR — Asthma Medication Ratio**
Same NDC mapping limitation as AAB. The ratio formula
`controller / (controller + reliever)` is implemented end to end; the
placeholder NDC lists cover common manufacturers of fluticasone, budesonide,
beclomethasone, mometasone (controllers) and albuterol, levalbuterol
(relievers). Replaceable with the NCQA value set in production.

### Decisions made

**Honest about NDC limitations** — Two options were considered for AAB and
AMR: drop them on grounds that the synthetic data lacks the required NDC
reference, or implement the structural logic with placeholder NDC lists and
document the substitution. The second was chosen because dropping
medication-management measures entirely from a HEDIS demo project would
under-represent a critical measure class. The placeholder approach
demonstrates correct SQL and honest documentation of the data boundary.

**Two-year look-back for COL only** — COL is the only measure in this batch
that uses a multi-year look-back. The Phase 5 coverage queries (which are
exploratory) all filtered to 2021 only, but the production COL query uses
2020-2021 because the HEDIS spec permits the 1-year prior look-back.

### Documentation

- `results/summary.md` updated to cover all 7 measures and the 8 dropped
  measures with reasons.
- `README.md` written from scratch as the polished GitHub landing page.

---

## Phase 7 / Phase 8 — Website Page (2026-05-11)

### What was done
Built `web/hedis.html` as a single-file dark-mode project page matching the
existing zk-praxis aesthetic (see `waves.html` for the template). The page
walks through the premise, stack, schema, measure-selection logic, and
implementations of PCR and FUH with embedded SQL code blocks and result
tables.

### Decisions made

**Page lives in this repo, not zk-praxis** — The file is written to
`web/hedis.html` inside this project so the HEDIS work stays contained.
Deployment to the zk-praxis droplet is a separate manual step (scp).

**Dark mode to match waves.html** — The index.html on zk-praxis uses a light
landing-page style, but the actual project pages (waves.html, neiss.html) use
the dark project-page template. The HEDIS page follows that pattern.

**Self-contained styling** — All CSS is inline in the HTML file. No external
dependencies, no JavaScript, no analytics call (the existing site loads
`/analytics/tracker.js`; that can be added on deploy if desired).

**Selective code excerpts** — The page shows the full PCR SQL and a partial
FUH excerpt rather than every measure's complete query. Readers who want the
rest can follow the GitHub link. This keeps the page focused on narrative
over code dump.

`web/hedis.html` subsequently moved to `archive/` on 2026-05-12 — page to be
rebuilt with updated results before deployment.
