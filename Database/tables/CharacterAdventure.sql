/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAdventure.sql
Repository Path : Database/tables/CharacterAdventure.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Associate a character with an adventure, recording when the
                  character joined and the optional selected character-card art.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAdventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Character.sql
                  Database/tables/Adventure.sql
                  Database/database/dnd.sql (characters schema)

DESIGN NOTES
- One CharacterAdventure association per character/adventure, versioned daily.
- RecordDate DATE + CharacterName + AdventureCode form the primary key.
- Active identifies the current association version; a filtered unique index
  permits one active version per character/adventure.
- InitialExpedition is the FIRST outing that character joined for this adventure,
  not the adventure's first expedition and not the current expedition.
- CardImagePath is OPTIONAL and references an illustration chosen for this
  adventure. CharacterAppearance holds enduring visual traits, not image links.
- CardImagePath can contain a Windows path; the future Flask app must resolve
  access from whichever computer runs it (PEQUOD/ALBATROSS).
- CharacterRecordDate / AdventureRecordDate preserve referential integrity by
  pointing to specific parent versions. The parents' PKs are composite; names
  and adventure codes alone are NOT unique over the entire version history.
- These FK dates are historical references, not auto-updating "active" links.
- One version per character/adventure per UTC day, owing to DATE primary key.
- Notes is Markdown-friendly NVARCHAR(MAX).
- This initial CREATE script does not drop, alter, or migrate existing tables.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Initial versioned association, first expedition and
                        optional card-image path; composite parent FKs.
===============================================================================
*/

USE [DnD];
GO

IF SCHEMA_ID(N'characters') IS NULL
    THROW 51400, 'Missing characters schema.', 1;
IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 51401, 'Missing characters.Character. Run Character.sql first.', 1;
IF OBJECT_ID(N'dbo.Adventure', N'U') IS NULL
    THROW 51402, 'Missing dbo.Adventure. Run Adventure.sql first.', 1;
GO

IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterAdventure]
    (
        [RecordDate]          DATE           NOT NULL
            CONSTRAINT [DF_CharacterAdventure_RecordDate]
                DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [CharacterName]       NVARCHAR(60)   NOT NULL,
        [AdventureCode]       NVARCHAR(100)  NOT NULL,
        [Active]              BIT            NOT NULL
            CONSTRAINT [DF_CharacterAdventure_Active] DEFAULT (1),
        [CharacterRecordDate] DATE           NOT NULL,
        [AdventureRecordDate] DATE           NOT NULL,
        [InitialExpedition]     INT            NOT NULL,
        [CharacterRole]       NVARCHAR(40)   NULL,
        [CardImagePath]       NVARCHAR(1024) NULL,
        [Notes]               NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_CharacterAdventure]
            PRIMARY KEY CLUSTERED ([RecordDate], [CharacterName], [AdventureCode]),
        CONSTRAINT [CK_CharacterAdventure_InitialExpedition]
            CHECK ([InitialExpedition] >= 1),
        CONSTRAINT [FK_CharacterAdventure_Character]
            FOREIGN KEY ([CharacterRecordDate], [CharacterName])
            REFERENCES [characters].[Character] ([RecordDate], [CharacterName]),
        CONSTRAINT [FK_CharacterAdventure_Adventure]
            FOREIGN KEY ([AdventureRecordDate], [AdventureCode])
            REFERENCES [dbo].[Adventure] ([RecordDate], [AdventureCode])
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterAdventure_OneActive]
        ON [characters].[CharacterAdventure] ([CharacterName], [AdventureCode])
        WHERE [Active] = 1;

    PRINT N'Created characters.CharacterAdventure.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'characters.CharacterAdventure', N'CardImagePath') IS NULL
       OR COL_LENGTH(N'characters.CharacterAdventure', N'CharacterRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterAdventure', N'AdventureRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterAdventure', N'InitialExpedition') IS NULL
       OR COL_LENGTH(N'characters.CharacterAdventure', N'Active') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes
           WHERE object_id = OBJECT_ID(N'characters.CharacterAdventure', N'U')
             AND [name] = N'UX_CharacterAdventure_OneActive'
             AND is_unique = 1 AND has_filter = 1
       )
    BEGIN
        THROW 51403,
              'An incompatible CharacterAdventure table exists. Review a data-preserving migration.', 1;
    END;
    PRINT N'CharacterAdventure exists; no data or schema changed.';
END;
GO

-- Read-only verification.
SELECT [RecordDate], [CharacterName], [AdventureCode], [Active],
       [CharacterRecordDate], [AdventureRecordDate], [InitialExpedition],
       [CharacterRole], [CardImagePath]
FROM [characters].[CharacterAdventure]
ORDER BY [CharacterName], [AdventureCode], [RecordDate] DESC;
GO
