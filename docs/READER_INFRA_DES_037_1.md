# AIDM-DES-037.1 — Dedicated PEQUOD Windows catalogue reader infrastructure

**COSTA, 27 November 2026. Development and CI evidence are not proof of live PEQUOD execution.**

## Failure observed by BON

- PEQUOD\AIDM_Reader local nonadministrator account and Windows-authenticated SQL user already exist.
- SQL EXECUTE AS LOGIN showed sysadmin=0, db_owner=0, SELECT=1 and INSERT/UPDATE/DELETE/ALTER=0 on Rules.Monster, Test.MonsterTestScenario and Test.MonsterTestCase.
- The actual reader Python process failed to launch from an SSH admin session; a cmd.exe probe exited 0xC0000142; the historical AIDM-Reader-Probe scheduled task reported 267011 (0x41303, **task has not yet run**). No actual OS-token-based SQL connection was proved. Do not assume this was a failed Python query.
- Never replace the real reader login with the privileged owner account or SQL Server mixed-mode authentication merely to pass UAT.

## Deliverables

1. aidm/reader_probe.py: independent Windows token evidence (whoami /user), effective SQL integrated identity, database role and permissions audit, three TOP (0) SELECTs, optionally exact-source reviewed MonsterCatalogue and normalized test-case smoke. It uses fixed SQL only, no DnD writes.
2. scripts/reader-infra/Invoke-ReaderProof.ps1: owner-admin *setup only*. Confirms the reader is not local administrator; requires a shared Python installation, copies reviewed Python to private ProgramData runtime (reader read+execute, not modify), prompts securely for local reader account password, registers a LIMITED one-shot Scheduled Task, verifies task principal, starts/polls, matches report SHA and source SHA, and removes the temporary task.
3. scripts/reader-infra/Get-ReaderDiagnostics.ps1: read-only original/new Task Scheduler status and sanitized Operational event IDs without action strings, exception messages, credentials or SQL errors.
4. scripts/reader-infra/Remove-ReaderProbeTask.ps1: opt-in cleanup of exactly the old/new temporary task. It does not modify SQL permissions, source records, test records, account, runtime or reports.
5. aidm/test/test_reader_probe.py: fake-Windows identity and fake-DB-API tests; no live Windows credential, SQL Server or pyodbc dependency in ordinary CI.

## Actual local setup — owner/admin must run on PEQUOD

**Remote GitHub code cannot log into or change your local Windows installation.**

In an approved elevated PowerShell session (including an interactive SSH terminal if supported), first verify the existing reader account, local SQL Server instance and installed ODBC Driver 17/18 name.

Install or choose a **shared** Python 3.12 interpreter with pyodbc in C:\Program Files or an administrator-controlled directory under C:\ProgramData, NOT under C:\Users\glade or any personal profile. A dedicated venv such as C:\ProgramData\AIDM\ReaderPython\Scripts\python.exe is suitable only once its code is writable exclusively by SYSTEM/Administrators and readable/executable by the reader. If Group Policy blocks batch logon, the administrator must review the reader-specific Log on as a batch job right; do not change broad security policy or add the reader to Administrators.

Use a clean exact-source checkout of the DES-037.1 PR branch, then run the following *example* commands. The SQL instance and Python path here are **illustrative**, not asserted current PEQUOD facts.

~~~powershell
.\scripts\reader-infra\Get-ReaderDiagnostics.ps1 -TaskName AIDM-Reader-Probe

.\scripts\reader-infra\Invoke-ReaderProof.ps1 -RepoRoot 'C:\Development\aidm-0371' -PythonExe 'C:\ProgramData\AIDM\ReaderPython\Scripts\python.exe' -Server '.\SQLEXPRESS' -Driver 'ODBC Driver 17 for SQL Server'

.\scripts\reader-infra\Remove-ReaderProbeTask.ps1 -TaskName AIDM-Reader-Probe -WhatIf
.\scripts\reader-infra\Remove-ReaderProbeTask.ps1 -TaskName AIDM-Reader-Probe
~~~

Task Scheduler registers with a **secure interactive password prompt**; never supply account credentials in a chat, command-line argument, file, environment variable, issue or test report. The registration uses the supported Windows User/Password/RunLevel Limited parameter set. The owner admin creates the task, but the task PROCESS must run with the reader OS token. The task is removed after the attempt; historical AIDM-Reader-Probe is left for separate owner-controlled cleanup.

If no report is produced, inspect the diagnostic task state and TaskScheduler Operational event IDs. An unchanged 0x41303 sentinel means no task execution proved. A new failure code may reveal batch logon policy, Python DLL access or another operating-system blocker; do not bypass it.

## Attestation gates and safety

Only same-machine SQL Servers and Windows Integrated Authentication are supported. No UID, PWD or SQL login credentials; the temporary local-only ODBC connection explicitly trusts the local SQL Server certificate, which must not be copied into remote-server configurations.

The script checks actual process account and SID via Windows whoami, SQL ORIGINAL_LOGIN and SUSER_SNAME (both the dedicated reader), DnD database context, sysadmin/db_owner/db_datawriter all false, CONTROL/CREATE TABLE/ALTER ANY SCHEMA on the database false, SELECT true and INSERT/UPDATE/DELETE/ALTER/CONTROL false on all three source tables. It executes a TOP(0) SELECT of each source object and performs no mutations.

The optional source-backed *developer smoke*, running under the same restricted process, uses the SHA-pinned corrected catalogue.py and SqlServerReader, inspects four explicitly TEST_ONLY SourceChecked/inactive monsters ORC, GIANT_CENTIPEDE, CARRION_CRAWLER, GIANT_CRAB_SPIDER, the normal approved-only gate, and two specified normalized Orc scenarios ORC-T001-A/B with child tests. It requires ReadyForExecution=0, does not generate HP, approve monster versions, declare B1 readiness, or run combat. Data/source prose is never printed. A genuinely present approved version triggers owner review; no silent approvals.

A PASS requires the one-shot process to have executed, OS token + SQL login/grants true, exact clean source SHA, matching copied reader and catalogue SHA256, three tables accessible read-only, normalized developer smoke successful, and source-stamped JSON report in ProgramData\AIDM\Reader0371\Reports. Validate the report independently as the reader can write it; an admin captures its hash and preserves evidence. The report is NOT BON UAT acceptance.

## BON, ALEK and closing conditions

Once the actual PEQUOD restricted-process proof is PASS, BON independently reruns parent DES-001.7.9 UAT-01 (four-source field fidelity), UAT-02 (approval/version enforcement), and UAT-03 (normalized test scenarios/cases). BON records exact source SHA, process token evidence and fresh execution statuses in DnD_Test using the *separate owner/admin identity* for evidence writes. The reader has no DnD_Test writes. UAT-04/05 historical results are preserved. Parent UAT-06 needs separate BON retest following DES-001.7.9.1. Do not mark any blocked case PASS from simulated CI.

There is no schema/data migration in this infrastructure story, no mixed-mode workaround, no SourceChecked promotion or B1 fixture approval. Keep the original reader account and three-table grants. Confirm owner Actual Time, ALEK acceptance, and independently witnessed PEQUOD execution before DES-037.1 can be Complete. GitHub Actions is fake-token/driver regression only.
