/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Languages.sql
Repository Path : Database/tables/Languages.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create a versioned catalog of Mentzer Basic languages.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Languages
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Rules.sql
Source          : 1983 Mentzer Basic D&D Players Manual pp.45-46,51,56;
                  Dungeon Masters Rulebook p.18 (uploaded Core Rules PDF).

DESIGN NOTES
- PK (RecordDate, RulesetCode, LanguageCode); UTC date, no time.
- Exactly one active version per ruleset/language code.
- The DM list is a list of 20 entries, not 20 plus Common/alignment.
- Other human tongue is a PLACEHOLDER (not one specific tongue).
- Ogre or Giant is one combined entry, matching the book.
- Alignment tongues are not written (Player Manual p.56).
- WrittenFormAllowed NULL means not specified, NOT automatically yes.
- No silent alter/drop or migration if existing schema is different.

CHANGE LOG
Date         Version   Change
-----------  --------  --------------------------------------------------------
2026-10-18   1.0.0     Initial approved design proposal and implementation.
===============================================================================
*/
USE [DnD];
GO
IF SCHEMA_ID(N'Rules') IS NULL
    THROW 55100, 'Missing [Rules] schema. Execute Database/schemas/Rules.sql.', 1;
GO

IF OBJECT_ID(N'Rules.Languages', N'U') IS NULL
BEGIN
    CREATE TABLE [Rules].[Languages]
    (
        [RecordDate]           DATE          NOT NULL
            CONSTRAINT [DF_Languages_RecordDate] DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [RulesetCode]          NVARCHAR(80)  NOT NULL,
        [LanguageCode]         NVARCHAR(50)  NOT NULL,
        [LanguageName]         NVARCHAR(100) NOT NULL,
        [Active]               BIT           NOT NULL CONSTRAINT [DF_Languages_Active] DEFAULT (1),
        [LanguageKind]         NVARCHAR(20)  NOT NULL,
        [ListPosition]         TINYINT       NULL,
        [ExtraLanguageOption]  BIT           NOT NULL,
        [WrittenFormAllowed]   BIT           NULL,
        [SourceReference]      NVARCHAR(250) NOT NULL,
        [NotesMarkdown]        NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_Languages]
            PRIMARY KEY CLUSTERED ([RecordDate], [RulesetCode], [LanguageCode]),
        CONSTRAINT [CK_Languages_Kind]
            CHECK ([LanguageKind] IN (N'Ordinary', N'Alignment', N'Placeholder')),
        CONSTRAINT [CK_Languages_ListPosition]
            CHECK ([ListPosition] IS NULL OR [ListPosition] BETWEEN 1 AND 20),
        CONSTRAINT [CK_Languages_AlignmentUnwritten]
            CHECK ([LanguageKind] <> N'Alignment' OR [WrittenFormAllowed] = 0),
        CONSTRAINT [CK_Languages_PlaceholderNotChoice]
            CHECK ([LanguageKind] <> N'Placeholder' OR [ExtraLanguageOption] = 0)
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Languages_OneActive]
        ON [Rules].[Languages] ([RulesetCode], [LanguageCode])
        WHERE [Active] = 1;
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Languages_OneActiveListPosition]
        ON [Rules].[Languages] ([RulesetCode], [ListPosition])
        WHERE [Active] = 1 AND [ListPosition] IS NOT NULL;
    PRINT N'Created Rules.Languages.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'Rules.Languages', N'RecordDate') IS NULL
       OR COL_LENGTH(N'Rules.Languages', N'RulesetCode') IS NULL
       OR COL_LENGTH(N'Rules.Languages', N'LanguageCode') IS NULL
       OR COL_LENGTH(N'Rules.Languages', N'LanguageKind') IS NULL
       OR COL_LENGTH(N'Rules.Languages', N'ExtraLanguageOption') IS NULL
       OR COL_LENGTH(N'Rules.Languages', N'WrittenFormAllowed') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns AS c
           JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'Rules.Languages', N'U')
             AND c.[name] = N'RecordDate' AND ty.[name] = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes AS ix
           WHERE ix.object_id = OBJECT_ID(N'Rules.Languages', N'U')
             AND ix.[name] = N'UX_Languages_OneActive'
             AND ix.is_unique = 1 AND ix.has_filter = 1
       )
    BEGIN
        THROW 55101, 'An incompatible Rules.Languages table exists. Review a data-preserving migration.', 1;
    END;
    PRINT N'Rules.Languages already exists; no changes applied.';
END;
GO

SELECT [RulesetCode], [LanguageCode], [LanguageName], [LanguageKind],
       [ListPosition], [ExtraLanguageOption], [WrittenFormAllowed], [Active]
FROM [Rules].[Languages]
ORDER BY [RulesetCode], [ListPosition], [LanguageName];
GO
