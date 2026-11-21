/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterExpedition_Evro_B1_12_Insert.sql
Repository Path : Database/tables/CharacterExpedition_Evro_B1_12_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Seed Evro's personal participation and outcome for B1
                  Expedition 12, without prematurely settling his XP.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema / Table  : characters.CharacterExpedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/CharacterAdventure_Evro_B1_Insert.sql
                  Database/tables/Expedition_B1_12_Insert.sql
                  Database/tables/CharacterExpedition.sql

DESIGN NOTES
- Evro was a Level 1 Fighter retainer in his first B1 outing, Expedition 12.
- Expedition 12 settlement is pending: EndXP, all earned-XP categories and
  TreasureShareCopper must remain NULL, not invented as zero.
- StartXP=0 is established at hire; StartHP=8, EndHP=7 were recorded.
- His initial 10 gp advance is an already-paid recruitment arrangement, NOT
  a new treasure/XP award credited here.
- His permanent scar and enduring features belong in CharacterAppearance;
  his chosen illustration path belongs in CharacterAdventure, not here.
- The 2026-10-18 attribute rebuild changes Evro's stats prospectively for
  Expedition 13; it does not change the original Expedition 12 history.
- Seed inserts only if no existing record for this participation exists.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Seed Evro Expedition 12 participation; HP 8 to 7,
                        monster/treasure XP pending.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'characters.CharacterExpedition', N'U') IS NULL
    THROW 51610, 'Missing characters.CharacterExpedition. Execute CharacterExpedition.sql first.', 1;
GO

DECLARE @ExpeditionRecordDate DATE;
DECLARE @CharacterAdventureRecordDate DATE;

SELECT @ExpeditionRecordDate = [RecordDate]
FROM [dbo].[Expedition]
WHERE [AdventureCode] = N'B1' AND [ExpeditionNumber] = 12 AND [Active] = 1;

SELECT @CharacterAdventureRecordDate = [RecordDate]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Evro' AND [AdventureCode] = N'B1'
  AND [Active] = 1;

IF @ExpeditionRecordDate IS NULL
    THROW 51611, 'No active B1 Expedition 12; run Expedition_B1_12_Insert.sql first.', 1;
IF @CharacterAdventureRecordDate IS NULL
    THROW 51612, 'No active Evro/B1 membership; run CharacterAdventure_Evro_B1_Insert.sql first.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM [characters].[CharacterExpedition]
    WHERE [CharacterName] = N'Evro' AND [AdventureCode] = N'B1'
      AND [ExpeditionNumber] = 12
)
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
        N'Evro', N'B1', 12, 1,
        @CharacterAdventureRecordDate, @ExpeditionRecordDate,
        N'Retainer', N'Returned', 8, 7, 0,
        N'## Evro — Expedition 12

Evro joined the company as a Fighter retainer on a ten-gold-piece advance, with a negotiated share of treasure. At the upper-level crossroads on dungeon Turn 4, a wandering troglodyte inflicted seven points of damage, taking Evro from **8/8 HP to 1/8 HP**. He survived and later drank the strange pink liquid in the Room of Pools, healing six points to **7/8 HP**.

During the outing he received the late Mohag''s plate armour, passed his magical shield to Sho-Rembo, and acquired an ordinary shield and sword. He helped the party recover and deliver three full wine barrels from Quasqueton. He returned to town alive at **7/8 HP**.

**XP and treasure-share settlement remain pending.** His new Strength 16 and Wisdom 16 were approved during the post-expedition character review and are not retroactively substituted for his original combat statistics.'
    );
    PRINT N'Inserted Evro B1 Expedition 12 participation; XP pending.';
END
ELSE
BEGIN
    PRINT N'Evro already has a B1 Expedition 12 participation record; seed skipped.';
END;
GO

SELECT [RecordDate], [CharacterName], [AdventureCode], [ExpeditionNumber],
       [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [MonsterXP], [TreasureXP], [PrimeRequisiteBonusXP],
       [EndXP], [TreasureShareCopper], [Active]
FROM [characters].[CharacterExpedition]
WHERE [CharacterName] = N'Evro' AND [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12
ORDER BY [RecordDate] DESC;
GO
