/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLevel.sql
Repository Path : Database/tables/CharacterLevel.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Character-specific snapshots of level advancement, HP, saves and bonuses.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Version         : 1.1.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Character.sql; Database/tables/ClassLevel.sql
Source          : 1983 Mentzer D&D Basic Rules, user-supplied PDF (reference seed).

DESIGN NOTES
- PK is (RecordDate, CharacterName, Level); one active snapshot per
  character per ATTAINED level. Old level records stay active when leveling up.
- MaxHP is the maximum hit-point total at this level, not current wounded HP.
- Character saves snapshot the five class saving throw TARGETS; separate
  WisdomMagicSaveBonus applies situationally to magical saving throws.
  Temporary magic equipment bonuses are NOT folded into these targets.
- ConstitutionHPBonusPerDie and PrimeRequisiteXPBonusPct capture personal
  modifiers, rather than adding them to rulebook ClassLevel data.
- XPWhenReached is cumulative XP when attaining a level; NULL if unknown.
- Referenced rule and character VERSION records are immutable via dated FK.
- In-world advancement date and adventure/expedition may be left NULL.
- If a prior draft exists pointing to dbo.Level, stop for migration review.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.1.0     Replace older draft dbo.Level dependency with dbo.ClassLevel; clarify saves and modifiers.
===============================================================================
*/

USE [DnD];
GO

IF SCHEMA_ID(N'characters') IS NULL
    THROW 51920, 'Missing schema characters.', 1;
IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 51921, 'Missing characters.Character.', 1;
IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
    THROW 51922, 'Missing dbo.ClassLevel; create ClassLevel first.', 1;
GO

IF OBJECT_ID(N'characters.CharacterLevel', N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterLevel]
    (
        [RecordDate]                 DATE           NOT NULL
            CONSTRAINT [DF_CharacterLevel_RecordDate] DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [CharacterName]              NVARCHAR(60)   NOT NULL,
        [Level]                      SMALLINT       NOT NULL,
        [Active]                     BIT            NOT NULL
            CONSTRAINT [DF_CharacterLevel_Active] DEFAULT (1),
        [CharacterRecordDate]        DATE           NOT NULL,
        [ClassLevelRecordDate]       DATE           NOT NULL,
        [RulesetCode]                NVARCHAR(80)   NOT NULL,
        [Class]                      NVARCHAR(40)   NOT NULL,
        [XPWhenReached]              INT            NULL,
        [MaxHP]                      SMALLINT       NOT NULL,
        [HPGained]                   SMALLINT       NULL,
        [HPDeterminationMethod]      NVARCHAR(160)  NULL,
        [ConstitutionHPBonusPerDie]  SMALLINT       NOT NULL CONSTRAINT [DF_CharacterLevel_ConBonus] DEFAULT (0),
        [PrimeRequisiteXPBonusPct]   SMALLINT       NOT NULL CONSTRAINT [DF_CharacterLevel_XPBonus] DEFAULT (0),
        [SaveDeathPoison]            TINYINT        NOT NULL,
        [SaveMagicWands]             TINYINT        NOT NULL,
        [SaveParalysisStone]         TINYINT        NOT NULL,
        [SaveDragonBreath]           TINYINT        NOT NULL,
        [SaveRodsStavesSpells]       TINYINT        NOT NULL,
        [WisdomMagicSaveBonus]       SMALLINT       NOT NULL CONSTRAINT [DF_CharacterLevel_WisSave] DEFAULT (0),
        [LevelReachedOn]             DATE           NULL,
        [LevelGainedAdventureCode]   NVARCHAR(100)  NULL,
        [LevelGainedExpeditionNumber] INT           NULL,
        [NotesMarkdown]             NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_CharacterLevel] PRIMARY KEY CLUSTERED
            ([RecordDate], [CharacterName], [Level]),
        CONSTRAINT [FK_CharacterLevel_Character]
            FOREIGN KEY ([CharacterRecordDate], [CharacterName])
            REFERENCES [characters].[Character] ([RecordDate], [CharacterName]),
        CONSTRAINT [FK_CharacterLevel_ClassLevel]
            FOREIGN KEY ([ClassLevelRecordDate], [RulesetCode], [Class], [Level])
            REFERENCES [dbo].[ClassLevel] ([RecordDate], [RulesetCode], [Class], [Level]),
        CONSTRAINT [CK_CharacterLevel_Stats] CHECK
            ([Level] >= 1 AND [MaxHP] >= 1 AND
             ([XPWhenReached] IS NULL OR [XPWhenReached] >= 0) AND
             ([HPGained] IS NULL OR [HPGained] >= 1) AND
             [PrimeRequisiteXPBonusPct] BETWEEN -20 AND 10 AND
             [ConstitutionHPBonusPerDie] BETWEEN -3 AND 3 AND
             [WisdomMagicSaveBonus] BETWEEN -3 AND 3),
        CONSTRAINT [CK_CharacterLevel_Saves] CHECK
            ([SaveDeathPoison] BETWEEN 1 AND 20 AND
             [SaveMagicWands] BETWEEN 1 AND 20 AND
             [SaveParalysisStone] BETWEEN 1 AND 20 AND
             [SaveDragonBreath] BETWEEN 1 AND 20 AND
             [SaveRodsStavesSpells] BETWEEN 1 AND 20),
        CONSTRAINT [CK_CharacterLevel_Expedition] CHECK
            ([LevelGainedExpeditionNumber] IS NULL OR
             ([LevelGainedAdventureCode] IS NOT NULL AND
              [LevelGainedExpeditionNumber] >= 1))
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterLevel_OneActivePerLevel]
        ON [characters].[CharacterLevel] ([CharacterName], [Level])
        WHERE [Active] = 1;

    PRINT N'Created characters.CharacterLevel.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'characters.CharacterLevel', N'MaxHP') IS NULL
       OR COL_LENGTH(N'characters.CharacterLevel', N'ClassLevelRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterLevel', N'WisdomMagicSaveBonus') IS NULL
       OR COL_LENGTH(N'characters.CharacterLevel', N'PrimeRequisiteXPBonusPct') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns AS c
           JOIN sys.types AS t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'characters.CharacterLevel', N'U')
             AND c.[name] = N'RecordDate' AND t.[name] = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.foreign_keys AS fk
           WHERE fk.parent_object_id = OBJECT_ID(N'characters.CharacterLevel', N'U')
             AND fk.[name] = N'FK_CharacterLevel_ClassLevel'
             AND fk.referenced_object_id = OBJECT_ID(N'dbo.ClassLevel', N'U')
       )
    BEGIN
        THROW 51923, 'Existing characters.CharacterLevel has incompatible old design. Review migration; no data changed.', 1;
    END;
    PRINT N'characters.CharacterLevel already exists.';
END;
GO

SELECT [CharacterName], [Class], [Level], [MaxHP], [Active]
FROM [characters].[CharacterLevel]
ORDER BY [CharacterName], [Level], [RecordDate];
GO
