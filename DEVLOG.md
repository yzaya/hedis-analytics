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
