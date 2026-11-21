/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLevel_Sho-Rembo_L1_Insert.sql
Repository Path : Database/tables/CharacterLevel_Sho-Rembo_L1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Sho's level 1 Halfling advancement snapshot with maximum HP 9.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterLevel
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Character_Sho-Rembo_Insert.sql; ClassLevel.sql; CharacterLevel.sql

DESIGN NOTES
- Uses Halfling Level 1 ClassLevel base saves 8,9,10,13,12.
- MaxHP=6 maximum Halfling d6 + 3 Constitution=9 under house rule.
- No Prime Requisite bonus or Wisdom magic save adjustment.
- No invention of bonus DEX attack modifier because Sho is practiced.
- No XP/advancement expedition association invented for Level 1.

CHANGE LOG
Date         Version   Change
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Initial Sho-Rembo insert, reflecting approved character
                        concept and expedition records.
===============================================================================
*/

USE [DnD];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'characters.CharacterLevel', N'U') IS NULL
    THROW 52400, 'Missing characters.CharacterLevel.', 1;
IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
    THROW 52401, 'Missing dbo.ClassLevel.', 1;
GO
DECLARE @CharacterDate DATE;
DECLARE @ClassLevelDate DATE;
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## Sho-Rembo — Halfling Level 1

- **House rule:** maximum first Hit Die: Halfling 1d6 = 6, plus +3 per Hit Die from Constitution 18, for **9 maximum HP**.
- **Scores after one-time reroll:** STR 9, INT 11, WIS 9, CON 18, DEX 9, CHA 15. The reroll was 4+1+1=6, so the 9 was retained; no two-for-one trade was performed.
- **Halfling abilities:** the canonical class bonuses are in dbo.ClassLevel, including the +1 missile hit bonus. Sho''s strong reputation with a bow does not add a house-rule attack bonus.
- **Prime requisite:** no XP bonus at current STR/DEX scores. Wisdom does not grant a magic-save adjustment.
- **Saving throws:** preserve base Halfling level-1 targets from ClassLevel. Do not conflate them with her armour or the magical shield.
- **HP note:** the 9-HP maximum is the newly approved retroactive level-1 rule, not proof that her historical opening HP in Expedition 12 was 9; the expedition sheet recorded 8/8.
');
SELECT @CharacterDate = [RecordDate]
FROM [characters].[Character]
WHERE [CharacterName] = N'Sho-Rembo' AND [Active] = 1
  AND [InitialClass] = N'Halfling' AND [Constitution] = 18
  AND [Strength] = 9 AND [Dexterity] = 9 AND [Wisdom] = 9;
SELECT @ClassLevelDate = [RecordDate]
FROM [dbo].[ClassLevel]
WHERE [RulesetCode] = N'MentzerBECMI' AND [Class] = N'Halfling'
  AND [Level] = 1 AND [Active] = 1;
IF @CharacterDate IS NULL
    THROW 52402, 'Sho missing active Halfling identity or scores differ from approved values.', 1;
IF @ClassLevelDate IS NULL
    THROW 52403, 'Missing active MentzerBECMI Halfling Level 1 reference row.', 1;
IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterLevel]
    WHERE [CharacterName] = N'Sho-Rembo' AND [Level] = 1
      AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterLevel]
        WHERE [CharacterName] = N'Sho-Rembo' AND [Level] = 1
          AND [Active] = 1
          AND ([Class] <> N'Halfling' OR [MaxHP] <> 9
               OR [ConstitutionHPBonusPerDie] <> 3
               OR [PrimeRequisiteXPBonusPct] <> 0)
    )
        THROW 52404, 'Active Sho Level 1 exists with different class/HP. Review, do not overwrite.', 1;
    PRINT N'Active Sho Level 1 snapshot exists; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterLevel]
    WHERE [CharacterName] = N'Sho-Rembo' AND [Level] = 1
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 52405, 'Sho level 1 has a version today; cannot insert another with DATE PK.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterLevel]
    (
        [CharacterName], [Level], [Active],
        [CharacterRecordDate], [ClassLevelRecordDate], [RulesetCode], [Class],
        [XPWhenReached], [MaxHP], [HPGained], [HPDeterminationMethod],
        [ConstitutionHPBonusPerDie], [PrimeRequisiteXPBonusPct],
        [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
        [SaveDragonBreath], [SaveRodsStavesSpells], [WisdomMagicSaveBonus],
        [NotesMarkdown]
    )
    SELECT N'Sho-Rembo', 1, 1,
           @CharacterDate, [RecordDate], [RulesetCode], [Class],
           0, 9, 9, N'Maximum first Halfling d6 (6) plus CON 18 (+3)',
           3, 0,
           [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
           [SaveDragonBreath], [SaveRodsStavesSpells], 0,
           @Notes
    FROM [dbo].[ClassLevel]
    WHERE [RecordDate] = @ClassLevelDate
      AND [RulesetCode] = N'MentzerBECMI'
      AND [Class] = N'Halfling' AND [Level] = 1 AND [Active] = 1;
    PRINT N'Inserted Sho Halfling Level 1, MaxHP 9.';
END;
GO
SELECT [RecordDate], [CharacterName], [Class], [Level], [MaxHP],
       [ConstitutionHPBonusPerDie], [PrimeRequisiteXPBonusPct],
       [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
       [SaveDragonBreath], [SaveRodsStavesSpells], [Active]
FROM [characters].[CharacterLevel]
WHERE [CharacterName] = N'Sho-Rembo' AND [Level] = 1;
GO
