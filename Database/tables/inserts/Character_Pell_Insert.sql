/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Character_Pell_Insert.sql
Repository Path : Database/tables/Character_Pell_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Pell's minimal identity and ability scores; preserve unknown biography.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Table           : characters.Character
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql (v1.1.1 or later)

DESIGN NOTES
- CharacterName='Pell'; no surname/lineage has been established.
- Fighter / Human / Neutral; charisma revised by one-time reroll 5+3+4=12.
- Final STR9 INT10 WIS12 CON9 DEX14 CHA12; no ability-point exchange.
- InitialAge=27 is a PLACEHOLDER required by the existing NOT NULL schema.
  Set @InitialAge to the player's desired value before execution.
- The player deliberately wants no invented character backstory; the required
  BackStory field records established facts and open questions only.
- BaseAC=9 is unarmored, independent of current plate/shield AC1.
- Idempotent: active row is preserved only if canonical scores/class match.

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

IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 53100, 'Missing characters.Character: run Character.sql first.', 1;
IF COL_LENGTH(N'characters.Character', N'BackStory') IS NULL
    OR COL_LENGTH(N'characters.Character', N'InitialAge') IS NULL
    OR COL_LENGTH(N'characters.Character', N'RecordDate') IS NULL
    THROW 53101, 'Existing Character schema is incompatible; stop and review.', 1;
GO

-- PROVISIONAL: Pell's age has not been fixed by the player.
DECLARE @InitialAge SMALLINT = 27;
DECLARE @BackStory NVARCHAR(MAX) = CONVERT(NVARCHAR(MAX), N'# Pell

Human Fighter, Neutral, and a **retainer** of the Quasqueton company. Pell is a dependable supporting fighter, proficient with the company light crossbow and willing to fight in the front rank with sword and shield when necessary. His greatest ability is Dexterity rather than raw Strength.

## Established Campaign History

Pell was encountered in Quasqueton and joined the company as a retainer. The player remembers meeting him alone in the dungeon, around the adventure in which Mohag the Wanderer was met; the exact original scene and first expedition remain to be verified. He is documented with the party by Expedition 8 and has participated in further expeditions.

In Expedition 12 he helped defend the barrel-moving party. He struck the fleeing surviving giant rat with a light-crossbow bolt for 3 damage during the rat encounter, after having hit a rat earlier for 1. He also hit the attacking troglodyte for 4 damage during the encounter in which Evro was badly wounded.

## Personal History

Pell''s family, birthplace, past before Quasqueton, and longer-term ambitions are **not yet established**. The player has elected to keep his personal background undescribed because Pell remains a retainer. Do not invent additional canon.

## Ability Rebuild

STR 9, INT 10, WIS 12, CON 9, DEX 14, CHA 12. His one-time 3d6 reroll of Charisma produced 5+3+4=12, replacing 8. No Prime Requisite exchange was made. The maximum-first-hit-die house rule gives 8 maximum hit points at level 1.');

IF @InitialAge NOT BETWEEN 1 AND 200
    THROW 53102, 'Choose an InitialAge from 1 to 200 before execution.', 1;

IF EXISTS
(
    SELECT 1 FROM [characters].[Character]
    WHERE [CharacterName] = N'Pell' AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[Character]
        WHERE [CharacterName] = N'Pell' AND [Active] = 1
          AND ([InitialClass] <> N'Fighter' OR [Race] <> N'Human'
               OR [InitialAlignment] <> N'Neutral' OR [InitialAge] <> @InitialAge
               OR [Strength] <> 9 OR [Intelligence] <> 10
               OR [Wisdom] <> 12 OR [Constitution] <> 9
               OR [Dexterity] <> 14 OR [Charisma] <> 12)
    )
        THROW 53103, 'Active Pell exists with different identity/scores/age. Do not overwrite.', 1;
    PRINT N'Pell already has an active matching Character row; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[Character]
    WHERE [CharacterName] = N'Pell'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 53104, 'Pell has a Character record dated today; DATE PK prevents another.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[Character]
    (
        [CharacterName], [Active], [Surname], [Moniker], [Race], [InitialClass],
        [Sex], [InitialAge], [InitialAlignment], [Strength], [Intelligence],
        [Wisdom], [Constitution], [Dexterity], [Charisma], [BaseAC], [BackStory]
    )
    VALUES
    (
        N'Pell', 1, NULL, N'Pell', N'Human', N'Fighter',
        N'Male', @InitialAge, N'Neutral', 9, 10, 12, 9, 14, 12, 9, @BackStory
    );
    PRINT N'Inserted Pell identity (age placeholder; confirm separately).';
END;
GO

SELECT [RecordDate], [CharacterName], [Active], [Moniker], [InitialClass],
       [InitialAge], [Strength], [Intelligence], [Wisdom],
       [Constitution], [Dexterity], [Charisma], LEN([BackStory]) AS BackStoryChars
FROM [characters].[Character]
WHERE [CharacterName] = N'Pell'
ORDER BY [RecordDate] DESC;
GO
