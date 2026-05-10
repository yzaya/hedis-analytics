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
