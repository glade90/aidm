/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLevel_Ralt_L1_Insert.sql
Repository Path : Database/tables/CharacterLevel_Ralt_L1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Ralt level 1 Magic-User snapshot with max HP 4 and ability-adjusted saves.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterLevel
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character_Ralt_Insert.sql; ClassLevel.sql; ClassLevel_Mentzer_Basic_Insert.sql; CharacterLevel.sql

DESIGN NOTES
- First Magic-User Hit Die d4 maximized to 4; CON9 contributes 0.
- INT18 => +10% XP. WIS7 => -1 magic saving throw bonus (i.e.,
  negative adjustment, separate from raw class save targets).
- Reference ClassLevel for the five level-1 base saving throws.
- Prepared spell Magic Missile mentioned in Notes; spells belong elsewhere.
- Does not modify historic Expedition 12 StartHP=1.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial Ralt seed; locked abilities, B1 portrait,
                        established history and unsettled Expedition 12.
===============================================================================
*/

USE [DnD];
GO
SET XACT_ABORT ON;
GO


IF OBJECT_ID(N'characters.CharacterLevel', N'U') IS NULL
    THROW 53230, 'Missing characters.CharacterLevel.', 1;
IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
    THROW 53231, 'Missing dbo.ClassLevel.', 1;
GO

DECLARE @CharacterDate DATE;
DECLARE @ClassLevelDate DATE;
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## Ralt Gaither — Level 1 Magic-User

- **Locked scores:** STR 11, INT 18, WIS 7, CON 9, DEX 14, CHA 10. The one-time 3d6 Wisdom reroll was 2+3+2=7, so Wisdom remained 7. No Prime Requisite exchange was made.
- **Maximum first Hit Die:** Magic-User 1d4 maximum of 4, plus CON 9 bonus 0 = 4 maximum HP under the newly adopted retroactive house rule.
- **Prime Requisite:** INT 18 grants +10% XP. INT is already maximum.
- **Base saves:** take all five Magic-User level-1 save targets from dbo.ClassLevel, NOT manually adjusted values.
- **Wisdom 7:** WisdomMagicSaveBonus = -1, to be applied to eligible saving throws against magic according to the campaign''s Mentzer ruling. Do not permanently subtract it from the five base scores.
- **Dexterity 14:** +1 missile attack bonus, and 1 point better Armor Class, recorded in the ability score rather than base saves.
- **Spellcasting:** Magic-User level 1 has one first-level casting slot under ClassLevel; Magic Missile is his established prepared spell. Do not add unknown prepared spells or automatically assign other spellbook contents.
- **Historic start:** Expedition 12 recorded Ralt at 1/1 HP before the retroactive new first-die house rule; preserve that in CharacterExpedition rather than rewrite history.');

SELECT @CharacterDate = [RecordDate]
FROM [characters].[Character]
WHERE [CharacterName] = N'Ralt' AND [Active] = 1
  AND [InitialClass] = N'Magic-User'
  AND [Strength] = 11 AND [Intelligence] = 18
  AND [Wisdom] = 7 AND [Constitution] = 9
  AND [Dexterity] = 14 AND [Charisma] = 10;
SELECT @ClassLevelDate = [RecordDate]
FROM [dbo].[ClassLevel]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [Class] = N'Magic-User' AND [Level] = 1 AND [Active] = 1;
IF @CharacterDate IS NULL
    THROW 53232, 'Missing Ralt identity with locked Magic-User scores.', 1;
IF @ClassLevelDate IS NULL
    THROW 53233, 'Missing active MentzerBECMI Magic-User level 1 reference seed.', 1;

IF EXISTS (SELECT 1 FROM [characters].[CharacterLevel]
           WHERE [CharacterName] = N'Ralt' AND [Level] = 1 AND [Active] = 1)
BEGIN
    IF EXISTS
    (
       SELECT 1 FROM [characters].[CharacterLevel]
       WHERE [CharacterName] = N'Ralt' AND [Level] = 1 AND [Active] = 1
         AND ([Class] <> N'Magic-User' OR [RulesetCode] <> N'MentzerBECMI'
              OR [MaxHP] <> 4 OR [ConstitutionHPBonusPerDie] <> 0
              OR [PrimeRequisiteXPBonusPct] <> 10 OR [WisdomMagicSaveBonus] <> -1)
    )
        THROW 53234, 'Active Ralt level 1 differs; do not overwrite.', 1;
    PRINT N'Active Ralt Level 1 matches; preserved.';
END
ELSE IF EXISTS (SELECT 1 FROM [characters].[CharacterLevel]
                WHERE [CharacterName] = N'Ralt' AND [Level] = 1
                  AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME()))
    THROW 53235, 'Ralt Level 1 already has a version today; cannot add another.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterLevel]
    (
        [CharacterName], [Level], [Active], [CharacterRecordDate],
        [ClassLevelRecordDate], [RulesetCode], [Class], [XPWhenReached],
        [MaxHP], [HPGained], [HPDeterminationMethod],
        [ConstitutionHPBonusPerDie], [PrimeRequisiteXPBonusPct],
        [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
        [SaveDragonBreath], [SaveRodsStavesSpells], [WisdomMagicSaveBonus],
        [NotesMarkdown]
    )
    SELECT
        N'Ralt', 1, 1, @CharacterDate, [RecordDate], [RulesetCode],
        [Class], 0, 4, 4, N'Maximum first Magic-User d4 (4); Constitution 9 gives 0',
        0, 10,
        [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
        [SaveDragonBreath], [SaveRodsStavesSpells], -1, @Notes
    FROM [dbo].[ClassLevel]
    WHERE [RecordDate] = @ClassLevelDate
      AND [RulesetCode] = N'MentzerBECMI'
      AND [Class] = N'Magic-User' AND [Level] = 1 AND [Active] = 1;
    PRINT N'Inserted Ralt Magic-User level 1 (MaxHP 4).';
END;
GO

SELECT [RecordDate], [CharacterName], [Class], [Level], [MaxHP],
       [ConstitutionHPBonusPerDie], [PrimeRequisiteXPBonusPct],
       [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
       [SaveDragonBreath], [SaveRodsStavesSpells], [WisdomMagicSaveBonus],
       [Active]
FROM [characters].[CharacterLevel]
WHERE [CharacterName] = N'Ralt' AND [Level] = 1
ORDER BY [RecordDate] DESC;
GO
