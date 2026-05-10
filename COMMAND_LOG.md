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
# Total: ~940MB
