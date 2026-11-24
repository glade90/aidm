/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterExpedition_Ralt_B1_12_Insert.sql
Repository Path : Database/tables/CharacterExpedition_Ralt_B1_12_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Ralt participation in B1 Expedition 12 without inventing unsettled XP or HP.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterExpedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : CharacterAdventure_Ralt_B1_Insert.sql; Expedition_B1_12_Insert.sql; CharacterExpedition.sql

DESIGN NOTES
- Ralt is a PlayerCharacter / caller, not a retainer.
- Historical opening state StartHP=1, StartXP=1103, as logged.
- New house-rule level-1 MaxHP=4 belongs in CharacterLevel, not StartHP.
- Party has returned, but final settlement is pending, so EndHP,
  all XP awarded and treasure share are NULL until audited.
- The K6 dispute with Wilberd is established; murder was prevented.

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


IF OBJECT_ID(N'characters.CharacterExpedition', N'U') IS NULL
    THROW 53240, 'Missing characters.CharacterExpedition.', 1;
IF OBJECT_ID(N'dbo.Expedition', N'U') IS NULL
    THROW 53241, 'Missing dbo.Expedition.', 1;
GO

DECLARE @AssociationDate DATE;
DECLARE @ExpeditionDate DATE;
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## B1 — Expedition 12: Ralt Gaither

Ralt served as a player character and the company''s caller, quartermaster and treasurer. His recorded start was **1/1 HP** and **1,103 banked XP**, before the maximum-first-hit-die rule retroactively changed his level-1 maximum to **4 HP**. The old opening snapshot is preserved here.

- **Magic:** known prepared spell Magic Missile. Do not assume its final expended state without the complete turn audit.
- **Weapons:** four daggers, including his distinctive ornate carved-handled dagger, used or threatened in close confrontations; other daggers are ordinary.
- **Wilberd''s intervention:** after a promise to free Kobold 6, Ralt tried to kill the prisoner. Wilberd prevented the act and personally freed K6 in the Room of Pools. The attempt did not become a murder.
- **Items and knowledge:** Ralt carried writings and books recovered during earlier exploration, a ring acquired in the laboratory, and other small investigatory gear. Avoid presuming unidentified objects'' magical qualities.
- **Mission role:** Ralt issues much of the outward direction, but Wilberd remains the organizer of the company; their opposing motives continue to develop.
- **Room 12 card portrait:** illustrative scene of Ralt consulting a book in Quasqueton''s ornate library, not a record of new treasure or spell acquisition.
- **After departure:** party returned to town with treasure and wine barrels; Expedition 12 is awaiting ') 
    + N'formal XP, HP and treasure settlement.

**Pending:** EndHP, personal monster XP, treasure XP, other XP, Prime Requisite bonus XP, EndXP and treasure share have not been reconciled; keep NULL, not zero.';

SELECT @AssociationDate = [RecordDate]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
  AND [Active] = 1 AND [CharacterRole] = N'PlayerCharacter';
SELECT @ExpeditionDate = [RecordDate]
FROM [dbo].[Expedition]
WHERE [AdventureCode] = N'B1' AND [ExpeditionNumber] = 12 AND [Active] = 1;
IF @AssociationDate IS NULL
    THROW 53242, 'Missing active Ralt/B1 PlayerCharacter membership.', 1;
IF @ExpeditionDate IS NULL
    THROW 53243, 'Missing active B1 Expedition 12.', 1;

IF EXISTS (SELECT 1 FROM [characters].[CharacterExpedition]
           WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
             AND [ExpeditionNumber] = 12 AND [Active] = 1)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterExpedition]
        WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
          AND [ExpeditionNumber] = 12 AND [Active] = 1
          AND ([ParticipationRole] <> N'PlayerCharacter'
               OR ([StartHP] IS NOT NULL AND [StartHP] <> 1)
               OR ([StartXP] IS NOT NULL AND [StartXP] <> 1103))
    )
        THROW 53244, 'Active Ralt Expedition 12 conflicts with starting HP/XP; review.', 1;
    PRINT N'Ralt Expedition 12 record already exists; preserved.';
END
ELSE IF EXISTS (SELECT 1 FROM [characters].[CharacterExpedition]
                WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
                  AND [ExpeditionNumber] = 12
                  AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME()))
    THROW 53245, 'Ralt Expedition 12 has a DATE-key row already today.', 1;
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
        N'Ralt', N'B1', 12, 1,
        @AssociationDate, @ExpeditionDate,
        N'PlayerCharacter', N'Returned', 1, NULL, 1103,
        NULL, NULL, NULL, NULL, NULL, NULL, @Notes
    );
    PRINT N'Inserted Ralt B1 Expedition 12 (awards unsettled).';
END;
GO

SELECT [RecordDate], [CharacterName], [AdventureCode], [ExpeditionNumber],
       [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [MonsterXP], [TreasureXP], [OtherXP],
       [PrimeRequisiteBonusXP], [EndXP], [TreasureShareCopper], [Active]
FROM [characters].[CharacterExpedition]
WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12
ORDER BY [RecordDate] DESC;
GO
