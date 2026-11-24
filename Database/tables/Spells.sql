/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Spells.sql
Repository Path : Database/tables/Spells.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Define source-accurate, versioned spell rules and class variants.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Spells
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Rules.sql (existing schema)
Source          : 1983 Mentzer D&D Basic Players Manual, printed pp. 25-27, 35, 38-41; DM Rulebook p. 18.

DESIGN NOTES
- One row per ruleset / spellcasting class / spell level / spell code / UTC date.
- Elf spellcasting uses Magic-User spells; no duplicate Elf catalog is seeded.
- Shared names get separate Cleric and Magic-User rows when mechanics differ.
- RangeFeet only populated for numeric ranges; 0 denotes caster-centered.
- Duration fields hold exact text, including variable durations; fixed numeric
  fields are NULL whenever the duration varies or is conditional.
- All first-level stats are drawn from the Basic Players Manual descriptions.
- Revocable history uses Active; at most one active version of each spell.
- Never silently alter, drop, or overwrite an existing spell table.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial implementation and source-checked design.
===============================================================================
*/

USE [DnD];
GO
IF SCHEMA_ID(N'Rules') IS NULL
    THROW 56000, 'Missing Rules schema. Run Rules.sql first.', 1;
GO
IF OBJECT_ID(N'Rules.Spells', N'U') IS NULL
BEGIN
    CREATE TABLE [Rules].[Spells]
    (
        [RecordDate]        DATE           NOT NULL
            CONSTRAINT [DF_Spells_RecordDate] DEFAULT (CONVERT(DATE,SYSUTCDATETIME())),
        [RulesetCode]       NVARCHAR(80)   NOT NULL,
        [SpellClass]        NVARCHAR(40)   NOT NULL,
        [SpellLevel]        TINYINT        NOT NULL,
        [SpellCode]         NVARCHAR(60)   NOT NULL,
        [Active]            BIT            NOT NULL
            CONSTRAINT [DF_Spells_Active] DEFAULT (1),
        [SpellName]         NVARCHAR(120)  NOT NULL,
        [ListPosition]      TINYINT        NOT NULL,
        [RangeText]         NVARCHAR(140)  NOT NULL,
        [RangeFeet]         SMALLINT       NULL,
        [DurationText]      NVARCHAR(180)  NOT NULL,
        [DurationTurns]     SMALLINT       NULL,
        [DurationRounds]    SMALLINT       NULL,
        [EffectText]        NVARCHAR(600)  NOT NULL,
        [DamageHealingText] NVARCHAR(180)  NULL,
        [SavingThrowText]   NVARCHAR(300)  NULL,
        [ReversibleInExpert] BIT           NOT NULL
            CONSTRAINT [DF_Spells_ReversibleInExpert] DEFAULT (0),
        [RulesMarkdown]     NVARCHAR(MAX)  NOT NULL,
        [SourceReference]   NVARCHAR(320)  NOT NULL,
        CONSTRAINT [PK_Spells] PRIMARY KEY CLUSTERED
            ([RecordDate],[RulesetCode],[SpellClass],[SpellLevel],[SpellCode]),
        CONSTRAINT [CK_Spells_Level] CHECK ([SpellLevel] BETWEEN 1 AND 9),
        CONSTRAINT [CK_Spells_ListPosition] CHECK ([ListPosition] BETWEEN 1 AND 99),
        CONSTRAINT [CK_Spells_Range] CHECK ([RangeFeet] IS NULL OR [RangeFeet] >= 0),
        CONSTRAINT [CK_Spells_Duration] CHECK
            (([DurationTurns] IS NULL OR [DurationTurns] >= 1) AND
             ([DurationRounds] IS NULL OR [DurationRounds] >= 1)),
        CONSTRAINT [CK_Spells_Classes] CHECK
            ([SpellClass] IN (N'Magic-User',N'Cleric'))
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Spells_OneActive]
        ON [Rules].[Spells] ([RulesetCode],[SpellClass],[SpellLevel],[SpellCode])
        WHERE [Active]=1;
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Spells_OneActiveListPosition]
        ON [Rules].[Spells] ([RulesetCode],[SpellClass],[SpellLevel],[ListPosition])
        WHERE [Active]=1;
    PRINT N'Created Rules.Spells.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'Rules.Spells',N'RecordDate') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'RulesetCode') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'SpellClass') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'SpellLevel') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'SpellCode') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'RangeFeet') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'DurationText') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'RulesMarkdown') IS NULL
       OR COL_LENGTH(N'Rules.Spells',N'Active') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns c
           JOIN sys.types ty ON ty.user_type_id=c.user_type_id
           WHERE c.object_id=OBJECT_ID(N'Rules.Spells',N'U')
             AND c.name=N'RecordDate' AND ty.name=N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes i
           WHERE i.object_id=OBJECT_ID(N'Rules.Spells',N'U')
             AND i.name=N'UX_Spells_OneActive' AND i.is_unique=1 AND i.has_filter=1
       )
    BEGIN
        THROW 56001, 'An incompatible Rules.Spells exists. Review a data-preserving migration.', 1;
    END;
    PRINT N'Rules.Spells already exists in approved form. No changes made.';
END;
GO
SELECT [RulesetCode], [SpellClass], [SpellLevel], COUNT(*) AS ActiveSpells
FROM [Rules].[Spells] WHERE [Active]=1
GROUP BY [RulesetCode],[SpellClass],[SpellLevel]
ORDER BY [RulesetCode],[SpellClass],[SpellLevel];
GO
