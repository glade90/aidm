/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLevel_Pell_L1_Insert.sql
Repository Path : Database/tables/CharacterLevel_Pell_L1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Pell's Fighter level-1 snapshot under maximum first-Hit-Die rule.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Table           : characters.CharacterLevel
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Character_Pell_Insert.sql; ClassLevel.sql; ClassLevel_Mentzer_Basic_Insert.sql; CharacterLevel.sql

DESIGN NOTES
- MentzerBECMI Fighter 1: base saves read from dbo.ClassLevel, not guessed.
- MaxHP=8 by retroactive maximum first Fighter d8 (CON 9: +0).
- Prime Requisite XP adjustment=0% (STR 9); magic save bonus=0 (WIS12).
- Dexterity 14 improves missile attacks and AC but does not modify the five
  base saving throw targets in this table.
- XPWhenReached=0, typical level-1 starting threshold; no invented date.
- Historical Expedition 12 start HP was 4; do not overwrite with 8.
- Uses active ClassLevel/Character composite parent FK dates.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial Pell insert: approved reroll, retainer role,
                        narrative card scene; no invented history or XP.
===============================================================================
*/

USE [DnD];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'characters.CharacterLevel', N'U') IS NULL
    THROW 53130, 'Missing characters.CharacterLevel; run CharacterLevel.sql first.', 1;
IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
    THROW 53131, 'Missing dbo.ClassLevel; run ClassLevel.sql first.', 1;
GO

DECLARE @CharacterDate DATE;
DECLARE @ClassLevelDate DATE;
DECLARE @Notes NVARCHAR(MAX) = CONVERT(NVARCHAR(MAX), N'## Pell — Fighter Level 1

- **House rule:** maximum first Fighter Hit Die (1d8) = 8 HP; Constitution 9 contributes 0.
- **Final scores:** STR 9, INT 10, WIS 12, CON 9, DEX 14, CHA 12. The one-time Charisma reroll was 5+3+4=12, improving the former 8. No Prime Requisite exchange was made.
- **Prime Requisite bonus:** 0% at Strength 9.
- **Saving throws:** copy the five Fighter level-1 base targets from the MentzerBECMI ClassLevel table. Wisdom 12 gives no bonus against magic.
- **Dexterity 14:** +1 on missile attacks and an Armor Class improvement of 1 under Basic D&D; these do not change fixed saving throw values.
- **Historic HP:** before the retroactive HP rule, the Expedition 12 sheet recorded Pell as 4/4. The new 8 maximum belongs here; his expedition starting HP record remains 4.
- **Narrative:** Pell remains a retainer.');

SELECT @CharacterDate = [RecordDate]
FROM [characters].[Character]
WHERE [CharacterName] = N'Pell' AND [Active] = 1
  AND [InitialClass] = N'Fighter'
  AND [Strength] = 9 AND [Intelligence] = 10 AND [Wisdom] = 12
  AND [Constitution] = 9 AND [Dexterity] = 14 AND [Charisma] = 12;
SELECT @ClassLevelDate = [RecordDate]
FROM [dbo].[ClassLevel]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [Class] = N'Fighter' AND [Level] = 1 AND [Active] = 1;
IF @CharacterDate IS NULL
    THROW 53132, 'Missing active Pell Fighter identity with the locked scores.', 1;
IF @ClassLevelDate IS NULL
    THROW 53133, 'Missing MentzerBECMI Fighter level 1; run the reference seed.', 1;

IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterLevel]
    WHERE [CharacterName] = N'Pell' AND [Level] = 1 AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterLevel]
        WHERE [CharacterName] = N'Pell' AND [Level] = 1 AND [Active] = 1
          AND ([Class] <> N'Fighter' OR [RulesetCode] <> N'MentzerBECMI'
               OR [MaxHP] <> 8 OR [PrimeRequisiteXPBonusPct] <> 0
               OR [ConstitutionHPBonusPerDie] <> 0 OR [WisdomMagicSaveBonus] <> 0)
    )
        THROW 53134, 'Existing active Pell level-1 stats differ; review, do not overwrite.', 1;
    PRINT N'Active Pell Fighter level 1 exists; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterLevel]
    WHERE [CharacterName] = N'Pell' AND [Level] = 1
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 53135, 'Pell level 1 has a version dated today; DATE PK disallows another.', 1;
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
        N'Pell', 1, 1, @CharacterDate, [RecordDate], [RulesetCode], [Class],
        0, 8, 8, N'Maximum first Fighter d8 (8), CON 9 modifier 0',
        0, 0, [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
        [SaveDragonBreath], [SaveRodsStavesSpells], 0, @Notes
    FROM [dbo].[ClassLevel]
    WHERE [RecordDate] = @ClassLevelDate AND [Active] = 1
      AND [RulesetCode] = N'MentzerBECMI'
      AND [Class] = N'Fighter' AND [Level] = 1;
    PRINT N'Inserted Pell Fighter level 1 snapshot (MaxHP 8).';
END;
GO

SELECT [RecordDate], [CharacterName], [Class], [Level], [MaxHP],
       [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
       [SaveDragonBreath], [SaveRodsStavesSpells], [PrimeRequisiteXPBonusPct],
       [WisdomMagicSaveBonus], [Active]
FROM [characters].[CharacterLevel]
WHERE [CharacterName] = N'Pell' AND [Level] = 1
ORDER BY [RecordDate] DESC;
GO
