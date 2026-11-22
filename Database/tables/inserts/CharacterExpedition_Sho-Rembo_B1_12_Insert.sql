/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterExpedition_Sho-Rembo_B1_12_Insert.sql
Repository Path : Database/tables/CharacterExpedition_Sho-Rembo_B1_12_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Sho's B1 Expedition 12 participation, leave rewards pending.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterExpedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : CharacterAdventure.sql; Expedition.sql; Expedition_B1_12_Insert.sql; CharacterExpedition.sql

DESIGN NOTES
- Sho now participates as a PlayerCharacter; originally Brandon's retainer.
- StartHP=8 and StartXP=915 from Expedition 12 actual character sheet.
- Level 1 MaxHP=9 after later retroactive first-die rule; do not rewrite
  the historical starting HP. Final HP is left NULL pending audit.
- No invented XP awards or treasure share; all remain NULL.
- Status Returned because the party has returned to town for settlement.

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

IF OBJECT_ID(N'characters.CharacterExpedition', N'U') IS NULL
    THROW 52500, 'Missing characters.CharacterExpedition.', 1;
GO
DECLARE @AssociationDate DATE;
DECLARE @ExpeditionDate DATE;
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## B1 — Expedition 12: Sho-Rembo

Sho served as a player character and flexible front-line defender, often relieving Alho or Evro as needed. She started Expedition 12 with **8/8 HP** under the rule then in force and **915 banked XP**. The adopted maximum-first-hit-die rule subsequently recalculated her level-1 maximum to **9 HP**; do not rewrite the original expedition opening snapshot without a separate audit.

In the giant-rat fight on Turn 22, Sho struck a rat with her hand axe for 6 damage, killing it; its simultaneous bite cost her 3 HP. She passed the disease check. At Turn 33 in the Room of Pools, a drink of Pool A healed those 3 missing HP. During Expedition 12, Evro also gave her his Shield +1, and her shortbow and arrows passed to Alho.

The party returned from the dungeon, but the Expedition 12 treasure/XP ceremony and the verified final HP reconciliation have not been completed. EndHP, all XP awards and treasure share are deliberately NULL pending the audit.
');
SELECT @AssociationDate = [RecordDate]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
  AND [Active] = 1;
SELECT @ExpeditionDate = [RecordDate]
FROM [dbo].[Expedition]
WHERE [AdventureCode] = N'B1' AND [ExpeditionNumber] = 12
  AND [Active] = 1;
IF @AssociationDate IS NULL
    THROW 52501, 'Missing Sho/B1 CharacterAdventure association.', 1;
IF @ExpeditionDate IS NULL
    THROW 52502, 'Missing B1 Expedition 12 record.', 1;
IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterExpedition]
    WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
      AND [ExpeditionNumber] = 12 AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterExpedition]
        WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
          AND [ExpeditionNumber] = 12 AND [Active] = 1
          AND ([StartXP] IS NOT NULL AND [StartXP] <> 915
               OR [StartHP] IS NOT NULL AND [StartHP] <> 8)
    )
        THROW 52503, 'Existing Sho Expedition 12 has different start HP/XP; review before changing.', 1;
    PRINT N'Active Sho B1 Expedition 12 exists; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterExpedition]
    WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
      AND [ExpeditionNumber] = 12
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 52504, 'Sho/B1/12 has a version today; DATE PK prevents another.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterExpedition]
    (
       [CharacterName], [AdventureCode], [ExpeditionNumber], [Active],
       [CharacterAdventureRecordDate], [ExpeditionRecordDate],
       [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [NotesMarkdown]
    )
    VALUES
    (
       N'Sho-Rembo', N'B1', 12, 1,
       @AssociationDate, @ExpeditionDate,
       N'PlayerCharacter', N'Returned', 8, NULL, 915, @Notes
    );
    PRINT N'Inserted Sho B1 Expedition 12, settlement pending.';
END;
GO
SELECT [RecordDate], [CharacterName], [AdventureCode], [ExpeditionNumber],
       [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [MonsterXP], [TreasureXP], [EndXP], [Active]
FROM [characters].[CharacterExpedition]
WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12;
GO
