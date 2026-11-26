# AIDM unified UAT registry — exactly three tables in `DnD_Test.Test`

**Prepared for PEQUOD / SQL Server 2016+; NOT executed on PEQUOD.**

## Final table design

1. **`DnD_Test.Test.UATTestScenario`** — one scenario/fixture, general or monster. Preserves the original monster-specific roster, count, surprise, scene, illustration, ruleset and source fields as nullable columns for non-monster tests. `ScenarioKind` distinguishes `MONSTER`, `STORY`, `GENERIC`.
2. **`DnD_Test.Test.UATTestCase`** — one versioned test specification per scenario; PK `(ScenarioCode,TestCaseCode,TestRevision)`. Keeps all original monster case codes and revisions; adds story refs, Given/When/Expected, fixture mode, test area, evidence reference and status. Imported monster cases have NULL `WhenText` and `FixtureMode` rather than fabricated values. `ReadyForExecution` and `SpecificationStatus` are NOT test results.
3. **`DnD_Test.Test.UATTestExecution`** — each recorded execution, with tester, exact SHA, observed result, environment, evidence and defect ref. FK to scenario+case+revision, retains any earlier numeric `ExecutionId`, no initial Pass results inserted.

The original `DnD.Test.MonsterTestScenario` and `DnD.Test.MonsterTestCase` remain untouched. Previous `DnD_Test.Test.MonsterTest*` and generic `UATTestCase/UATTestExecution` are *transferred* to `DnD_Test.Legacy` within the same transaction after all rows are copied, so final `DnD_Test.Test` has exactly three tables. The `Legacy` schema is a rollback/audit archive, not part of active UAT. Do not delete it until after a separately verified sign-off and backup. This is a staged, data-preserving replacement, not an in-place table rename: it is needed to reconcile the prior generic table with the monster-specific column contracts and existing execution FKs.

## Deployment on PEQUOD (Windows-authenticated SQL Server)

**Back up `DnD` and `DnD_Test` first**, especially if the prior bundle was already deployed; inspect current table/row counts. Review SQL scripts in an editor. Use the folder containing these scripts:

```powershell
sqlcmd -S PEQUOD -d master   -E -b -I -i 00_Bootstrap_DnD_Test.sql
sqlcmd -S PEQUOD -d DnD_Test -E -b -I -i 01_Migrate_To_Three_UAT_Tables.sql
sqlcmd -S PEQUOD -d DnD_Test -E -b -I -i 02_Seed_DES_006_5_UAT.sql
sqlcmd -S PEQUOD -d DnD_Test -E -b -I -i 03_Verify_Three_Table_Registry.sql
```

`-b` fails the shell command on SQL errors; `-I` enables quoted identifiers. Run after confirming the live SQL Server instance name is PEQUOD. The migration has `XACT_ABORT ON` and a transaction; conflicts abort without dropping old data. It refuses to silently archive unexpected tables, overwrite an existing `Legacy` archive, or accept conflicting duplicate monster definitions from two source databases. Re-running after a successful cutover is safe and reports an already unified registry. If the three-table registry already exists, rerun seed separately to insert any missing new UAT cases.

## Migration mapping

- From `DnD.Test.MonsterTestScenario` and/or `DnD_Test.Test.MonsterTestScenario` into `Test.UATTestScenario`: preserve `ScenarioCode`, source fields, revision and original timestamps. Original monster status `Executed`/`PassedUAT` is *not* treated as a new execution result; preserve in `LegacyScenarioStatus` while treating active specification as `Ready`.
- From old `MonsterTestCase`: preserve `ScenarioCode`, `TestCaseCode`, `TestRevision`, `TestName`, `GivenText`, `ExpectedText`, fixed dice, source refs, notes, timestamps; `WhenText` NULL until separately authored.
- From previous `DnD_Test.Test.UATTestCase`: use generic scenario `STORY:<LinkedStoryRef>`, preserve existing `TestCaseCode` and `TestRevision` and all acceptance fields; no case revision is silently rewritten.
- From previous `DnD_Test.Test.UATTestExecution`: preserve `ExecutionId` and evidence, add scenario key from the referenced original case's `LinkedStoryRef`; enforce new three-part FK.
- The included `DES-006.5` seeding script inserts **nine definitions only**, with `UAT-09` `Blocked`; does not insert any execution or imply a PASS.

**Conflict policy:** if two existing monster scenario/case records share a key but differ in content, migration aborts. Reconcile the sources instead of silently choosing one. The script is not an active test runner; it stores definitions and execution evidence.

## Integration changes required after migration

Update existing monster SQL seed/loader scripts that currently target `DnD.Test.MonsterTestScenario/MonsterTestCase` to use `DnD_Test.Test.UATTestScenario/UATTestCase`. Update inserts to include `ScenarioKind=N'MONSTER'` for scenario rows, and for cases use the composite scenario+case+revision PK. Do not keep running old monster DDL as part of the canonical test deployment. Rules/monster catalogues stay in `DnD.Rules`. Any code with a `DnD.Test` connection should be updated and tested, then the archive can be evaluated for removal by explicit approval. This bundle changes the SQL schema only; it does not modify AIDM Python loaders or GitHub's seed scripts.

## Safety and limitations

- This ChatGPT environment cannot connect to your private SQL Server on PEQUOD; **no deployment is claimed**.
- This is a proposed, non-destructive SQL Server migration; **review and execute first against a restored/test instance** before production-like local data. SQL Server-specific DDL and transfer behaviour are not database-executed in this environment.
- Source scripts inspected: AIDM `main` `Database/tables/MonsterTestScenario.sql`, `MonsterTestCase.sql`, `Database/database/Test.sql`, and prior `AIDM_TestDB_UAT_bundle` SQL scripts.