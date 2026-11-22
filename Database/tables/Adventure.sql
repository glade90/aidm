/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Adventure.sql
Repository Path : Database/tables/Adventure.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create an adventure/scenario catalog for published modules,
                  original adventures, and adaptations. Summaries are player-safe.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : dbo
Table           : dbo.Adventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : DnD database (Database/database/dnd.sql)

DESIGN NOTES
- Adventure means a scenario or story arc, not necessarily a published module.
- AdventureCode is a stable label (e.g. B1), not an identity integer.
- RecordDate is UTC DATE; (RecordDate, AdventureCode) identifies a version.
- Active marks the current approved version, not whether play is underway.
  AdventureStatus independently tracks planned/ongoing/completed/abandoned.
- Exactly one Active=1 version is allowed for each AdventureCode.
- One version per adventure per UTC calendar day (DATE-based primary key).
- ModuleCode, ModuleTitle, and Publisher are nullable for original adventures.
- PlayerSummary must contain no hidden keys, stocking, secret doors or spoilers.
- Ruleset records rules authority; RulesNotes can document local exceptions.
- This is a CREATE script, not a migration: it never drops or overwrites data.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     First versioned Adventure table for published and
                        original scenarios.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'dbo.Adventure', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Adventure]
    (
        [RecordDate]      DATE           NOT NULL
            CONSTRAINT [DF_Adventure_RecordDate]
                DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [AdventureCode]   NVARCHAR(100)  NOT NULL,
        [Active]          BIT            NOT NULL
            CONSTRAINT [DF_Adventure_Active] DEFAULT (1),
        [AdventureName]   NVARCHAR(160)  NOT NULL,
        [AdventureType]   NVARCHAR(30)   NOT NULL,
        [ModuleCode]      NVARCHAR(30)   NULL,
        [ModuleTitle]     NVARCHAR(160)  NULL,
        [Publisher]       NVARCHAR(80)   NULL,
        [Ruleset]         NVARCHAR(200)  NOT NULL,
        [RulesNotes]      NVARCHAR(MAX)  NULL,
        [PlayerSummary]   NVARCHAR(MAX)  NOT NULL,
        [AdventureStatus] NVARCHAR(20)   NOT NULL
            CONSTRAINT [DF_Adventure_Status] DEFAULT (N'Planned'),
        [Notes]           NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_Adventure]
            PRIMARY KEY CLUSTERED ([RecordDate], [AdventureCode]),
        CONSTRAINT [CK_Adventure_AdventureType]
            CHECK ([AdventureType] IN
                (N'PublishedModule', N'Original', N'Adaptation', N'Other')),
        CONSTRAINT [CK_Adventure_AdventureStatus]
            CHECK ([AdventureStatus] IN
                (N'Planned', N'Ongoing', N'Completed', N'Abandoned'))
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_Adventure_OneActivePerCode]
        ON [dbo].[Adventure] ([AdventureCode])
        WHERE [Active] = 1;

    PRINT N'Created dbo.Adventure.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'dbo.Adventure', N'AdventureCode') IS NULL
       OR COL_LENGTH(N'dbo.Adventure', N'RecordDate') IS NULL
       OR COL_LENGTH(N'dbo.Adventure', N'Active') IS NULL
       OR COL_LENGTH(N'dbo.Adventure', N'PlayerSummary') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes AS i
           WHERE i.object_id = OBJECT_ID(N'dbo.Adventure', N'U')
             AND i.[name] = N'UX_Adventure_OneActivePerCode'
             AND i.is_unique = 1 AND i.has_filter = 1
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.key_constraints AS pk
           JOIN sys.index_columns AS i1 ON i1.object_id = pk.parent_object_id
               AND i1.index_id = pk.unique_index_id AND i1.key_ordinal = 1
           JOIN sys.columns AS c1 ON c1.object_id = i1.object_id
               AND c1.column_id = i1.column_id
           JOIN sys.index_columns AS i2 ON i2.object_id = pk.parent_object_id
               AND i2.index_id = pk.unique_index_id AND i2.key_ordinal = 2
           JOIN sys.columns AS c2 ON c2.object_id = i2.object_id
               AND c2.column_id = i2.column_id
           WHERE pk.parent_object_id = OBJECT_ID(N'dbo.Adventure', N'U')
             AND pk.[type] = 'PK'
             AND c1.[name] = N'RecordDate' AND c2.[name] = N'AdventureCode'
       )
    BEGIN
        THROW 51301,
            'An incompatible dbo.Adventure table exists. Stop and review a data-preserving migration.', 1;
    END;
    PRINT N'dbo.Adventure exists; no data or schema changed.';
END;
GO

-- Read-only verification.
SELECT [RecordDate], [AdventureCode], [AdventureName], [AdventureType],
       [Ruleset], [AdventureStatus], [Active]
FROM [dbo].[Adventure]
ORDER BY [AdventureCode], [RecordDate] DESC;
GO
