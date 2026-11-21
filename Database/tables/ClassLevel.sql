/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : ClassLevel.sql
Repository Path : Database/tables/ClassLevel.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Versioned, class-wide advancement and fixed rules reference.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : dbo
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/database/dnd.sql
Source          : 1983 Mentzer D&D Basic Rules, user-supplied PDF (reference seed).

DESIGN NOTES
- Exactly one active row for each (RulesetCode, Class, Level).
- RecordDate is a UTC DATE; one version per ruleset/class/level/date.
- MinXP and MaxXP are INCLUSIVE cumulative XP boundaries.
- NULL MaxXP means the next threshold is NOT YET VERIFIED, not infinite XP.
- SpellSlotsLevel1..9 are casting allowances, not spells known.
- Saving throws here are the class baseline; character modifiers go in
  characters.CharacterLevel.
- Turning codes: N = no effect, T = automatically turn, number = 2d6 target.
- Special skills and class features are class/level rules, not personal choices.
- Does not alter dbo.Level if that old draft table happens to exist.
- Existing incompatible dbo.ClassLevel is never dropped or overwritten.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Create dbo.ClassLevel and protective indexes.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ClassLevel]
    (
        [RecordDate]             DATE          NOT NULL
            CONSTRAINT [DF_ClassLevel_RecordDate] DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [RulesetCode]            NVARCHAR(80)  NOT NULL,
        [Class]                  NVARCHAR(40)  NOT NULL,
        [Level]                  SMALLINT      NOT NULL,
        [Active]                 BIT           NOT NULL
            CONSTRAINT [DF_ClassLevel_Active] DEFAULT (1),
        [MinXP]                  INT           NOT NULL,
        [MaxXP]                  INT           NULL,
        [Title]                  NVARCHAR(100) NOT NULL,
        [PrimeRequisite]         NVARCHAR(100) NOT NULL,
        [HitDieSides]            TINYINT       NOT NULL,
        [HitDiceAtLevel]         SMALLINT      NOT NULL,
        [SaveDeathPoison]        TINYINT       NOT NULL,
        [SaveMagicWands]         TINYINT       NOT NULL,
        [SaveParalysisStone]     TINYINT       NOT NULL,
        [SaveDragonBreath]       TINYINT       NOT NULL,
        [SaveRodsStavesSpells]   TINYINT       NOT NULL,
        [SpellSlotsLevel1]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell1] DEFAULT (0),
        [SpellSlotsLevel2]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell2] DEFAULT (0),
        [SpellSlotsLevel3]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell3] DEFAULT (0),
        [SpellSlotsLevel4]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell4] DEFAULT (0),
        [SpellSlotsLevel5]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell5] DEFAULT (0),
        [SpellSlotsLevel6]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell6] DEFAULT (0),
        [SpellSlotsLevel7]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell7] DEFAULT (0),
        [SpellSlotsLevel8]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell8] DEFAULT (0),
        [SpellSlotsLevel9]       TINYINT       NOT NULL CONSTRAINT [DF_ClassLevel_Spell9] DEFAULT (0),
        [TurnSkeleton]           NVARCHAR(10)  NULL,
        [TurnZombie]             NVARCHAR(10)  NULL,
        [TurnGhoul]              NVARCHAR(10)  NULL,
        [TurnWight]              NVARCHAR(10)  NULL,
        [ThiefOpenLocksPct]      TINYINT       NULL,
        [ThiefFindTrapsPct]      TINYINT       NULL,
        [ThiefRemoveTrapsPct]    TINYINT       NULL,
        [ThiefClimbWallsPct]     TINYINT       NULL,
        [ThiefMoveSilentlyPct]   TINYINT       NULL,
        [ThiefHideInShadowsPct]  TINYINT       NULL,
        [ThiefPickPocketsPct]    TINYINT       NULL,
        [ThiefHearNoiseD6Max]   TINYINT       NULL,
        [ClassFeaturesMarkdown] NVARCHAR(MAX) NULL,
        [AdvancementNotesMarkdown] NVARCHAR(MAX) NULL,
        [SourceReference]        NVARCHAR(300) NOT NULL,
        CONSTRAINT [PK_ClassLevel] PRIMARY KEY CLUSTERED
            ([RecordDate], [RulesetCode], [Class], [Level]),
        CONSTRAINT [CK_ClassLevel_Level] CHECK ([Level] >= 1),
        CONSTRAINT [CK_ClassLevel_XP] CHECK
            ([MinXP] >= 0 AND ([MaxXP] IS NULL OR [MaxXP] >= [MinXP])),
        CONSTRAINT [CK_ClassLevel_HitDice] CHECK
            ([HitDieSides] IN (4, 6, 8, 10, 12) AND [HitDiceAtLevel] >= 1),
        CONSTRAINT [CK_ClassLevel_BaseSaves] CHECK
            ([SaveDeathPoison] BETWEEN 1 AND 20 AND
             [SaveMagicWands] BETWEEN 1 AND 20 AND
             [SaveParalysisStone] BETWEEN 1 AND 20 AND
             [SaveDragonBreath] BETWEEN 1 AND 20 AND
             [SaveRodsStavesSpells] BETWEEN 1 AND 20),
        CONSTRAINT [CK_ClassLevel_HearNoise] CHECK
            ([ThiefHearNoiseD6Max] IS NULL OR
             [ThiefHearNoiseD6Max] BETWEEN 1 AND 6)
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_ClassLevel_OneActiveVersion]
        ON [dbo].[ClassLevel] ([RulesetCode], [Class], [Level])
        WHERE [Active] = 1;

    PRINT N'Created dbo.ClassLevel.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'dbo.ClassLevel', N'MinXP') IS NULL
       OR COL_LENGTH(N'dbo.ClassLevel', N'MaxXP') IS NULL
       OR COL_LENGTH(N'dbo.ClassLevel', N'Title') IS NULL
       OR COL_LENGTH(N'dbo.ClassLevel', N'SpellSlotsLevel9') IS NULL
       OR COL_LENGTH(N'dbo.ClassLevel', N'ThiefOpenLocksPct') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns AS c
           JOIN sys.types AS t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'dbo.ClassLevel', N'U')
             AND c.[name] = N'RecordDate' AND t.[name] = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes AS i
           WHERE i.object_id = OBJECT_ID(N'dbo.ClassLevel', N'U')
             AND i.[name] = N'UX_ClassLevel_OneActiveVersion'
             AND i.is_unique = 1 AND i.has_filter = 1
       )
    BEGIN
        THROW 51901, 'Existing dbo.ClassLevel is incompatible; review migration. No changes made.', 1;
    END;
    PRINT N'dbo.ClassLevel already exists with required columns.';
END;
GO

SELECT [Class], COUNT(*) AS ActiveLevelRows
FROM [dbo].[ClassLevel] WHERE [Active] = 1 AND [RulesetCode] = N'MentzerBECMI'
GROUP BY [Class] ORDER BY [Class];
GO
