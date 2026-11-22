/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Skills.sql
Repository Path : Database/tables/Skills.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create the versioned Rules.Skills reference table.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Version         : 1.0.0
Created         : 2026-10-19
Last Modified   : 2026-10-19
Dependencies    : Rules.sql (existing schema)
Source          : D&D Rules Cyclopedia (1991), Chapter 5, p. 82, Sample Skills Table

DESIGN NOTES
- 62 official table entries: STR 3, INT 29, WIS 10, DEX 10, CON 2, CHA 8.
- Art occurs in both Intelligence and Wisdom and has DISTINCT stable codes.
- Skill names/ability associations come from Rules Cyclopedia (1991), NOT
  the 1983 Mentzer Basic Players Manual.
- This is a narrative-only campaign catalog: NO skill checks, bonuses,
  proficiency modifiers, success guarantees, or extra class abilities.
- Original descriptions are short paraphrases, not rule text.
- RulesetCode remains MentzerBECMI for compatibility with DnD campaign tables.
- CatalogCode explicitly records the later 1991 source.
- One active version per ruleset and skill code; new versions must use a
  new RecordDate and deactivate prior version separately after review.
- No DROP/ALTER or silent replacement of existing reference records.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-19   1.0.0     Initial Rules Cyclopedia narrative skill catalog.
===============================================================================
*/

USE [DnD];
GO
IF SCHEMA_ID(N'Rules') IS NULL
    THROW 56200, 'Missing Rules schema. Run Rules.sql first.', 1;
GO
IF OBJECT_ID(N'Rules.Skills', N'U') IS NULL
BEGIN
    CREATE TABLE [Rules].[Skills]
    (
        [RecordDate]           DATE           NOT NULL
            CONSTRAINT [DF_Skills_RecordDate] DEFAULT (CONVERT(DATE,SYSUTCDATETIME())),
        [RulesetCode]          NVARCHAR(80)   NOT NULL,
        [SkillCode]            NVARCHAR(80)   NOT NULL,
        [Active]               BIT            NOT NULL
            CONSTRAINT [DF_Skills_Active] DEFAULT (1),
        [SkillName]            NVARCHAR(120)  NOT NULL,
        [SourceEntry]          NVARCHAR(160)  NOT NULL,
        [AssociatedAbility]    NVARCHAR(20)   NOT NULL,
        [CatalogCode]          NVARCHAR(80)   NOT NULL,
        [SourceListPosition]   SMALLINT       NOT NULL,
        [ChoicePrompt]         NVARCHAR(160)  NULL,
        [NarrativeDescription] NVARCHAR(600)  NOT NULL,
        [NarrativeOnly]        BIT            NOT NULL
            CONSTRAINT [DF_Skills_NarrativeOnly] DEFAULT (1),
        [SourceReference]      NVARCHAR(300)  NOT NULL,
        [NotesMarkdown]       NVARCHAR(MAX)  NULL,
        CONSTRAINT [PK_Skills] PRIMARY KEY CLUSTERED
            ([RecordDate],[RulesetCode],[SkillCode]),
        CONSTRAINT [CK_Skills_AssociatedAbility] CHECK
            ([AssociatedAbility] IN
                (N'Strength',N'Intelligence',N'Wisdom',N'Dexterity',N'Constitution',N'Charisma')),
        CONSTRAINT [CK_Skills_ListPosition] CHECK ([SourceListPosition] BETWEEN 1 AND 32767),
        CONSTRAINT [CK_Skills_NarrativeOnly] CHECK ([NarrativeOnly] = 1),
        CONSTRAINT [CK_Skills_ChoicePrompt] CHECK
            ([ChoicePrompt] IS NULL OR LEN(LTRIM(RTRIM([ChoicePrompt]))) > 0)
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_Skills_OneActive]
        ON [Rules].[Skills] ([RulesetCode],[SkillCode]) WHERE [Active] = 1;
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Skills_ActiveCatalogPosition]
        ON [Rules].[Skills] ([RulesetCode],[CatalogCode],[SourceListPosition])
        WHERE [Active] = 1;
    PRINT N'Created Rules.Skills.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'Rules.Skills', N'RecordDate') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'RulesetCode') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'SkillCode') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'Active') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'SkillName') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'SourceEntry') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'AssociatedAbility') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'CatalogCode') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'SourceListPosition') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'ChoicePrompt') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'NarrativeDescription') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'NarrativeOnly') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'SourceReference') IS NULL
       OR COL_LENGTH(N'Rules.Skills', N'NotesMarkdown') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns c
           JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'Rules.Skills',N'U')
             AND c.name = N'RecordDate' AND t.name = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes i
           WHERE i.object_id = OBJECT_ID(N'Rules.Skills',N'U')
             AND i.name = N'UX_Skills_OneActive' AND i.is_unique = 1 AND i.has_filter = 1
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes i
           WHERE i.object_id = OBJECT_ID(N'Rules.Skills',N'U')
             AND i.name = N'UX_Skills_ActiveCatalogPosition'
             AND i.is_unique = 1 AND i.has_filter = 1
       )
    BEGIN
        THROW 56201, 'Incompatible Rules.Skills already exists; review migration without losing data.', 1;
    END;
    PRINT N'Rules.Skills already exists; no changes made.';
END;
GO
