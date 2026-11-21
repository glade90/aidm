/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLanguage.sql
Repository Path : Database/tables/CharacterLanguage.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Track the languages each character actually knows.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterLanguage
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Rules.sql; Languages.sql; Character.sql
Source          : 1983 Mentzer Basic D&D Players Manual pp.45-46,51,56;
                  Dungeon Masters Rulebook p.18 (uploaded Core Rules PDF).

DESIGN NOTES
- One historical row per character / ruleset / language / UTC date.
- PK (RecordDate, CharacterName, RulesetCode, LanguageCode), DATE only.
- FKs use specific Character and Languages version dates, no numeric IDs.
- At most one currently active row per character/ruleset/language.
- CanRead/CanWrite NULL means unknown, not necessarily unable.
- No invented language proficiency numbers or automatic grant on level-up.
- AcquisitionMethod records automatic, Intelligence, or future DM-approved learning.
- LearnedOn and optional adventure/expedition allow later acquisitions.
- Changing alignment requires a reviewed transition: retire old tongue and add
  the new one; only the appropriate alignment tongue may be active.
- Does not auto-populate character records or choose Ralt's bonus languages.
- No destructive migration of existing records.

CHANGE LOG
Date         Version   Change
-----------  --------  --------------------------------------------------------
2026-10-18   1.0.0     Initial approved design proposal and implementation.
===============================================================================
*/
USE [DnD];
GO
IF SCHEMA_ID(N'characters') IS NULL
    THROW 55120, 'Missing characters schema.', 1;
IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 55121, 'Missing characters.Character.', 1;
IF OBJECT_ID(N'Rules.Languages', N'U') IS NULL
    THROW 55122, 'Missing Rules.Languages; execute Languages.sql first.', 1;
GO

IF OBJECT_ID(N'characters.CharacterLanguage', N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterLanguage]
    (
        [RecordDate]                DATE          NOT NULL
            CONSTRAINT [DF_CharacterLanguage_RecordDate]
            DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [CharacterName]             NVARCHAR(60)  NOT NULL,
        [RulesetCode]               NVARCHAR(80)  NOT NULL,
        [LanguageCode]              NVARCHAR(50)  NOT NULL,
        [Active]                    BIT           NOT NULL
            CONSTRAINT [DF_CharacterLanguage_Active] DEFAULT (1),
        [CharacterRecordDate]       DATE          NOT NULL,
        [LanguageRecordDate]        DATE          NOT NULL,
        [AcquisitionMethod]         NVARCHAR(30)  NOT NULL,
        [LearnedOn]                 DATE          NULL,
        [AcquisitionAdventureCode]  NVARCHAR(100) NULL,
        [AcquisitionExpeditionNumber] INT         NULL,
        [CanSpeak]                  BIT           NOT NULL
            CONSTRAINT [DF_CharacterLanguage_CanSpeak] DEFAULT (1),
        [CanRead]                   BIT           NULL,
        [CanWrite]                  BIT           NULL,
        [NotesMarkdown]             NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_CharacterLanguage]
            PRIMARY KEY CLUSTERED
              ([RecordDate], [CharacterName], [RulesetCode], [LanguageCode]),
        CONSTRAINT [FK_CharacterLanguage_Character]
            FOREIGN KEY ([CharacterRecordDate], [CharacterName])
            REFERENCES [characters].[Character] ([RecordDate], [CharacterName]),
        CONSTRAINT [FK_CharacterLanguage_Language]
            FOREIGN KEY ([LanguageRecordDate], [RulesetCode], [LanguageCode])
            REFERENCES [Rules].[Languages] ([RecordDate], [RulesetCode], [LanguageCode]),
        CONSTRAINT [CK_CharacterLanguage_AcquisitionMethod]
            CHECK ([AcquisitionMethod] IN
                (N'StartingCommon', N'StartingAlignment', N'Racial',
                 N'IntelligenceBonus', N'DMGranted', N'Training')),
        CONSTRAINT [CK_CharacterLanguage_AcquisitionExpedition]
            CHECK ([AcquisitionExpeditionNumber] IS NULL OR
                ([AcquisitionAdventureCode] IS NOT NULL
                 AND [AcquisitionExpeditionNumber] >= 1)),
        CONSTRAINT [CK_CharacterLanguage_WriteRequiresRead]
            CHECK ([CanWrite] IS NULL OR [CanWrite] = 0 OR [CanRead] = 1)
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterLanguage_OneActive]
        ON [characters].[CharacterLanguage]
           ([CharacterName], [RulesetCode], [LanguageCode])
        WHERE [Active] = 1;
    PRINT N'Created characters.CharacterLanguage.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'characters.CharacterLanguage', N'RecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'CharacterRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'LanguageRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'RulesetCode') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'LanguageCode') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'AcquisitionMethod') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'CanSpeak') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'CanRead') IS NULL
       OR COL_LENGTH(N'characters.CharacterLanguage', N'CanWrite') IS NULL
       OR NOT EXISTS
       (
          SELECT 1 FROM sys.columns AS c
          JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
          WHERE c.object_id = OBJECT_ID(N'characters.CharacterLanguage', N'U')
            AND c.[name] = N'RecordDate' AND ty.[name] = N'date'
       )
       OR NOT EXISTS
       (
          SELECT 1 FROM sys.indexes AS ix
          WHERE ix.object_id = OBJECT_ID(N'characters.CharacterLanguage', N'U')
            AND ix.[name] = N'UX_CharacterLanguage_OneActive'
            AND ix.is_unique = 1 AND ix.has_filter = 1
       )
       OR NOT EXISTS
       (
          SELECT 1 FROM sys.foreign_keys
          WHERE parent_object_id = OBJECT_ID(N'characters.CharacterLanguage', N'U')
            AND [name] = N'FK_CharacterLanguage_Language'
       )
    BEGIN
        THROW 55123, 'Incompatible CharacterLanguage exists. Request data-preserving migration.', 1;
    END;
    PRINT N'characters.CharacterLanguage already exists; preserved.';
END;
GO

-- New table intentionally empty until the party's language selections are approved.
SELECT [CharacterName], [RulesetCode], [LanguageCode], [AcquisitionMethod],
       [CanSpeak], [CanRead], [CanWrite], [LearnedOn], [Active]
FROM [characters].[CharacterLanguage]
ORDER BY [CharacterName], [RulesetCode], [LanguageCode], [RecordDate] DESC;
GO
