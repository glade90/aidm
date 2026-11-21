/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAppearance.sql
Repository Path : Database/tables/CharacterAppearance.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Record a character's canonical physical appearance for an
                  adventure, independently of individual artwork and outings.
Target Server   : PEQUOD (default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAppearance
Version         : 1.1.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/database/dnd.sql (DnD + characters schema)
                  Database/tables/Character.sql (character identity)

DESIGN NOTES
- One appearance record describes how a character looks during an ADVENTURE,
  not a particular expedition or a particular generated illustration.
- NO image paths, image IDs, picture titles or expedition numbers here.
  Image assets will be stored separately in a future image table.
- RecordDate uses the UTC calendar DATE, not a timestamp.
- Historical versions use (RecordDate, CharacterName, Adventure) as the PK.
  This permits one version per character/adventure/day.
- Active = 1 selects the approved current appearance for that adventure.
  A filtered unique index prevents multiple active versions of the same pair.
- CharacterName relates to characters.Character by its natural name. Since
  characters.Character is versioned and CharacterName alone is NOT unique,
  a direct FK on just that column is impossible. A future association strategy
  can be designed separately. Do not add an arbitrary version binding here.
- Adventure holds a short identifier (for example 'B1'). Once the Adventure
  table is agreed, this column can be migrated to a true foreign key.
- AppearanceNotes is Markdown-friendly NVARCHAR(MAX), documenting artistic
  decisions and changes (including the provenance of lasting scars).
- No automatic drop or migration. If the earlier image-oriented table was
  created, stop and design a data-preserving migration.

CHANGE LOG
Date         Version   Change
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Initial proposal: illustration/scenes and image locations.
2026-10-18   1.1.0     Correct table purpose to enduring physical appearance;
                        remove images, scenes and expedition fields; add
                        individual appearance descriptors, Adventure and notes.
===============================================================================
*/

USE [DnD];
GO

IF SCHEMA_ID(N'characters') IS NULL
    THROW 51200, 'Missing [characters] schema. Run Database/database/dnd.sql first.', 1;

IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 51201, 'Missing [characters].[Character] table. Run Character.sql first.', 1;

-- Creation only; never silently alter or discard an older table.
IF OBJECT_ID(N'characters.CharacterAppearance', N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterAppearance]
    (
        [RecordDate]           DATE           NOT NULL
            CONSTRAINT [DF_CharacterAppearance_RecordDate]
            DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [CharacterName]        NVARCHAR(60)   NOT NULL,
        [Adventure]            NVARCHAR(100)  NOT NULL,
        [Active]               BIT            NOT NULL
            CONSTRAINT [DF_CharacterAppearance_Active] DEFAULT (1),

        [HeightDescription]    NVARCHAR(120)  NULL,
        [BuildDescription]     NVARCHAR(250)  NULL,
        [HairColor]            NVARCHAR(60)   NULL,
        [HairDescription]      NVARCHAR(250)  NULL,
        [FacialHair]           NVARCHAR(200)  NULL,
        [EyeColor]             NVARCHAR(60)   NULL,
        [FaceDescription]      NVARCHAR(350)  NULL,
        [Scars]                NVARCHAR(500)  NULL,
        [OverallImpression]    NVARCHAR(350)  NULL,
        [AppearanceNotes]      NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_CharacterAppearance]
            PRIMARY KEY CLUSTERED ([RecordDate], [CharacterName], [Adventure])
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterAppearance_ActiveCharacterAdventure]
        ON [characters].[CharacterAppearance] ([CharacterName], [Adventure])
        WHERE [Active] = 1;

    PRINT N'Created characters.CharacterAppearance (physical descriptions only).';
END
ELSE
BEGIN
    -- Fail clearly if an old illustration-based table is already installed.
    IF COL_LENGTH(N'characters.CharacterAppearance', N'ImagePath') IS NOT NULL
       OR COL_LENGTH(N'characters.CharacterAppearance', N'AppearanceCode') IS NOT NULL
       OR COL_LENGTH(N'characters.CharacterAppearance', N'HeightDescription') IS NULL
       OR COL_LENGTH(N'characters.CharacterAppearance', N'AppearanceNotes') IS NULL
       OR COL_LENGTH(N'characters.CharacterAppearance', N'Adventure') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes
           WHERE object_id = OBJECT_ID(N'characters.CharacterAppearance', N'U')
             AND [name] = N'UX_CharacterAppearance_ActiveCharacterAdventure'
             AND is_unique = 1 AND has_filter = 1
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.key_constraints AS pk
           JOIN sys.index_columns AS i1
                ON i1.object_id = pk.parent_object_id
               AND i1.index_id = pk.unique_index_id
               AND i1.key_ordinal = 1
           JOIN sys.columns AS c1
                ON c1.object_id = i1.object_id AND c1.column_id = i1.column_id
           JOIN sys.index_columns AS i2
                ON i2.object_id = pk.parent_object_id
               AND i2.index_id = pk.unique_index_id
               AND i2.key_ordinal = 2
           JOIN sys.columns AS c2
                ON c2.object_id = i2.object_id AND c2.column_id = i2.column_id
           JOIN sys.index_columns AS i3
                ON i3.object_id = pk.parent_object_id
               AND i3.index_id = pk.unique_index_id
               AND i3.key_ordinal = 3
           JOIN sys.columns AS c3
                ON c3.object_id = i3.object_id AND c3.column_id = i3.column_id
           WHERE pk.parent_object_id = OBJECT_ID(N'characters.CharacterAppearance', N'U')
             AND pk.[type] = 'PK'
             AND c1.[name] = N'RecordDate'
             AND c2.[name] = N'CharacterName'
             AND c3.[name] = N'Adventure'
       )
    BEGIN
        THROW 51202,
              'An incompatible CharacterAppearance table exists. Do not drop it; request a reviewed, data-preserving migration.',
              1;
    END;

    PRINT N'CharacterAppearance already exists in the approved form; no changes applied.';
END;
GO

-- Read-only verification.
SELECT
    DB_NAME() AS DatabaseName,
    s.[name] AS SchemaName,
    t.[name] AS TableName
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.[name] = N'characters'
  AND t.[name] = N'CharacterAppearance';
GO
