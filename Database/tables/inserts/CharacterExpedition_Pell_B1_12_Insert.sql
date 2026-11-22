/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterExpedition_Pell_B1_12_Insert.sql
Repository Path : Database/tables/CharacterExpedition_Pell_B1_12_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Record Pell's Expedition 12 participation and keep unsettled rewards NULL.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Table           : characters.CharacterExpedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : CharacterAdventure.sql; CharacterAdventure_Pell_B1_Insert.sql; Expedition.sql; Expedition_B1_12_Insert.sql; CharacterExpedition.sql

DESIGN NOTES
- Pell is a RETAINER, not a player character, in Expedition 12.
- StartHP=4, StartXP=268 are historical expedition-opening numbers.
- Retroactive maximum first Hit Die gives 8 max HP in CharacterLevel;
  historical StartHP is not silently rewritten.
- Party has returned; status Returned while expedition settlement pending.
- EndHP, monster/treasure/other XP, bonus XP, EndXP and cash share stay NULL
  until the final expedition reconciliation has been performed.
- Notes record established crossbow hits (fleeing giant rat and troglodyte)
  and the art scene; no invented rewards or debt payments.

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

IF OBJECT_ID(N'characters.CharacterExpedition', N'U') IS NULL
    THROW 53140, 'Missing characters.CharacterExpedition.', 1;
IF OBJECT_ID(N'dbo.Expedition', N'U') IS NULL
    THROW 53141, 'Missing dbo.Expedition; run Expedition.sql first.', 1;
GO

DECLARE @AssociationDate DATE;
DECLARE @ExpeditionDate DATE;
DECLARE @Notes NVARCHAR(MAX) = CONVERT(NVARCHAR(MAX), N'## Pell — B1 Expedition 12

Pell served as a retainer and flexible defender while the company transported three sealed wine barrels out of Quasqueton. He began the expedition with **4/4 HP** and **268 banked XP**, before the later retroactive maximum-first-Hit-Die rule changed his level-1 maximum to **8**.

- **Crossbow and the giant rats:** in the giant-rat battle (Turn 22), Pell hit a rat with a crossbow bolt for 1 damage in the first exchange, then struck the fleeing surviving rat for 3 damage in the subsequent volley. Wilberd finished that rat.
- **Troglodyte encounter:** Pell scored a crossbow hit for 4 damage against the troglodyte that nearly killed Evro. This encounter is part of his recorded B1 achievements.
- **Chosen trading-card scene:** Pell fires his light crossbow at the fleeing giant rat in a torchlit, barrel-lined corridor. His physical appearance is recorded in CharacterAppearance; the future local image path belongs in CharacterAdventure.
- **Equipment:** plate armour, ordinary shield, sword and company light crossbow; Dexterity 14 gives +1 missile attacks. Separate outstanding equipment loan to Ralt of 60 gp was recorded previously; no repayment is confirmed.

**Settlement pending:** Expedition 12 has returned to town, but monster XP, treasure XP, personal reward share and final HP reconciliation have not been finalized. EndHP, individual XP awards, EndXP, and treasure share remain NULL deliberately.');

SELECT @AssociationDate = [RecordDate]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
  AND [Active] = 1 AND [CharacterRole] = N'Retainer';
SELECT @ExpeditionDate = [RecordDate]
FROM [dbo].[Expedition]
WHERE [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12 AND [Active] = 1;
IF @AssociationDate IS NULL
    THROW 53142, 'Missing active Pell/B1 retainer membership.', 1;
IF @ExpeditionDate IS NULL
    THROW 53143, 'Missing active B1 Expedition 12.', 1;

IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterExpedition]
    WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
      AND [ExpeditionNumber] = 12 AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterExpedition]
        WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
          AND [ExpeditionNumber] = 12 AND [Active] = 1
          AND ([ParticipationRole] <> N'Retainer'
               OR ([StartHP] IS NOT NULL AND [StartHP] <> 4)
               OR ([StartXP] IS NOT NULL AND [StartXP] <> 268))
    )
        THROW 53144, 'Existing active Pell B1/12 has conflicting role, HP or XP; review before changes.', 1;
    PRINT N'Pell B1 Expedition 12 exists; no changes made.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterExpedition]
    WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
      AND [ExpeditionNumber] = 12
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 53145, 'Pell B1/12 already has a version today; DATE PK prevents another.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterExpedition]
    (
        [CharacterName], [AdventureCode], [ExpeditionNumber], [Active],
        [CharacterAdventureRecordDate], [ExpeditionRecordDate],
        [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
        [StartXP], [MonsterXP], [TreasureXP], [OtherXP],
        [PrimeRequisiteBonusXP], [EndXP], [TreasureShareCopper], [NotesMarkdown]
    )
    VALUES
    (
        N'Pell', N'B1', 12, 1, @AssociationDate, @ExpeditionDate,
        N'Retainer', N'Returned', 4, NULL, 268,
        NULL, NULL, NULL, NULL, NULL, NULL, @Notes
    );
    PRINT N'Inserted Pell Expedition 12 participation; rewards are pending.';
END;
GO

SELECT [RecordDate], [CharacterName], [AdventureCode], [ExpeditionNumber],
       [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [MonsterXP], [TreasureXP], [EndXP], [TreasureShareCopper], [Active]
FROM [characters].[CharacterExpedition]
WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12
ORDER BY [RecordDate] DESC;
GO
