/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Expedition.sql
Repository Path : Database/tables/Expedition.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Store a single outing within an adventure, from departure
                  through return and the formal XP/treasure settlement ceremony.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : dbo
Table           : dbo.Expedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Adventure.sql

DESIGN NOTES
- An Adventure may have many Expeditions (one outing per ExpeditionNumber).
- Returning to town does not close an expedition: Settlement is a distinct
  status until the formal XP/treasure awards and records are finalized.
- RecordDate DATE plus AdventureCode and ExpeditionNumber identifies a version;
  Active marks the latest approved DATABASE version, not play status.
- At most one Active=1 version per adventure/expedition (filtered unique index).
- One version per adventure/expedition per UTC calendar date is supported.
- AdventureRecordDate references the specific parent Adventure version in use
  when this expedition snapshot is created; it need not track later revisions.
- Dates within the fantasy world are not assumed: GameStartDate and GameEndDate
  are optional text until the in-world calendar is defined.
- ClosedAtUtc records the real-world administrative close timestamp, if known;
  it must not be populated merely because the party reached town.
- SummaryMarkdown and SettlementNotes are Markdown-compatible NVARCHAR(MAX).
- This file creates a NEW table only. It does not migrate existing tables.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Initial versioned Expedition table with adventure
                        relationship and separate settlement status.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'dbo.Adventure', N'U') IS NULL
    THROW 51500, 'Missing dbo.Adventure. Execute Adventure.sql first.', 1;
GO

IF OBJECT_ID(N'dbo.Expedition', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Expedition]
    (
        [RecordDate]          DATE           NOT NULL
            CONSTRAINT [DF_Expedition_RecordDate]
                DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [AdventureCode]       NVARCHAR(100)  NOT NULL,
        [ExpeditionNumber]    INT            NOT NULL,
        [Active]              BIT            NOT NULL
            CONSTRAINT [DF_Expedition_Active] DEFAULT (1),
        [AdventureRecordDate] DATE           NOT NULL,
        [ExpeditionStatus]    NVARCHAR(20)   NOT NULL
            CONSTRAINT [DF_Expedition_Status] DEFAULT (N'Active'),
        [GameStartDate]       NVARCHAR(80)   NULL,
        [GameEndDate]         NVARCHAR(80)   NULL,
        [StartLocation]       NVARCHAR(200)  NULL,
        [EndLocation]         NVARCHAR(200)  NULL,
        [FinalDungeonTurn]    INT            NULL,
        [ClosedAtUtc]         DATETIME2(0)   NULL,
        [SummaryMarkdown]     NVARCHAR(MAX)  NULL,
        [SettlementNotes]     NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_Expedition]
            PRIMARY KEY CLUSTERED
                ([RecordDate], [AdventureCode], [ExpeditionNumber]),
        CONSTRAINT [FK_Expedition_Adventure]
            FOREIGN KEY ([AdventureRecordDate], [AdventureCode])
            REFERENCES [dbo].[Adventure] ([RecordDate], [AdventureCode]),
        CONSTRAINT [CK_Expedition_Number]
            CHECK ([ExpeditionNumber] >= 1),
        CONSTRAINT [CK_Expedition_FinalTurn]
            CHECK ([FinalDungeonTurn] IS NULL OR [FinalDungeonTurn] >= 0),
        CONSTRAINT [CK_Expedition_Status]
            CHECK ([ExpeditionStatus] IN
                (N'Planned', N'Active', N'Settlement', N'Closed', N'Abandoned')),
        CONSTRAINT [CK_Expedition_ClosedAt]
            CHECK ([ClosedAtUtc] IS NULL OR [ExpeditionStatus] = N'Closed')
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_Expedition_OneActiveVersion]
        ON [dbo].[Expedition] ([AdventureCode], [ExpeditionNumber])
        WHERE [Active] = 1;

    PRINT N'Created dbo.Expedition.';
END
ELSE
BEGIN
    -- Never mistake an older/incompatible table for an approved new version.
    IF COL_LENGTH(N'dbo.Expedition', N'RecordDate') IS NULL
       OR COL_LENGTH(N'dbo.Expedition', N'AdventureCode') IS NULL
       OR COL_LENGTH(N'dbo.Expedition', N'ExpeditionNumber') IS NULL
       OR COL_LENGTH(N'dbo.Expedition', N'AdventureRecordDate') IS NULL
       OR COL_LENGTH(N'dbo.Expedition', N'ExpeditionStatus') IS NULL
       OR COL_LENGTH(N'dbo.Expedition', N'Active') IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.columns AS c
           JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'dbo.Expedition', N'U')
             AND c.[name] = N'RecordDate' AND ty.[name] = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes AS ix
           WHERE ix.object_id = OBJECT_ID(N'dbo.Expedition', N'U')
             AND ix.[name] = N'UX_Expedition_OneActiveVersion'
             AND ix.is_unique = 1 AND ix.has_filter = 1
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.foreign_keys AS fk
           WHERE fk.parent_object_id = OBJECT_ID(N'dbo.Expedition', N'U')
             AND fk.[name] = N'FK_Expedition_Adventure'
             AND fk.referenced_object_id = OBJECT_ID(N'dbo.Adventure', N'U')
       )
    BEGIN
        THROW 51501,
              'An incompatible dbo.Expedition exists. Review a data-preserving migration.', 1;
    END;
    PRINT N'dbo.Expedition already exists; no changes made.';
END;
GO

-- Read-only verification.
SELECT [RecordDate], [AdventureCode], [ExpeditionNumber], [Active],
       [AdventureRecordDate], [ExpeditionStatus], [FinalDungeonTurn],
       [StartLocation], [EndLocation], [ClosedAtUtc]
FROM [dbo].[Expedition]
ORDER BY [AdventureCode], [ExpeditionNumber], [RecordDate] DESC;
GO
