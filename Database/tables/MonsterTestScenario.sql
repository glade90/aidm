/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestScenario.sql
Repository Path : Database/tables/MonsterTestScenario.sql
Project         : Golden Braid / AIDM
Purpose         : One version-controlled SQL record per distinct Monster
                  combat/Encounter regression SCENARIO.
Target Server   : PEQUOD, SQL Server 2016+ (JSON support)
Database        : DnD
Schema          : Rules
Table           : Rules.MonsterTestScenario
Version         : 0.1.0 (DRAFT FOR OWNER REVIEW)
Created         : 2026-11-21
Dependencies    : Database/database/dnd.sql, Database/database/Rules.sql;
                  Database/tables/Monster.sql v0.4 for source monster contracts.
Population      : Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Insert.sql

DATA MODEL
- ONE ROW PER ENCOUNTER: ScenarioCode is PRIMARY KEY. ORC-T001-A/B are
  separate encounters because they have different rosters and rules cases.
  A scenario with several monsters STILL has ONE row, not a row per actor.
- PartyRosterJson and MonsterRosterJson are structured, SQL Server-valid JSON
  arrays of actor identities/roles/starting HP and raw HP dice when fixed.
  This is test-fixture data, NOT persistent real campaign state.
- CountRollJson holds the pre-encounter Number Appearing dice, where fixed.
  SurpriseJson holds ONE surprise d6 PER SIDE and source-specific threshold,
  but is NULL where surprise was never rolled.
- SceneFactsJson holds explicit environment/exposure facts; per-actor
  Troglodyte stench exposure is supplied by each independent Combat test.
  TestCasesJson is a JSON array of test IDs, Given/When/Expected criteria.
  The active deterministic harness validates JSON shape and references.
- The containing table enforces SQL JSON validity (SQL Server 2016 ISJSON)
  and simple bounds; referential/version resolution of MonsterCode is in
  the application because Rules.Monster is date-versioned. NULL means UNKNOWN.
- Monster test data never comes from B1 module hit-point/count arrays.
  Mentzer 1983 + owner-approved synthetic fixtures are the source.
- Status SPECIFIED is NOT executable/passed. ReadyForExecution remains 0
  until all mechanisms, precombat values and acceptance gates are satisfied.
- The Monster catalog owns monster rules/prose and future Encounter-specific
  narrative; scenarios refer to it by RulesetCode/PrimaryMonsterCode and
  do not replicate its full descriptive species record.
- No entity in this table should cause combat to query SQL. A generic
  prototype loader resolves a fixture and version-pinned species snapshot,
  then passes the fully formed roster to Encounter/Combat.
- Re-running CREATE will neither drop nor edit existing table rows.
===============================================================================
*/

USE [DnD];
GO

IF SCHEMA_ID(N'Rules') IS NULL
    THROW 56580, 'Rules schema missing. Create Rules schema first.', 1;
GO

IF OBJECT_ID(N'Rules.MonsterTestScenario', N'U') IS NULL
BEGIN
    CREATE TABLE [Rules].[MonsterTestScenario]
    (
        [ScenarioCode]          NVARCHAR(80)   NOT NULL,
        [ScenarioName]          NVARCHAR(160)  NOT NULL,
        [RulesetCode]           NVARCHAR(80)   NOT NULL,
        [PrimaryMonsterCode]    NVARCHAR(80)   NOT NULL,
        [FixtureRevision]       INT            NOT NULL
            CONSTRAINT [DF_MonsterTestScenario_FixtureRevision] DEFAULT (1),
        [ScenarioStatus]        NVARCHAR(20)   NOT NULL
            CONSTRAINT [DF_MonsterTestScenario_Status] DEFAULT (N'Specified'),
        [ReadyForExecution]     BIT            NOT NULL
            CONSTRAINT [DF_MonsterTestScenario_Ready] DEFAULT (0),
        [OriginReference]       NVARCHAR(500)  NOT NULL,
        [MonsterCount]          INT            NOT NULL,
        [PartyRosterJson]       NVARCHAR(MAX)  NOT NULL,
        [MonsterRosterJson]     NVARCHAR(MAX)  NOT NULL,
        [CountRollJson]         NVARCHAR(MAX)  NULL,
        [SurpriseJson]          NVARCHAR(MAX)  NULL,
        [SceneFactsJson]        NVARCHAR(MAX)  NOT NULL,
        [TestCasesJson]         NVARCHAR(MAX)  NOT NULL,
        [ExpectedHandoffJson]   NVARCHAR(MAX)  NULL,
        [IllustrationPath]      NVARCHAR(500)  NULL,
        [Notes]                 NVARCHAR(MAX)  NULL,
        [CreatedUtc]            DATETIME2(0)   NOT NULL
            CONSTRAINT [DF_MonsterTestScenario_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        [UpdatedUtc]            DATETIME2(0)   NULL,

        CONSTRAINT [PK_MonsterTestScenario]
            PRIMARY KEY CLUSTERED ([ScenarioCode]),

        CONSTRAINT [CK_MonsterTestScenario_Revision]
            CHECK ([FixtureRevision] > 0 AND [MonsterCount] > 0),

        CONSTRAINT [CK_MonsterTestScenario_Status]
            CHECK ([ScenarioStatus] IN
                (N'Specified', N'Ready', N'Executed', N'PassedUAT', N'Superseded')),

        CONSTRAINT [CK_MonsterTestScenario_Ready]
            CHECK ([ReadyForExecution] = 0 OR
                   [ScenarioStatus] IN (N'Ready', N'Executed', N'PassedUAT')),

        CONSTRAINT [CK_MonsterTestScenario_JSON]
            CHECK
            (
                ISJSON([PartyRosterJson]) = 1
                AND ISJSON([MonsterRosterJson]) = 1
                AND ISJSON([SceneFactsJson]) = 1
                AND ISJSON([TestCasesJson]) = 1
                AND ([CountRollJson] IS NULL OR ISJSON([CountRollJson]) = 1)
                AND ([SurpriseJson] IS NULL OR ISJSON([SurpriseJson]) = 1)
                AND ([ExpectedHandoffJson] IS NULL OR ISJSON([ExpectedHandoffJson]) = 1)
            )
    );

    CREATE NONCLUSTERED INDEX [IX_MonsterTestScenario_Species]
        ON [Rules].[MonsterTestScenario]
            ([RulesetCode], [PrimaryMonsterCode], [ScenarioStatus]);

    PRINT N'Created Rules.MonsterTestScenario (one row per encounter, no seeds).';
END
ELSE
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM (VALUES
            (N'ScenarioCode'), (N'ScenarioName'), (N'RulesetCode'),
            (N'PrimaryMonsterCode'), (N'FixtureRevision'), (N'ScenarioStatus'),
            (N'ReadyForExecution'), (N'OriginReference'), (N'MonsterCount'),
            (N'PartyRosterJson'), (N'MonsterRosterJson'), (N'CountRollJson'),
            (N'SurpriseJson'), (N'SceneFactsJson'), (N'TestCasesJson'),
            (N'ExpectedHandoffJson'), (N'IllustrationPath'), (N'Notes'),
            (N'CreatedUtc'), (N'UpdatedUtc')
        ) AS expected([ColumnName])
        WHERE COL_LENGTH(N'Rules.MonsterTestScenario', expected.[ColumnName]) IS NULL
    )
        THROW 56581, 'Existing MonsterTestScenario schema differs; review data-preserving migration.', 1;

    PRINT N'Rules.MonsterTestScenario already exists; no data changed.';
END;
GO

-- Read-only list of fixtures and their readiness.
SELECT [ScenarioCode], [ScenarioName], [RulesetCode],
       [PrimaryMonsterCode], [MonsterCount], [ScenarioStatus],
       [ReadyForExecution], [FixtureRevision], [IllustrationPath]
FROM [Rules].[MonsterTestScenario]
ORDER BY [ScenarioCode];
GO
