# Deploy unified three-table UAT registry from BONNIE on PEQUOD

These files were staged in `Database/migrations/uat_three_table/` on the permanent `bonnie` branch. They have NOT been run against PEQUOD.

## 1. Git Bash: fetch the exact branch in an isolated worktree

Do not disturb your active `C:/Development/aidm` checkout; `bonnie` currently diverges from `main`.

```bash
cd /c/Development/aidm
git fetch origin bonnie
git worktree add --detach /c/Development/aidm-bonnie-uat origin/bonnie
cd /c/Development/aidm-bonnie-uat/Database/migrations/uat_three_table
git rev-parse HEAD
```

If the worktree directory already exists, do not run `git worktree add` again; `cd` into it and confirm the SHA. Do not force-reset any branch.

## 2. Confirm the right SQL Server; back up both databases

In a PEQUOD Git Bash shell, using Windows Authentication:

```bash
sqlcmd -S PEQUOD -E -b -Q "SELECT @@SERVERNAME AS ServerName, @@VERSION AS SqlVersion; SELECT name FROM sys.databases WHERE name IN ('DnD','DnD_Test');"
```

Take and independently verify a backup of `DnD` and, if present, `DnD_Test` before proceeding. The SQL scripts are non-destructive, but a database/schema migration still warrants backups. The `Legacy` archive is kept automatically; it is not a substitute for a backup.

## 3. Apply in order, stop on errors

```bash
sqlcmd -S PEQUOD -d master   -E -b -I -i 00_Bootstrap_DnD_Test.sql
sqlcmd -S PEQUOD -d DnD_Test -E -b -I -i 01_Migrate_To_Three_UAT_Tables.sql
sqlcmd -S PEQUOD -d DnD_Test -E -b -I -i 02_Seed_DES_006_5_UAT.sql
sqlcmd -S PEQUOD -d DnD_Test -E -b -I -i 03_Verify_Three_Table_Registry.sql
```

Check each exit code or run the `&&` chain in Git Bash to automatically stop on the first failing step. If your SQL Server uses a named instance, replace `PEQUOD` with its actual connection name.

## 4. Acceptance criteria

Exactly three tables under `DnD_Test.Test`: `UATTestScenario`, `UATTestCase`, `UATTestExecution`. Nine DES-006.5 cases exist as specifications, UAT-09 blocked, no fabricated PASS executions, and zero orphan rows. Prior `DnD.Test` source tables stay intact. If earlier bundle deployed, old `DnD_Test.Test` tables move to `DnD_Test.Legacy`.

## 5. Scope cautions

Do not run legacy `Database/tables/MonsterTestScenario.sql` or its old inserts against the new `DnD_Test` target; update loader/seed SQL to the new unified names under a separately tested change. Source tables in `DnD` are deliberately left for rollback, and this branch commit has not modified the monster application loader. The migration is written for SQL Server 2016+ but has not been database-executed here.

If a migration step fails, preserve the full `sqlcmd` output and stop; do not blindly rerun the follow-on scripts.