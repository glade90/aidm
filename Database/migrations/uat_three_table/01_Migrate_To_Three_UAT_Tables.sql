/*
 Golden Braid / AIDM — Three-table unified UAT schema migration.
 Version 1.0, SQL Server 2016+; run on PEQUOD after backup and 00_Bootstrap.
 Final DnD_Test.Test contains EXACTLY:
     UATTestScenario -> UATTestCase -> UATTestExecution
 Sources: optional DnD.Test.MonsterTest{Scenario,Case}, optional
 DnD_Test.Test.MonsterTest{Scenario,Case}, and optional prior DnD_Test.Test
 UATTest{Case,Execution}. Old DnD.Test remains UNTOUCHED.
 Tables already in DnD_Test.Test are ARCHIVED to DnD_Test.Legacy (no DROP).
 All work in ONE TRANSACTION; missing/mismatched source aborts and rolls back.
 Case IDs + revisions and prior ExecutionId are PRESERVED. No fabricated PASS.
 No live SQL connection/PEQUOD execution claimed by this file.
*/
USE [DnD_Test];
GO
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF SCHEMA_ID(N'Test') IS NULL OR SCHEMA_ID(N'Legacy') IS NULL OR SCHEMA_ID(N'UATStage') IS NULL
    THROW 56800, 'Run 00_Bootstrap_DnD_Test.sql first.', 1;

 -- Detect a previous completed migration, not just table names.
 IF OBJECT_ID(N'Test.UATTestScenario',N'U') IS NOT NULL
 BEGIN
    IF OBJECT_ID(N'Test.UATTestCase',N'U') IS NULL OR
       OBJECT_ID(N'Test.UATTestExecution',N'U') IS NULL OR
       COL_LENGTH(N'Test.UATTestCase',N'ScenarioCode') IS NULL OR
       COL_LENGTH(N'Test.UATTestExecution',N'ScenarioCode') IS NULL
       THROW 56801, 'Partial/incompatible unified registry; manual reconciliation required.', 1;
    IF (SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
        WHERE s.name=N'Test') <> 3
       THROW 56802, 'Unified registry exists but Test schema does not contain exactly 3 tables.', 1;
    PRINT N'Unified three-table UAT registry already exists; no migration changes.';
 END
 ELSE
 BEGIN
    -- Never silently archive an unknown Test table or overwrite an older backup.
    IF EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
               WHERE s.name=N'Test' AND t.name NOT IN
                 (N'MonsterTestScenario',N'MonsterTestCase',N'UATTestCase',N'UATTestExecution'))
       THROW 56803, 'Unexpected table in DnD_Test.Test; inspect before migration.', 1;
    IF EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
               WHERE s.name=N'Legacy' AND t.name IN
                 (N'MonsterTestScenario',N'MonsterTestCase',N'UATTestCase',N'UATTestExecution'))
       THROW 56804, 'Legacy table name already exists; do not overwrite prior archives.', 1;
    IF EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
               WHERE s.name=N'UATStage' AND t.name IN
                 (N'UATTestScenario_m',N'UATTestCase_m',N'UATTestExecution_m'))
       THROW 56805, 'Previous staging tables found; investigate before migration.', 1;

    CREATE TABLE [UATStage].[UATTestScenario_m]
    (
        [ScenarioCode] NVARCHAR(128) NOT NULL,
        [ScenarioName] NVARCHAR(200) NOT NULL,
        [ScenarioKind] NVARCHAR(20) NOT NULL,
        [RulesetCode] NVARCHAR(80) NULL,
        [PrimaryMonsterCode] NVARCHAR(80) NULL,
        [FixtureRevision] INT NOT NULL CONSTRAINT [DF_UATS_m_FixtureRevision] DEFAULT(1),
        [SpecificationStatus] NVARCHAR(20) NOT NULL CONSTRAINT [DF_UATS_m_Status] DEFAULT(N'Specified'),
        [ReadyForExecution] BIT NOT NULL CONSTRAINT [DF_UATS_m_Ready] DEFAULT(0),
        [OriginReference] NVARCHAR(500) NULL,
        [MonsterCount] INT NULL,
        [PartyRosterJson] NVARCHAR(MAX) NULL,
        [MonsterRosterJson] NVARCHAR(MAX) NULL,
        [CountRollJson] NVARCHAR(MAX) NULL,
        [SurpriseJson] NVARCHAR(MAX) NULL,
        [SceneFactsJson] NVARCHAR(MAX) NULL,
        [ExpectedHandoffJson] NVARCHAR(MAX) NULL,
        [IllustrationPath] NVARCHAR(500) NULL,
        [ScenarioDataJson] NVARCHAR(MAX) NULL,
        [LegacyScenarioStatus] NVARCHAR(20) NULL,
        [Notes] NVARCHAR(MAX) NULL,
        [CreatedUtc] DATETIME2(0) NOT NULL CONSTRAINT [DF_UATS_m_CreatedUtc] DEFAULT(SYSUTCDATETIME()),
        [UpdatedUtc] DATETIME2(0) NULL,
        CONSTRAINT [PK_UATS_m] PRIMARY KEY CLUSTERED ([ScenarioCode]),
        CONSTRAINT [CK_UATS_m_Kind] CHECK ([ScenarioKind] IN (N'MONSTER',N'STORY',N'GENERIC')),
        CONSTRAINT [CK_UATS_m_Status] CHECK ([SpecificationStatus] IN
            (N'Specified',N'Ready',N'Blocked',N'Deferred',N'Superseded')),
        CONSTRAINT [CK_UATS_m_Ready] CHECK ([ReadyForExecution]=0 OR [SpecificationStatus]=N'Ready'),
        CONSTRAINT [CK_UATS_m_Revision] CHECK ([FixtureRevision]>0 AND ([MonsterCount] IS NULL OR [MonsterCount]>0)),
        CONSTRAINT [CK_UATS_m_Json] CHECK
          (([PartyRosterJson] IS NULL OR ISJSON([PartyRosterJson])=1)
           AND ([MonsterRosterJson] IS NULL OR ISJSON([MonsterRosterJson])=1)
           AND ([CountRollJson] IS NULL OR ISJSON([CountRollJson])=1)
           AND ([SurpriseJson] IS NULL OR ISJSON([SurpriseJson])=1)
           AND ([SceneFactsJson] IS NULL OR ISJSON([SceneFactsJson])=1)
           AND ([ExpectedHandoffJson] IS NULL OR ISJSON([ExpectedHandoffJson])=1)
           AND ([ScenarioDataJson] IS NULL OR ISJSON([ScenarioDataJson])=1))
    );

    CREATE TABLE [UATStage].[UATTestCase_m]
    (
        [ScenarioCode] NVARCHAR(128) NOT NULL,
        [TestCaseCode] NVARCHAR(80) NOT NULL,
        [TestRevision] INT NOT NULL CONSTRAINT [DF_UATC_m_Revision] DEFAULT(1),
        [SequenceNo] INT NOT NULL,
        [TestName] NVARCHAR(180) NOT NULL,
        [LinkedStoryRef] NVARCHAR(80) NULL,
        [TestArea] NVARCHAR(60) NULL,
        [TestPhase] NVARCHAR(40) NULL,
        [GivenText] NVARCHAR(MAX) NOT NULL,
        [WhenText] NVARCHAR(MAX) NULL, -- Existing monster cases did not have WHEN.
        [ExpectedText] NVARCHAR(MAX) NOT NULL,
        [SpecificationStatus] NVARCHAR(20) NOT NULL CONSTRAINT [DF_UATC_m_Status] DEFAULT(N'Specified'),
        [ReadyForExecution] BIT NOT NULL CONSTRAINT [DF_UATC_m_Ready] DEFAULT(0),
        [FixtureMode] NVARCHAR(20) NULL, -- Unknown for imported monster cases; do not invent mode.
        [FixtureRef] NVARCHAR(250) NULL,
        [DiceFixtureJson] NVARCHAR(MAX) NULL,
        [AdditionalDataJson] NVARCHAR(MAX) NULL,
        [AutomatedTestRef] NVARCHAR(500) NULL,
        [Notes] NVARCHAR(MAX) NULL,
        [CreatedUtc] DATETIME2(0) NOT NULL CONSTRAINT [DF_UATC_m_CreatedUtc] DEFAULT(SYSUTCDATETIME()),
        [UpdatedUtc] DATETIME2(0) NULL,
        CONSTRAINT [PK_UATC_m] PRIMARY KEY CLUSTERED ([ScenarioCode],[TestCaseCode],[TestRevision]),
        CONSTRAINT [FK_UATC_m_Scenario] FOREIGN KEY ([ScenarioCode])
           REFERENCES [UATStage].[UATTestScenario_m] ([ScenarioCode]),
        CONSTRAINT [CK_UATC_m_RevSeq] CHECK ([TestRevision]>0 AND [SequenceNo]>0),
        CONSTRAINT [CK_UATC_m_Status] CHECK ([SpecificationStatus] IN
          (N'Specified',N'Ready',N'Blocked',N'Deferred',N'Superseded')),
        CONSTRAINT [CK_UATC_m_Ready] CHECK ([ReadyForExecution]=0 OR [SpecificationStatus]=N'Ready'),
        CONSTRAINT [CK_UATC_m_Mode] CHECK ([FixtureMode] IS NULL OR [FixtureMode] IN
          (N'SYNTHETIC',N'LIVE',N'MIXED')),
        CONSTRAINT [CK_UATC_m_JSON] CHECK
          (([DiceFixtureJson] IS NULL OR ISJSON([DiceFixtureJson])=1)
           AND ([AdditionalDataJson] IS NULL OR ISJSON([AdditionalDataJson])=1))
    );
    CREATE NONCLUSTERED INDEX [IX_UATC_m_Story] ON [UATStage].[UATTestCase_m]
        ([LinkedStoryRef],[TestCaseCode],[TestRevision] DESC);
    CREATE NONCLUSTERED INDEX [IX_UATC_m_Area] ON [UATStage].[UATTestCase_m]
        ([TestArea],[SpecificationStatus],[ScenarioCode]);

    CREATE TABLE [UATStage].[UATTestExecution_m]
    (
        [ExecutionId] BIGINT IDENTITY(1,1) NOT NULL,
        [ScenarioCode] NVARCHAR(128) NOT NULL,
        [TestCaseCode] NVARCHAR(80) NOT NULL,
        [TestRevision] INT NOT NULL,
        [RunGroupCode] NVARCHAR(120) NULL,
        [ExecutedUtc] DATETIME2(0) NOT NULL CONSTRAINT [DF_UATE_m_ExecutedUtc] DEFAULT(SYSUTCDATETIME()),
        [TestedBy] NVARCHAR(80) NOT NULL,
        [EnvironmentName] NVARCHAR(120) NOT NULL,
        [SourceSha] CHAR(40) NULL,
        [ExecutionMode] NVARCHAR(20) NOT NULL,
        [ResultStatus] NVARCHAR(20) NOT NULL,
        [ObservedText] NVARCHAR(MAX) NULL,
        [EvidenceRef] NVARCHAR(500) NULL,
        [EvidenceJson] NVARCHAR(MAX) NULL,
        [DefectRef] NVARCHAR(120) NULL,
        [Notes] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_UATE_m] PRIMARY KEY CLUSTERED ([ExecutionId]),
        CONSTRAINT [FK_UATE_m_Case] FOREIGN KEY ([ScenarioCode],[TestCaseCode],[TestRevision])
           REFERENCES [UATStage].[UATTestCase_m] ([ScenarioCode],[TestCaseCode],[TestRevision]),
        CONSTRAINT [CK_UATE_m_Result] CHECK ([ResultStatus] IN (N'NotRun',N'Pass',N'Fail',N'Blocked')),
        CONSTRAINT [CK_UATE_m_Mode] CHECK ([ExecutionMode] IN (N'SYNTHETIC',N'LIVE',N'MIXED')),
        CONSTRAINT [CK_UATE_m_EvidenceJson] CHECK ([EvidenceJson] IS NULL OR ISJSON([EvidenceJson])=1),
        CONSTRAINT [CK_UATE_m_Sha] CHECK
           ([SourceSha] IS NULL OR (LEN([SourceSha])=40 AND [SourceSha] NOT LIKE '%[^0-9a-fA-F]%')),
        CONSTRAINT [CK_UATE_m_Observed] CHECK
           ([ResultStatus] NOT IN (N'Pass',N'Fail') OR
            ([SourceSha] IS NOT NULL AND [ObservedText] IS NOT NULL AND LEN(LTRIM(RTRIM([ObservedText])))>0))
    );
    CREATE NONCLUSTERED INDEX [IX_UATE_m_Latest] ON [UATStage].[UATTestExecution_m]
        ([ScenarioCode],[TestCaseCode],[TestRevision],[ExecutionId] DESC)
        INCLUDE ([ResultStatus],[ExecutedUtc],[SourceSha]);

    DECLARE @sourceDb sysname;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @sourceScenarios NVARCHAR(400);
    DECLARE @sourceCases NVARCHAR(400);
    DECLARE @hasScenarios bit;
    DECLARE @hasCases bit;

    -- Source preference does not erase records: read both copies, reject conflicts.
    DECLARE source_cursor CURSOR LOCAL FAST_FORWARD FOR
         SELECT [SourceDB] FROM (VALUES (N'DnD_Test'),(N'DnD')) AS s([SourceDB]);
    OPEN source_cursor;
    FETCH NEXT FROM source_cursor INTO @sourceDb;
    WHILE @@FETCH_STATUS=0
    BEGIN
       SET @sourceScenarios=QUOTENAME(@sourceDb)+N'.[Test].[MonsterTestScenario]';
       SET @sourceCases=QUOTENAME(@sourceDb)+N'.[Test].[MonsterTestCase]';
       SET @hasScenarios=CASE WHEN OBJECT_ID(@sourceScenarios,N'U') IS NOT NULL THEN 1 ELSE 0 END;
       SET @hasCases=CASE WHEN OBJECT_ID(@sourceCases,N'U') IS NOT NULL THEN 1 ELSE 0 END;
       IF @hasScenarios<>@hasCases
          THROW 56806, 'Found only one of the monster source tables; review schema.', 1;
       IF @hasScenarios=1
       BEGIN
          -- A Monster scenario retains original fields; result-like legacy status is
          -- audit metadata, NOT proof of a current UAT execution.
          SET @sql=N'
          INSERT [UATStage].[UATTestScenario_m]
            ([ScenarioCode],[ScenarioName],[ScenarioKind],[RulesetCode],
             [PrimaryMonsterCode],[FixtureRevision],[SpecificationStatus],
             [ReadyForExecution],[OriginReference],[MonsterCount],
             [PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],
             [SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],
             [LegacyScenarioStatus],[Notes],[CreatedUtc],[UpdatedUtc])
          SELECT s.[ScenarioCode],s.[ScenarioName],N''MONSTER'',s.[RulesetCode],
             s.[PrimaryMonsterCode],s.[FixtureRevision],
             CASE WHEN s.[ScenarioStatus] IN(N''Executed'',N''PassedUAT'')
                  THEN N''Ready'' ELSE s.[ScenarioStatus] END,
             s.[ReadyForExecution],s.[OriginReference],s.[MonsterCount],
             s.[PartyRosterJson],s.[MonsterRosterJson],s.[CountRollJson],s.[SurpriseJson],
             s.[SceneFactsJson],s.[ExpectedHandoffJson],s.[IllustrationPath],
             s.[ScenarioStatus],s.[Notes],s.[CreatedUtc],s.[UpdatedUtc]
          FROM '+@sourceScenarios+N' AS s
          WHERE NOT EXISTS (SELECT 1 FROM [UATStage].[UATTestScenario_m] AS d
                            WHERE d.[ScenarioCode]=s.[ScenarioCode]);
          IF EXISTS (
             SELECT s.[ScenarioCode],s.[ScenarioName],s.[RulesetCode],
                s.[PrimaryMonsterCode],s.[FixtureRevision],
                CASE WHEN s.[ScenarioStatus] IN(N''Executed'',N''PassedUAT'')
                     THEN N''Ready'' ELSE s.[ScenarioStatus] END,
                s.[ReadyForExecution],s.[OriginReference],s.[MonsterCount],
                s.[PartyRosterJson],s.[MonsterRosterJson],s.[CountRollJson],s.[SurpriseJson],
                s.[SceneFactsJson],s.[ExpectedHandoffJson],s.[IllustrationPath],
                s.[ScenarioStatus],s.[Notes],s.[CreatedUtc],s.[UpdatedUtc]
             FROM '+@sourceScenarios+N' s
             EXCEPT
             SELECT d.[ScenarioCode],d.[ScenarioName],d.[RulesetCode],
                d.[PrimaryMonsterCode],d.[FixtureRevision],d.[SpecificationStatus],
                d.[ReadyForExecution],d.[OriginReference],d.[MonsterCount],
                d.[PartyRosterJson],d.[MonsterRosterJson],d.[CountRollJson],d.[SurpriseJson],
                d.[SceneFactsJson],d.[ExpectedHandoffJson],d.[IllustrationPath],
                d.[LegacyScenarioStatus],d.[Notes],d.[CreatedUtc],d.[UpdatedUtc]
             FROM [UATStage].[UATTestScenario_m] d WHERE d.[ScenarioKind]=N''MONSTER'')
             THROW 56807, ''Conflicting MonsterTestScenario source rows; aborted.'',1;';
          EXEC sys.sp_executesql @sql;

          SET @sql=N'
          INSERT [UATStage].[UATTestCase_m]
           ([ScenarioCode],[TestCaseCode],[TestRevision],[SequenceNo],[TestName],
            [LinkedStoryRef],[TestPhase],[GivenText],[ExpectedText],
            [SpecificationStatus],[ReadyForExecution],[DiceFixtureJson],
            [AdditionalDataJson],[AutomatedTestRef],[Notes],[CreatedUtc],[UpdatedUtc])
          SELECT s.[ScenarioCode],s.[TestCaseCode],s.[TestRevision],s.[SequenceNo],
            s.[TestName],s.[LinkedStoryRef],s.[TestPhase],s.[GivenText],
            s.[ExpectedText],s.[TestStatus],
            CASE WHEN s.[TestStatus]=N''Ready'' AND sc.[ReadyForExecution]=1
                 THEN CONVERT(bit,1) ELSE CONVERT(bit,0) END,
            s.[DiceFixtureJson],s.[AdditionalDataJson],s.[AutomatedTestRef],
            s.[Notes],s.[CreatedUtc],s.[UpdatedUtc]
          FROM '+@sourceCases+N' AS s
          JOIN [UATStage].[UATTestScenario_m] sc ON sc.[ScenarioCode]=s.[ScenarioCode]
          WHERE NOT EXISTS (SELECT 1 FROM [UATStage].[UATTestCase_m] d
             WHERE d.[ScenarioCode]=s.[ScenarioCode]
             AND d.[TestCaseCode]=s.[TestCaseCode]
             AND d.[TestRevision]=s.[TestRevision]);
          IF EXISTS (
            SELECT s.[ScenarioCode],s.[TestCaseCode],s.[TestRevision],s.[SequenceNo],
               s.[TestName],s.[LinkedStoryRef],s.[TestPhase],s.[GivenText],s.[ExpectedText],
               s.[TestStatus],s.[DiceFixtureJson],s.[AdditionalDataJson],
               s.[AutomatedTestRef],s.[Notes],s.[CreatedUtc],s.[UpdatedUtc]
            FROM '+@sourceCases+N' s
            EXCEPT
            SELECT d.[ScenarioCode],d.[TestCaseCode],d.[TestRevision],d.[SequenceNo],
               d.[TestName],d.[LinkedStoryRef],d.[TestPhase],d.[GivenText],d.[ExpectedText],
               d.[SpecificationStatus],d.[DiceFixtureJson],d.[AdditionalDataJson],
               d.[AutomatedTestRef],d.[Notes],d.[CreatedUtc],d.[UpdatedUtc]
            FROM [UATStage].[UATTestCase_m] d)
            THROW 56808, ''Conflicting MonsterTestCase source rows; aborted.'',1;';
          EXEC sys.sp_executesql @sql;
       END;
       FETCH NEXT FROM source_cursor INTO @sourceDb;
    END;
    CLOSE source_cursor;
    DEALLOCATE source_cursor;

    -- Previous bundle's generic UAT registry had no ScenarioCode; group by story.
    IF OBJECT_ID(N'Test.UATTestCase',N'U') IS NOT NULL
    BEGIN
       IF COL_LENGTH(N'Test.UATTestCase',N'ScenarioCode') IS NOT NULL
           THROW 56809, 'Unexpected already-versioned UATTestCase without scenario table.', 1;
       IF EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE [LinkedStoryRef] IS NULL
                  OR LEN([LinkedStoryRef])=0)
           THROW 56810, 'Old UATTestCase has missing LinkedStoryRef; cannot group safely.', 1;
       INSERT [UATStage].[UATTestScenario_m]
         ([ScenarioCode],[ScenarioName],[ScenarioKind],[FixtureRevision],
          [SpecificationStatus],[ReadyForExecution],[OriginReference],[CreatedUtc],[Notes])
       SELECT N'STORY:'+c.[LinkedStoryRef],N'Functional UAT — '+c.[LinkedStoryRef],
              N'STORY',1,N'Specified',0,
              N'Imported from prior DnD_Test.Test.UATTestCase',
              MIN(c.[CreatedUtc]),N'Story-level scenario synthesized from existing UAT case definitions; no result claimed.'
       FROM [Test].[UATTestCase] c
       WHERE NOT EXISTS (SELECT 1 FROM [UATStage].[UATTestScenario_m] d
                         WHERE d.ScenarioCode=N'STORY:'+c.[LinkedStoryRef])
       GROUP BY c.[LinkedStoryRef];
       IF EXISTS (SELECT 1 FROM [Test].[UATTestCase] c
           JOIN [UATStage].[UATTestScenario_m] d ON d.[ScenarioCode]=N'STORY:'+c.[LinkedStoryRef]
           WHERE d.[ScenarioKind]<>N'STORY')
           THROW 56811, 'Generic UAT story scenario code collides with a monster scenario.', 1;
       INSERT [UATStage].[UATTestCase_m]
         ([ScenarioCode],[TestCaseCode],[TestRevision],[SequenceNo],[TestName],
          [LinkedStoryRef],[TestArea],[GivenText],[WhenText],[ExpectedText],
          [SpecificationStatus],[ReadyForExecution],[FixtureMode],[FixtureRef],
          [AutomatedTestRef],[Notes],[CreatedUtc])
       SELECT N'STORY:'+c.[LinkedStoryRef],c.[TestCaseCode],c.[TestRevision],
              c.[SequenceNo],c.[TestName],c.[LinkedStoryRef],c.[TestArea],
              c.[GivenText],c.[WhenText],c.[ExpectedText],c.[SpecificationStatus],
              c.[ReadyForExecution],c.[FixtureMode],c.[FixtureRef],
              c.[AutomatedTestRef],c.[Notes],c.[CreatedUtc]
       FROM [Test].[UATTestCase] c
       WHERE NOT EXISTS (SELECT 1 FROM [UATStage].[UATTestCase_m] d
           WHERE d.[ScenarioCode]=N'STORY:'+c.[LinkedStoryRef]
             AND d.[TestCaseCode]=c.[TestCaseCode] AND d.[TestRevision]=c.[TestRevision]);
       -- Ensure every old generic case has a canonical new counterpart.
       IF EXISTS (SELECT 1 FROM [Test].[UATTestCase] c
          LEFT JOIN [UATStage].[UATTestCase_m] d
           ON d.[ScenarioCode]=N'STORY:'+c.[LinkedStoryRef]
           AND d.[TestCaseCode]=c.[TestCaseCode] AND d.[TestRevision]=c.[TestRevision]
          WHERE d.[TestCaseCode] IS NULL)
          THROW 56812, 'Some generic UAT test cases were not copied.', 1;
       -- Full value comparison: no silent edits to expected observations,
       -- readiness, modes, provenance, original notes or timestamps.
       IF EXISTS (
          SELECT N'STORY:'+c.[LinkedStoryRef],c.[TestCaseCode],c.[TestRevision],
             c.[SequenceNo],c.[TestName],c.[LinkedStoryRef],c.[TestArea],
             c.[GivenText],c.[WhenText],c.[ExpectedText],c.[SpecificationStatus],
             c.[ReadyForExecution],c.[FixtureMode],c.[FixtureRef],
             c.[AutomatedTestRef],c.[Notes],c.[CreatedUtc]
          FROM [Test].[UATTestCase] c
          EXCEPT
          SELECT d.[ScenarioCode],d.[TestCaseCode],d.[TestRevision],
             d.[SequenceNo],d.[TestName],d.[LinkedStoryRef],d.[TestArea],
             d.[GivenText],d.[WhenText],d.[ExpectedText],d.[SpecificationStatus],
             d.[ReadyForExecution],d.[FixtureMode],d.[FixtureRef],
             d.[AutomatedTestRef],d.[Notes],d.[CreatedUtc]
          FROM [UATStage].[UATTestCase_m] d)
          THROW 56819, 'Generic UAT case content differs; migration rolled back.',1;
    END;

    IF OBJECT_ID(N'Test.UATTestExecution',N'U') IS NOT NULL
    BEGIN
       IF OBJECT_ID(N'Test.UATTestCase',N'U') IS NULL
          THROW 56813, 'Old generic UAT executions exist without case definitions.',1;
       IF EXISTS (SELECT 1 FROM [Test].[UATTestExecution] e
          LEFT JOIN [Test].[UATTestCase] c
            ON c.TestCaseCode=e.TestCaseCode AND c.TestRevision=e.TestRevision
          WHERE c.TestCaseCode IS NULL)
          THROW 56814, 'Orphaned prior UAT execution; aborting to protect history.',1;
       SET IDENTITY_INSERT [UATStage].[UATTestExecution_m] ON;
       INSERT [UATStage].[UATTestExecution_m]
        ([ExecutionId],[ScenarioCode],[TestCaseCode],[TestRevision],[RunGroupCode],
         [ExecutedUtc],[TestedBy],[EnvironmentName],[SourceSha],[ExecutionMode],
         [ResultStatus],[ObservedText],[EvidenceRef],[EvidenceJson],[DefectRef],[Notes])
       SELECT e.[ExecutionId],N'STORY:'+c.[LinkedStoryRef],e.[TestCaseCode],
              e.[TestRevision],e.[RunGroupCode],e.[ExecutedUtc],e.[TestedBy],
              e.[EnvironmentName],e.[SourceSha],e.[ExecutionMode],e.[ResultStatus],
              e.[ObservedText],e.[EvidenceRef],e.[EvidenceJson],e.[DefectRef],e.[Notes]
       FROM [Test].[UATTestExecution] e
       JOIN [Test].[UATTestCase] c
        ON c.TestCaseCode=e.TestCaseCode AND c.TestRevision=e.TestRevision;
       SET IDENTITY_INSERT [UATStage].[UATTestExecution_m] OFF;
       IF (SELECT COUNT_BIG(*) FROM [Test].[UATTestExecution]) <>
          (SELECT COUNT_BIG(*) FROM [UATStage].[UATTestExecution_m])
          THROW 56815, 'Prior UAT execution history migration count mismatch.',1;
       IF EXISTS (SELECT e.ExecutionId FROM [Test].[UATTestExecution] e
           EXCEPT SELECT e.ExecutionId FROM [UATStage].[UATTestExecution_m] e)
          THROW 56816, 'Prior UAT execution IDs not all preserved.',1;
       IF EXISTS (
          SELECT e.[ExecutionId],N'STORY:'+c.[LinkedStoryRef],e.[TestCaseCode],
             e.[TestRevision],e.[RunGroupCode],e.[ExecutedUtc],e.[TestedBy],
             e.[EnvironmentName],e.[SourceSha],e.[ExecutionMode],e.[ResultStatus],
             e.[ObservedText],e.[EvidenceRef],e.[EvidenceJson],e.[DefectRef],e.[Notes]
          FROM [Test].[UATTestExecution] e
          JOIN [Test].[UATTestCase] c
            ON c.[TestCaseCode]=e.[TestCaseCode] AND c.[TestRevision]=e.[TestRevision]
          EXCEPT
          SELECT d.[ExecutionId],d.[ScenarioCode],d.[TestCaseCode],d.[TestRevision],
             d.[RunGroupCode],d.[ExecutedUtc],d.[TestedBy],d.[EnvironmentName],
             d.[SourceSha],d.[ExecutionMode],d.[ResultStatus],d.[ObservedText],
             d.[EvidenceRef],d.[EvidenceJson],d.[DefectRef],d.[Notes]
          FROM [UATStage].[UATTestExecution_m] d)
          THROW 56820, 'Prior UAT execution values differ; migration rolled back.',1;
    END;

    -- No source data is destroyed. Existing DnD_Test.Test definitions are moved
    -- to DnD_Test.Legacy under original table names for rollback/inspection.
    IF OBJECT_ID(N'Test.UATTestExecution',N'U') IS NOT NULL
         ALTER SCHEMA [Legacy] TRANSFER [Test].[UATTestExecution];
    IF OBJECT_ID(N'Test.UATTestCase',N'U') IS NOT NULL
         ALTER SCHEMA [Legacy] TRANSFER [Test].[UATTestCase];
    IF OBJECT_ID(N'Test.MonsterTestCase',N'U') IS NOT NULL
         ALTER SCHEMA [Legacy] TRANSFER [Test].[MonsterTestCase];
    IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NOT NULL
         ALTER SCHEMA [Legacy] TRANSFER [Test].[MonsterTestScenario];

    ALTER SCHEMA [Test] TRANSFER [UATStage].[UATTestScenario_m];
    EXEC sys.sp_rename N'Test.UATTestScenario_m',N'UATTestScenario',N'OBJECT';
    ALTER SCHEMA [Test] TRANSFER [UATStage].[UATTestCase_m];
    EXEC sys.sp_rename N'Test.UATTestCase_m',N'UATTestCase',N'OBJECT';
    ALTER SCHEMA [Test] TRANSFER [UATStage].[UATTestExecution_m];
    EXEC sys.sp_rename N'Test.UATTestExecution_m',N'UATTestExecution',N'OBJECT';

    IF (SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
        WHERE s.name=N'Test')<>3
         THROW 56817, 'Test schema has unexpected table count; transaction rolls back.',1;
    IF OBJECT_ID(N'Test.UATTestScenario',N'U') IS NULL OR
       OBJECT_ID(N'Test.UATTestCase',N'U') IS NULL OR
       OBJECT_ID(N'Test.UATTestExecution',N'U') IS NULL
         THROW 56818, 'Cutover table names not found; transaction rolls back.',1;
    PRINT N'Unified UAT migration committed: exactly three Test tables; old test data preserved in Legacy and DnD.';
 END;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF CURSOR_STATUS('local','source_cursor')>=0 CLOSE source_cursor;
 IF CURSOR_STATUS('local','source_cursor')>=-1 DEALLOCATE source_cursor;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
SELECT s.name AS SchemaName,t.name AS TableName
FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
WHERE s.name IN (N'Test',N'Legacy') ORDER BY s.name,t.name;
GO