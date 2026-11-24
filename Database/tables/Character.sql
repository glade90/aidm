/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Character.sql
Repository Path : Database/tables/Character.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create the versioned character identity/starting attributes table.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.Character
Version         : 1.1.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : DnD database and characters schema (Database/database/dnd.sql)

DESIGN DECISIONS
- Compound PRIMARY KEY: (RecordDate, CharacterName), in that column order.
- RecordDate is UTC DATETIME2(7), not DATE: multiple versions may occur per day.
- Active BIT indicates the currently approved version of a character (1/0).
- A filtered UNIQUE index allows at most one Active=1 row per character name.
- An inactive row is retained for historical reference, never deleted by this script.
- CharacterName is the stable natural identifier; no surrogate CharacterID.
- Attributes reflect the approved values at the time the version was recorded.
- BackStory stores the full Markdown verbatim as NVARCHAR(MAX).
- Character portraits are held in future adventure/expedition-related tables.
- CharacterLevel, CharacterExpedition, etc. are separate future tables.
- Subsequent version creation should deactivate the old record and insert the
  new one in a transaction; do not update previously approved facts in place.
- THIS IS AN INITIAL CREATION SCRIPT, NOT A MIGRATION. If an incompatible
  earlier Character table exists, stop; no data or constraints are changed.
- Child tables wishing to reference a particular character version must use
  BOTH RecordDate and CharacterName in a composite foreign key; a character
  name alone is no longer a unique key across history.

CHANGE LOG
Date         Version   Change
-----------  --------  --------------------------------------------------------
2026-10-18   1.0.0     Initial characters.Character table definition.
2026-10-18   1.0.1     Document Markdown convention for BackStory.
2026-10-18   1.1.0     Change PK to (RecordDate, CharacterName); add Active and
                        filtered unique index for active record per name.
===============================================================================
*/

USE [DnD];
GO

-- 1. Confirm prerequisite schema.
IF SCHEMA_ID(N'characters') IS NULL
    THROW 51000, 'Schema [characters] does not exist; run Database/database/dnd.sql first.', 1;
GO

-- 2. Create only if absent. Never alter or replace an existing table implicitly.
IF OBJECT_ID(N'characters.Character', N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[Character]
    (
    [RecordDate] DATE NOT NULL
        CONSTRAINT [DF_Character_RecordDate] DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [CharacterName]    NVARCHAR(60)  NOT NULL,
        [Active]           BIT           NOT NULL
            CONSTRAINT [DF_Character_Active] DEFAULT (1),
        [Surname]          NVARCHAR(60)  NULL,
        [Moniker]          NVARCHAR(160) NOT NULL,
        [Race]             NVARCHAR(40)  NOT NULL,
        [InitialClass]     NVARCHAR(40)  NOT NULL,
        [Sex]              NVARCHAR(20)  NULL,
        [InitialAge]       SMALLINT      NOT NULL,
        [InitialAlignment] NVARCHAR(20)  NOT NULL,
        [Strength]         TINYINT       NOT NULL,
        [Intelligence]     TINYINT       NOT NULL,
        [Wisdom]           TINYINT       NOT NULL,
        [Constitution]     TINYINT       NOT NULL,
        [Dexterity]        TINYINT       NOT NULL,
        [Charisma]         TINYINT       NOT NULL,
        [BaseAC]           TINYINT       NOT NULL,
        [BackStory]        NVARCHAR(MAX) NOT NULL,

        CONSTRAINT [PK_Character]
            PRIMARY KEY CLUSTERED ([RecordDate], [CharacterName]),
        CONSTRAINT [CK_Character_InitialAge]
            CHECK ([InitialAge] BETWEEN 1 AND 200),
        CONSTRAINT [CK_Character_InitialAlignment]
            CHECK ([InitialAlignment] IN (N'Lawful', N'Neutral', N'Chaotic')),
        CONSTRAINT [CK_Character_Strength]     CHECK ([Strength] BETWEEN 3 AND 18),
        CONSTRAINT [CK_Character_Intelligence] CHECK ([Intelligence] BETWEEN 3 AND 18),
        CONSTRAINT [CK_Character_Wisdom]       CHECK ([Wisdom] BETWEEN 3 AND 18),
        CONSTRAINT [CK_Character_Constitution] CHECK ([Constitution] BETWEEN 3 AND 18),
        CONSTRAINT [CK_Character_Dexterity]    CHECK ([Dexterity] BETWEEN 3 AND 18),
        CONSTRAINT [CK_Character_Charisma]     CHECK ([Charisma] BETWEEN 3 AND 18)
    );

    -- One active version per character; inactive versions may be unlimited.
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Character_OneActivePerName]
        ON [characters].[Character] ([CharacterName])
        WHERE [Active] = 1;

    PRINT N'Created characters.Character with compound PK and versioning.';
END
ELSE
BEGIN
    -- Avoid implying that a table with the old CharacterName-only PK is valid.
    IF COL_LENGTH(N'characters.Character', N'RecordDate') IS NULL
       OR COL_LENGTH(N'characters.Character', N'Active') IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.key_constraints AS pk
           JOIN sys.index_columns AS i1
             ON i1.object_id = pk.parent_object_id
            AND i1.index_id = pk.unique_index_id AND i1.key_ordinal = 1
           JOIN sys.columns AS c1
             ON c1.object_id = i1.object_id AND c1.column_id = i1.column_id
           JOIN sys.index_columns AS i2
             ON i2.object_id = pk.parent_object_id
            AND i2.index_id = pk.unique_index_id AND i2.key_ordinal = 2
           JOIN sys.columns AS c2
             ON c2.object_id = i2.object_id AND c2.column_id = i2.column_id
           WHERE pk.parent_object_id = OBJECT_ID(N'characters.Character', N'U')
             AND pk.[type] = 'PK'
             AND c1.[name] = N'RecordDate'
             AND c2.[name] = N'CharacterName'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes AS ix
           WHERE ix.object_id = OBJECT_ID(N'characters.Character', N'U')
             AND ix.[name] = N'UX_Character_OneActivePerName'
             AND ix.is_unique = 1 AND ix.has_filter = 1
       )
    BEGIN
        THROW 51001,
              'Existing characters.Character has an older/incompatible design. Do NOT drop it. Review a data-preserving migration before running the Evro insert.',
              1;
    END;

    PRINT N'characters.Character already exists with versioning; no changes applied.';
END;
GO

-- 3. Read-only verification.
SELECT
    DB_NAME() AS DatabaseName,
    s.[name] AS SchemaName,
    t.[name] AS TableName,
    i.[name] AS IndexName,
    i.is_unique AS IsUnique,
    i.has_filter AS IsFiltered,
    i.filter_definition AS FilterDefinition
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
LEFT JOIN sys.indexes AS i
  ON i.object_id = t.object_id AND i.[name] = N'UX_Character_OneActivePerName'
WHERE s.[name] = N'characters'
  AND t.[name] = N'Character';
GO
