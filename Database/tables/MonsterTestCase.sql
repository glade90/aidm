/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestCase.sql
Repository Path : Database/tables/MonsterTestCase.sql
Project         : Golden Braid / AIDM
Purpose         : Normalized source-controlled test CASE definitions: one row
                  per expected behaviour/branch within a monster encounter.
Target Server   : PEQUOD, SQL Server 2016+
Database        : DnD
Schema/Table    : Test.MonsterTestCase
Version         : 0.2.0 (DRAFT / OWNER REVIEW)
Created         : 2026-11-21
Dependency      : Database/database/Test.sql; Database/tables/MonsterTestScenario.sql
Seed            : Database/tables/inserts/MonsterTestCase_Mentzer_Basic_Insert.sql

DESIGN
- Parent Test.MonsterTestScenario: ONE row per encounter, contains roster,
  fixed precombat dice, scene and appearance assets.
- Child Test.MonsterTestCase: ONE row per test case, with stable TestCaseCode.
  Composite PK (ScenarioCode, TestCaseCode) permits reusing a generic test
  name for different scenarios without accidental overwrites.
- Each test states explicit Given/When and Expected; optional injected dice
  are validated JSON, distinct from the scenario's count/surprise seed.
- TestPhase separates ENCOUNTER from COMBAT, COMBAT_HANDOFF and deferred
  lifecycle tests. Surprise is NOT a Combat attack-round test.
- TestStatus describes specification/readiness ONLY. Not a test result.
  Test executions, pass/fail, build SHA and actual UAT evidence are different
  records in a future TestRun/TestResult service; they MUST NOT be overwritten
  on each test definition edit.
- TestRevision supports future edited acceptance expectations; revisions
  are managed via Git/SQL migration, never silent upsert of existing records.
- ISJSON checks validate syntax only; fixture contract validation and
  source/character authority remain in the generic loader/harness.
- Non-destructive idempotent creation: no DROP TABLE, no seed data here.
===============================================================================
*/
USE [DnD];
GO

IF SCHEMA_ID(N'Test') IS NULL
    THROW 56592, 'Test schema is missing. Run Database/database/Test.sql.', 1;
IF OBJECT_ID(N'Test.MonsterTestScenario', N'U') IS NULL
    THROW 56593, 'Create Test.MonsterTestScenario before MonsterTestCase.', 1;
GO

IF OBJECT_ID(N'Test.MonsterTestCase', N'U') IS NULL
BEGIN
    CREATE TABLE [Test].[MonsterTestCase]
    (
        [ScenarioCode]        NVARCHAR(80)   NOT NULL,
        [TestCaseCode]        NVARCHAR(80)   NOT NULL,
        [SequenceNo]          INT            NOT NULL,
        [TestName]            NVARCHAR(180)  NOT NULL,
        [TestPhase]           NVARCHAR(40)   NOT NULL,
        [TestStatus]          NVARCHAR(20)   NOT NULL
            CONSTRAINT [DF_MonsterTestCase_Status] DEFAULT (N'Specified'),
        [TestRevision]        INT            NOT NULL
            CONSTRAINT [DF_MonsterTestCase_Revision] DEFAULT (1),
        [GivenText]           NVARCHAR(MAX)  NOT NULL,
        [ExpectedText]        NVARCHAR(MAX)  NOT NULL,
        [DiceFixtureJson]     NVARCHAR(MAX)  NULL,
        [AdditionalDataJson]  NVARCHAR(MAX)  NULL,
        [LinkedStoryRef]      NVARCHAR(80)   NULL,
        [AutomatedTestRef]    NVARCHAR(500)  NULL,
        [Notes]               NVARCHAR(MAX)  NULL,
        [CreatedUtc]          DATETIME2(0)   NOT NULL
            CONSTRAINT [DF_MonsterTestCase_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        [UpdatedUtc]          DATETIME2(0)   NULL,

        CONSTRAINT [PK_MonsterTestCase]
            PRIMARY KEY CLUSTERED ([ScenarioCode], [TestCaseCode]),
        CONSTRAINT [FK_MonsterTestCase_Scenario]
            FOREIGN KEY ([ScenarioCode])
            REFERENCES [Test].[MonsterTestScenario] ([ScenarioCode]),

        CONSTRAINT [CK_MonsterTestCase_SequenceRevision]
            CHECK ([SequenceNo] > 0 AND [TestRevision] > 0),
        CONSTRAINT [CK_MonsterTestCase_Phase]
            CHECK ([TestPhase] IN
                (N'ENCOUNTER', N'COMBAT', N'COMBAT_HANDOFF',
                 N'DEFERRED_LIFECYCLE')),
        CONSTRAINT [CK_MonsterTestCase_Status]
            CHECK ([TestStatus] IN
                (N'Specified', N'Ready', N'Deferred', N'Blocked', N'Superseded')),
        CONSTRAINT [CK_MonsterTestCase_DiceJson]
            CHECK (([DiceFixtureJson] IS NULL OR ISJSON([DiceFixtureJson]) = 1)
               AND ([AdditionalDataJson] IS NULL OR ISJSON([AdditionalDataJson]) = 1))
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_MonsterTestCase_Sequence]
        ON [Test].[MonsterTestCase] ([ScenarioCode], [SequenceNo]);

    CREATE NONCLUSTERED INDEX [IX_MonsterTestCase_PhaseStatus]
        ON [Test].[MonsterTestCase] ([TestPhase], [TestStatus], [ScenarioCode]);

    PRINT N'Created Test.MonsterTestCase (zero cases); definitions are not execution results.';
END
ELSE
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM (VALUES
            (N'ScenarioCode'), (N'TestCaseCode'), (N'SequenceNo'),
            (N'TestName'), (N'TestPhase'), (N'TestStatus'),
            (N'TestRevision'), (N'GivenText'), (N'ExpectedText'),
            (N'DiceFixtureJson'), (N'AdditionalDataJson'),
            (N'LinkedStoryRef'), (N'AutomatedTestRef'), (N'Notes'),
            (N'CreatedUtc'), (N'UpdatedUtc')
        ) AS required ([ColumnName])
        WHERE COL_LENGTH(N'Test.MonsterTestCase', required.[ColumnName]) IS NULL
    )
        THROW 56594, 'Existing MonsterTestCase schema incompatible. Review data-preserving migration.', 1;

    PRINT N'Test.MonsterTestCase already exists; nothing changed.';
END;
GO

-- Review the current test catalogue grouped by scenario.
SELECT [ScenarioCode], [TestCaseCode], [SequenceNo], [TestName],
       [TestPhase], [TestStatus], [TestRevision], [LinkedStoryRef],
       [AutomatedTestRef]
FROM [Test].[MonsterTestCase]
ORDER BY [ScenarioCode], [SequenceNo];
GO
