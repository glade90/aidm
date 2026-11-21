/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterSpell.sql
Repository Path : Database/tables/CharacterSpell.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Record permanently available character spellbook spells, not daily preparation.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterSpell
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Rules.sql; Spells.sql
Source          : 1983 Mentzer D&D Basic Players Manual, printed pp. 25-27, 35, 38-41; DM Rulebook p. 18.

DESIGN NOTES
- One version per character/ruleset/class/level/spell/date, with no ID column.
- CharacterRecordDate and SpellRecordDate refer to exact parent versions.
- A starting, teacher-granted, copied-scroll or DM-granted spell belongs in
  this table only if permanently recorded in the character spellbook.
- Clerics can use eligible spells through class access; do NOT create a book
  entry for every cleric spell. Available spell slots are in dbo.ClassLevel.
- Prepared/expended spells change within a day and are DELIBERATELY not kept
  here, because RecordDate DATE allows only one historical version per day.
- Future separate preparation ledger can handle multiple casts/rests/day.
- Active=0 retires an entry (e.g. lost book), preserving earlier history.
- No change to characters.Character, ClassLevel or adventure tables.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial implementation and source-checked design.
===============================================================================
*/

USE [DnD];
GO
IF OBJECT_ID(N'characters.Character',N'U') IS NULL
    THROW 56020, 'characters.Character missing. Run Character.sql first.', 1;
IF OBJECT_ID(N'Rules.Spells',N'U') IS NULL
    THROW 56021, 'Rules.Spells missing. Run Spells.sql first.', 1;
GO
IF OBJECT_ID(N'characters.CharacterSpell',N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterSpell]
    (
        [RecordDate]             DATE           NOT NULL
            CONSTRAINT [DF_CharacterSpell_RecordDate] DEFAULT (CONVERT(DATE,SYSUTCDATETIME())),
        [CharacterName]          NVARCHAR(60)   NOT NULL,
        [RulesetCode]            NVARCHAR(80)   NOT NULL,
        [SpellClass]             NVARCHAR(40)   NOT NULL,
        [SpellLevel]             TINYINT        NOT NULL,
        [SpellCode]              NVARCHAR(60)   NOT NULL,
        [Active]                 BIT            NOT NULL
            CONSTRAINT [DF_CharacterSpell_Active] DEFAULT (1),
        [CharacterRecordDate]    DATE           NOT NULL,
        [SpellRecordDate]        DATE           NOT NULL,
        [AcquisitionMethod]     NVARCHAR(30)   NOT NULL,
        [LearnedOn]              DATE           NULL,
        [AcquisitionAdventureCode] NVARCHAR(100) NULL,
        [AcquisitionExpeditionNumber] INT       NULL,
        [SpellbookDescription]   NVARCHAR(250)  NULL,
        [NotesMarkdown]         NVARCHAR(MAX)  NULL,
        CONSTRAINT [PK_CharacterSpell] PRIMARY KEY CLUSTERED
            ([RecordDate],[CharacterName],[RulesetCode],[SpellClass],
             [SpellLevel],[SpellCode]),
        CONSTRAINT [FK_CharacterSpell_Character]
            FOREIGN KEY ([CharacterRecordDate],[CharacterName])
            REFERENCES [characters].[Character]([RecordDate],[CharacterName]),
        CONSTRAINT [FK_CharacterSpell_Spell]
            FOREIGN KEY ([SpellRecordDate],[RulesetCode],[SpellClass],
                         [SpellLevel],[SpellCode])
            REFERENCES [Rules].[Spells]([RecordDate],[RulesetCode],[SpellClass],
                                       [SpellLevel],[SpellCode]),
        CONSTRAINT [CK_CharacterSpell_AcquisitionMethod] CHECK
            ([AcquisitionMethod] IN (N'StartingTeacher',N'LevelTeacher',
                                     N'CopiedScroll',N'DMGranted',N'Other')),
        CONSTRAINT [CK_CharacterSpell_Expedition] CHECK
            ([AcquisitionExpeditionNumber] IS NULL OR
             ([AcquisitionAdventureCode] IS NOT NULL
              AND [AcquisitionExpeditionNumber]>=1))
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterSpell_OneActive]
        ON [characters].[CharacterSpell]
          ([CharacterName],[RulesetCode],[SpellClass],[SpellLevel],[SpellCode])
        WHERE [Active]=1;
    PRINT N'Created characters.CharacterSpell.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'characters.CharacterSpell',N'RecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterSpell',N'CharacterName') IS NULL
       OR COL_LENGTH(N'characters.CharacterSpell',N'CharacterRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterSpell',N'SpellRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterSpell',N'SpellCode') IS NULL
       OR COL_LENGTH(N'characters.CharacterSpell',N'AcquisitionMethod') IS NULL
       OR COL_LENGTH(N'characters.CharacterSpell',N'Active') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns c
           JOIN sys.types ty ON ty.user_type_id=c.user_type_id
           WHERE c.object_id=OBJECT_ID(N'characters.CharacterSpell',N'U')
             AND c.name=N'RecordDate' AND ty.name=N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes i
           WHERE i.object_id=OBJECT_ID(N'characters.CharacterSpell',N'U')
             AND i.name=N'UX_CharacterSpell_OneActive'
             AND i.is_unique=1 AND i.has_filter=1
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.foreign_keys fk
           WHERE fk.parent_object_id=OBJECT_ID(N'characters.CharacterSpell',N'U')
             AND fk.name=N'FK_CharacterSpell_Spell'
       )
    BEGIN
        THROW 56022, 'An incompatible characters.CharacterSpell exists. Review data-preserving migration.', 1;
    END;
    PRINT N'characters.CharacterSpell already exists. No changes made.';
END;
GO
SELECT [CharacterName],[RulesetCode],[SpellClass],[SpellLevel],[SpellCode],
       [AcquisitionMethod],[Active]
FROM [characters].[CharacterSpell]
ORDER BY [CharacterName],[SpellLevel],[SpellCode],[RecordDate] DESC;
GO
