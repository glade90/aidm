/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestCases_Normalize_v0_2_0.sql
Repository Path : Database/tables/migrations/MonsterTestCases_Normalize_v0_2_0.sql
Project         : Golden Braid / AIDM
Purpose         : Non-destructive move from legacy scenario TestCasesJson
                  to one relational Rules.MonsterTestCase row per test.
Target Server   : PEQUOD SQL Server 2016+, DnD database
Version         : 0.2.0 (OWNER REVIEW)
Created         : 2026-11-21
Dependencies    : Existing Rules.MonsterTestScenario (v0.1 or v0.2);
                  CREATE Rules.MonsterTestCase FIRST.
===============================================================================
UPGRADE
- If you have NOT created the scenario table yet: do NOT run migration.
  Execute latest MonsterTestScenario.sql, scenario seed, MonsterTestCase.sql,
  then MonsterTestCase seed (see final handoff).
- If you HAVE created scenario table with embedded JSON:
  1. Create MonsterTestCase.sql
  2. Run THIS migration: import ALL legacy cases into child, make legacy
     TestCasesJson nullable for new encounter-only records.
  3. Run new child test-case seed (skips existing cases), as needed.
- Legacy JSON is intentionally left IN PLACE as read-only historical backup;
  it is NOT the editable source of truth after migration.
- Existing case definitions in child are NEVER overwritten. If custom
  cases were present in old JSON, they are retained and imported.
- The source JSON must be an ARRAY of objects with test_id, phase, given and
  expected. Unknown custom JSON keys are preserved in AdditionalDataJson.
- On unexpected legacy payload format or duplicated keys, transaction rolls
  back rather than silently losing data. Requires DnD compatibility >=130
  for OPENJSON support.
===============================================================================
*/
USE [DnD];
GO

IF OBJECT_ID(N'Rules.MonsterTestScenario', N'U') IS NULL
    THROW 56610, 'Rules.MonsterTestScenario missing. Run its v0.2 CREATE script instead.', 1;
IF OBJECT_ID(N'Rules.MonsterTestCase', N'U') IS NULL
    THROW 56611, 'Rules.MonsterTestCase missing. Create child table before migration.', 1;
IF (SELECT [compatibility_level] FROM sys.databases WHERE [name] = DB_NAME()) < 130
    THROW 56612, 'OPENJSON requires DnD database compatibility level 130 or higher. Do not change compatibility without owner review.', 1;
GO
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    -- Validate all nonempty historical arrays before any schema/data edit.
    IF EXISTS
    (
        SELECT 1
        FROM [Rules].[MonsterTestScenario] AS s
        WHERE s.[TestCasesJson] IS NOT NULL
          AND LEFT(LTRIM(s.[TestCasesJson]), 1) <> N'['
    )
        THROW 56613, 'Legacy TestCasesJson is not an array; inspect before migration.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [Rules].[MonsterTestScenario] AS s
        CROSS APPLY OPENJSON(s.[TestCasesJson]) AS j
        OUTER APPLY OPENJSON(j.[value]) WITH
        (
            [test_id] NVARCHAR(80) '$.test_id',
            [phase] NVARCHAR(40) '$.phase',
            [given] NVARCHAR(MAX) '$.given',
            [expected] NVARCHAR(MAX) '$.expected'
        ) AS p
        WHERE p.[test_id] IS NULL OR LEN(p.[test_id]) = 0
           OR p.[phase] IS NULL
           OR p.[phase] NOT IN
                (N'ENCOUNTER', N'COMBAT', N'COMBAT_HANDOFF',
                 N'DEFERRED_LIFECYCLE')
           OR p.[given] IS NULL OR p.[expected] IS NULL
           OR TRY_CONVERT(INT, j.[key]) IS NULL
    )
        THROW 56614, 'Unsupported legacy test structure; no data changed.', 1;

    INSERT INTO [Rules].[MonsterTestCase]
    (
        [ScenarioCode], [TestCaseCode], [SequenceNo], [TestName],
        [TestPhase], [TestStatus], [TestRevision], [GivenText],
        [ExpectedText], [DiceFixtureJson], [AdditionalDataJson],
        [LinkedStoryRef], [AutomatedTestRef], [Notes]
    )
    SELECT
        s.[ScenarioCode],
        p.[test_id],
        CONVERT(INT, j.[key]) + 1,
        LEFT(p.[given], 180),
        p.[phase],
        CASE WHEN p.[phase] = N'DEFERRED_LIFECYCLE'
             THEN N'Deferred' ELSE N'Specified' END,
        1,
        p.[given], p.[expected],
        p.[dice],
        j.[value],                    -- exact historical JSON for audit
        p.[story],
        NULL,
        N'Imported from legacy Scenario.TestCasesJson; historical JSON retained. Unexecuted.'
    FROM [Rules].[MonsterTestScenario] AS s
    CROSS APPLY OPENJSON(s.[TestCasesJson]) AS j
    OUTER APPLY OPENJSON(j.[value]) WITH
    (
        [test_id] NVARCHAR(80) '$.test_id',
        [phase] NVARCHAR(40) '$.phase',
        [given] NVARCHAR(MAX) '$.given',
        [expected] NVARCHAR(MAX) '$.expected',
        [dice] NVARCHAR(MAX) '$.dice' AS JSON,
        [story] NVARCHAR(80) '$.story'
    ) AS p
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[MonsterTestCase] AS existing WITH (UPDLOCK, HOLDLOCK)
        WHERE existing.[ScenarioCode] = s.[ScenarioCode]
          AND existing.[TestCaseCode] = p.[test_id]
    );
    DECLARE @Migrated INT = @@ROWCOUNT;

    -- Nullable column permits new scenario inserts to keep all cases in child.
    -- Leave old JSON payload intact as an archive rather than dropping data.
    IF EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE [parent_object_id] = OBJECT_ID(N'Rules.MonsterTestScenario', N'U')
          AND [name] = N'CK_MonsterTestScenario_JSON'
    )
        ALTER TABLE [Rules].[MonsterTestScenario]
            DROP CONSTRAINT [CK_MonsterTestScenario_JSON];

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE [object_id] = OBJECT_ID(N'Rules.MonsterTestScenario', N'U')
          AND [name] = N'TestCasesJson'
          AND [is_nullable] = 0
    )
        ALTER TABLE [Rules].[MonsterTestScenario]
            ALTER COLUMN [TestCasesJson] NVARCHAR(MAX) NULL;

    ALTER TABLE [Rules].[MonsterTestScenario] WITH CHECK
    ADD CONSTRAINT [CK_MonsterTestScenario_JSON] CHECK
    (
        ISJSON([PartyRosterJson]) = 1
        AND ISJSON([MonsterRosterJson]) = 1
        AND ISJSON([SceneFactsJson]) = 1
        AND ([TestCasesJson] IS NULL OR ISJSON([TestCasesJson]) = 1)
        AND ([CountRollJson] IS NULL OR ISJSON([CountRollJson]) = 1)
        AND ([SurpriseJson] IS NULL OR ISJSON([SurpriseJson]) = 1)
        AND ([ExpectedHandoffJson] IS NULL OR ISJSON([ExpectedHandoffJson]) = 1)
    );

    COMMIT;
    PRINT CONCAT(N'Migrated ', @Migrated,
                 N' legacy test cases to Rules.MonsterTestCase. Old JSON archived.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- Read-only verification; compare existing legacy JSON counts with child rows.
SELECT s.[ScenarioCode],
       CASE WHEN s.[TestCasesJson] IS NULL THEN 0
            ELSE (SELECT COUNT(*) FROM OPENJSON(s.[TestCasesJson])) END
            AS [LegacyJsonCaseCount],
       (SELECT COUNT(*)
        FROM [Rules].[MonsterTestCase] AS t
        WHERE t.[ScenarioCode] = s.[ScenarioCode]) AS [NormalizedCaseCount]
FROM [Rules].[MonsterTestScenario] AS s
ORDER BY s.[ScenarioCode];
GO
