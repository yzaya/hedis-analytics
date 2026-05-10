# COMMAND LOG
Every command run in this project, timestamped, in order.

---

## Phase 1 — Git and GitHub Setup
**Date: 2026-05-10**

[2026-05-10 13:00] TERMINAL
$ sudo mkdir -p -m 755 /etc/apt/keyrings

[2026-05-10 13:01] TERMINAL
$ wget -qO /tmp/githubcli-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg

[2026-05-10 13:02] TERMINAL
$ sudo cp /tmp/githubcli-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg

[2026-05-10 13:03] TERMINAL
$ sudo nano /etc/apt/sources.list.d/github-cli.list
# Added: deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main

[2026-05-10 13:04] TERMINAL
$ sudo apt-get update && sudo apt-get install gh -y

[2026-05-10 13:05] TERMINAL
$ gh --version
# gh version 2.92.0 (2026-04-28)

[2026-05-10 13:27] TERMINAL
$ gh auth login
# Selected: GitHub.com, SSH, uploaded ~/.ssh/github.pub, title: GitHub CLI, Login with a web browser
# Authentication complete.

[2026-05-10 13:28] TERMINAL
$ git init

[2026-05-10 13:28] TERMINAL
$ git config user.name "yzaya"

[2026-05-10 13:29] TERMINAL
$ git config user.email "104730696+yzaya@users.noreply.github.com"

[2026-05-10 13:30] TERMINAL
$ gh repo create hedis-analytics --private --source=. --remote=origin
# ✓ Created repository yzaya/hedis-analytics on github.com
# ✓ Added remote git@github.com:yzaya/hedis-analytics.git

[2026-05-10 13:31] TERMINAL
$ nano .gitignore
# Added: CONTEXT.md, data/raw/, data/processed/

[2026-05-10 13:35] TERMINAL
$ mkdir -p schema etl measures results docs data/raw data/processed

[2026-05-10 13:36] TERMINAL
$ git add .gitignore

[2026-05-10 13:37] TERMINAL
$ git commit -m "[SETUP] Initialize project structure and gitignore"
# [main (root-commit) 74af64b] [SETUP] Initialize project structure and gitignore
# 1 file changed, 3 insertions(+)

[2026-05-10 13:40] TERMINAL
$ ssh-keygen -t ed25519 -C "104730696+yzaya@users.noreply.github.com" -f ~/.ssh/github
# Generated new ED25519 key, overwrote old key
# No passphrase set

[2026-05-10 13:41] TERMINAL
$ ssh-add ~/.ssh/github
# Identity added: /home/yzaya/.ssh/github (104730696+yzaya@users.noreply.github.com)

[2026-05-10 13:42] TERMINAL
$ gh ssh-key add ~/.ssh/github.pub --title "linux"
# ✓ Public key added to your account

[2026-05-10 13:43] TERMINAL
$ git push -u origin main
# Branch 'main' set up to track remote branch 'main' from 'origin'.
# Push successful.

---

## Phase 2 — Install and Verify MSSQL Server
**Date: 2026-05-10**

[2026-05-10 14:00] TERMINAL
$ curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg

[2026-05-10 14:01] TERMINAL
$ curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list

[2026-05-10 14:02] TERMINAL
$ sudo apt-get update && sudo apt-get install -y mssql-server
# Failed: NO_PUBKEY EB3E94ADBE1229CF — signing key not linked to repo

[2026-05-10 14:05] TERMINAL
$ sudo gpg --dearmor -o /usr/share/keyrings/mssql-server.gpg /usr/share/keyrings/microsoft-prod.gpg

[2026-05-10 14:06] TERMINAL
$ sudo nano /etc/apt/sources.list.d/mssql-server-2022.list
# Updated entry to: deb [signed-by=/usr/share/keyrings/mssql-server.gpg] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main

[2026-05-10 14:07] TERMINAL
$ sudo apt-get update && sudo apt-get install -y mssql-server
# Installed successfully

[2026-05-10 14:20] TERMINAL
$ sudo /opt/mssql/bin/mssql-conf setup
# Selected: Developer Edition, accepted license, set SA password
# Setup completed successfully. SQL Server started.

[2026-05-10 14:21] TERMINAL
$ systemctl status mssql-server
# Active: active (running)

[2026-05-10 14:22] TERMINAL
$ curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
$ curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-tools.list
$ sudo apt-get update && sudo apt-get install -y mssql-tools18 unixodbc-dev

[2026-05-10 14:23] TERMINAL
$ echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc && source ~/.bashrc

[2026-05-10 14:24] TERMINAL
$ sqlcmd -?
# sqlcmd version 18.6.0002.1 — confirmed working

[2026-05-10 14:25] TERMINAL
$ sqlcmd -S localhost -U SA -Q "SELECT @@VERSION" -C
# SQL Server 2022 Developer Edition (64-bit) on Linux (Pop!_OS 22.04 LTS)
# (1 rows affected)

[2026-05-10 14:30] TERMINAL
$ curl -L "https://azuredatastudio-update.azurewebsites.net/latest/linux-deb-x64/stable" -o ~/Downloads/azuredatastudio.deb
# Failed: Could not resolve host

$ curl -L "https://go.microsoft.com/fwlink/?linkid=2215528" -o ~/Downloads/azuredatastudio.deb
# Downloaded HTML page instead of .deb — Azure Data Studio installation abandoned
# Decision: use sqlcmd only for this project

---

## Phase 3 — Download CMS Synthetic Medicare Data
**Date: 2026-05-10**

[2026-05-10 14:49] BROWSER
# Downloaded from https://data.cms.gov/collection/synthetic-medicare-enrollment-fee-for-service-claims-and-prescription-drug-event
# Files: beneficiary_2025.csv, All FFS Claims.zip, pde.csv
# Saved to ~/Downloads/

[2026-05-10 14:50] TERMINAL
$ mv ~/Downloads/beneficiary* ~/Projects/hedis-analytics/data/raw/
$ mv ~/Downloads/*FFS* ~/Projects/hedis-analytics/data/raw/
$ mv ~/Downloads/pde* ~/Projects/hedis-analytics/data/raw/

[2026-05-10 14:51] TERMINAL
$ unzip ~/Projects/hedis-analytics/data/raw/'All FFS Claims.zip' -d ~/Projects/hedis-analytics/data/raw/
# Extracted: carrier.csv, dme.csv, hha.csv, hospice.csv, inpatient.csv, outpatient.csv, snf.csv

[2026-05-10 14:52] TERMINAL
$ rm ~/Projects/hedis-analytics/data/raw/'All FFS Claims.zip'

[2026-05-10 14:53] TERMINAL
$ ls -lh ~/Projects/hedis-analytics/data/raw/
# beneficiary_2025.csv  3.2M
# carrier.csv           444M
# dme.csv                37M
# hha.csv               2.1M
# hospice.csv           4.4M
# inpatient.csv          34M
# outpatient.csv        321M
# pde.csv                87M
# snf.csv               9.5M
# Total: ~942MB

---

## Phase 4 — Load Data into SQL Server
**Date: 2026-05-10**

[2026-05-10 15:30] TERMINAL
$ export SQLCMDPASSWORD=<sa_password>
# Set for session — clears on terminal close

[2026-05-10 15:31] TERMINAL
$ sqlcmd -S localhost -U SA -C -i /home/yzaya/Projects/hedis-analytics/schema/create_tables.sql
# Changed database context to 'hedis'
# All 9 tables created successfully

[2026-05-10 15:32] TERMINAL
$ sqlcmd -S localhost -U SA -C -Q "USE hedis; DROP TABLE IF EXISTS beneficiary, inpatient, outpatient, carrier, dme, hha, hospice, snf, pde;"
# Tables dropped — schema had VARCHAR sizing errors, needed to be widened

[2026-05-10 15:33] TERMINAL
$ sqlcmd -S localhost -U SA -C -i /home/yzaya/Projects/hedis-analytics/schema/create_tables.sql
# Msg 1801: Database 'hedis' already exists — expected, ignored
# All 9 tables recreated with corrected column sizes

[2026-05-10 15:34] TERMINAL
$ sqlcmd -S localhost -U SA -C -Q "USE hedis; SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';"
# 9 tables confirmed: beneficiary, inpatient, outpatient, carrier, dme, hha, hospice, snf, pde

[2026-05-10 15:35] PYTHON
$ python3 /home/yzaya/Projects/hedis-analytics/etl/load_cms_data.py
# beneficiary   10,000 rows
# inpatient     58,066 rows
# outpatient   575,092 rows
# carrier    1,121,004 rows
# dme          103,828 rows
# hha            6,215 rows
# hospice       12,107 rows
# snf           12,548 rows
# pde          515,520 rows
# All files loaded successfully. Connection closed.

[2026-05-10 16:00] TERMINAL
$ wc -l /home/yzaya/Projects/hedis-analytics/data/raw/*.csv
#     10001 beneficiary_2025.csv
#   1121005 carrier.csv
#    103829 dme.csv
#      6216 hha.csv
#     12108 hospice.csv
#     58067 inpatient.csv
#    575093 outpatient.csv
#    515521 pde.csv
#     12549 snf.csv
#   2414389 total
# All row counts match ETL output exactly (lines - 1 header = rows loaded)

---

## Phase 5 Prep — Switch to 2021 Beneficiary File
**Date: 2026-05-10**

[2026-05-10 16:30] BROWSER
# Downloaded beneficiary_2021.csv from CMS synthetic Medicare data portal
# Saved to ~/Downloads/

[2026-05-10 16:31] TERMINAL
$ mv ~/Downloads/beneficiary_2021.csv /home/yzaya/Projects/hedis-analytics/data/raw/

[2026-05-10 16:32] TERMINAL
$ wc -l /home/yzaya/Projects/hedis-analytics/data/raw/beneficiary_2021.csv
#  8247 beneficiary_2021.csv
# 8247 lines - 1 header = 8,246 rows

[2026-05-10 16:33] TERMINAL
$ /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -C -Q "USE hedis; TRUNCATE TABLE beneficiary;"
# Changed database context to 'hedis'.

[2026-05-10 16:34] PYTHON
$ python3 [inline load script — beneficiary_2021.csv only]
# Connected.
# Rows before: 0
# Rows after:  8246
# Inserted:    8246
# Done.

[2026-05-10 16:35] TERMINAL
$ /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -C -Q "USE hedis; SELECT TOP 3 BENE_ID, BENE_BIRTH_DT, BENE_ENROLLMT_REF_YR, BENE_DEATH_DT FROM beneficiary;"
# BENE_ENROLLMT_REF_YR = 2021 confirmed
# BENE_DEATH_DT = NULL for sampled rows
# Row count verified: 8,246 matches CSV (8247 lines - 1 header)
