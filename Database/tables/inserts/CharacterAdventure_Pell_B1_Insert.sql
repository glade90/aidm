/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAdventure_Pell_B1_Insert.sql
Repository Path : Database/tables/CharacterAdventure_Pell_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Register Pell as a B1 retainer with provisional first expedition and optional card art.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Table           : characters.CharacterAdventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Character_Pell_Insert.sql; Adventure.sql; Adventure_B1_Insert.sql; CharacterAdventure.sql

DESIGN NOTES
- Pell remains a RETAINER (never promoted to a player character).
- InitialExpedition=8 is explicitly PROVISIONAL: documentation puts Pell
  with the party by Expedition 8; original joining event is unverified.
  Edit @InitialExpedition BEFORE execution if older session records differ.
- CardImagePath=NULL until the player provides the actual saved Windows path.
- Do not substitute a sandbox image location for a Windows library path.
- Uses active parent Character and B1 Adventure record-version dates.

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

IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
    THROW 53120, 'Missing characters.CharacterAdventure.', 1;
IF OBJECT_ID(N'dbo.Adventure', N'U') IS NULL
    THROW 53121, 'Missing dbo.Adventure; execute Adventure.sql first.', 1;
GO

-- PROVISIONAL. Pell is documented with the party by Expedition 8,
-- but the first-joined expedition has not been verified.
DECLARE @InitialExpedition INT = 8;
DECLARE @CharacterDate DATE;
DECLARE @AdventureDate DATE;
DECLARE @CardImagePath NVARCHAR(1024) = NULL; -- Set to approved Windows path when saved.
DECLARE @Notes NVARCHAR(MAX) = CONVERT(NVARCHAR(MAX), N'## Pell in B1

- **Adventure:** B1 — In Search of the Unknown.
- **Status:** Retainer. Pell remains a hired/associated fighter, not a PlayerCharacter.
- **Joining:** documented in the party by Expedition 8; the precise initial expedition and whether he was originally encountered alone with Mohag still require confirmation from older play. `InitialExpedition = 8` is a provisional value, not certified history.
- **Primary role:** supporting crossbowman with +1 missile accuracy from Dexterity 14; can fight with sword and shield when ordered.
- **Card image:** chosen art depicts Pell firing a light crossbow at the fleeing giant rat in the torchlit dungeon during Expedition 12. The image path will be registered here only after the player saves the final file in the Windows library.
- **Equipment arrangement:** company light crossbow; plate and shield financed with 60 gp owed to Ralt under the previously recorded arrangement (repayment not confirmed).
- **Backstory:** deliberately not developed by the player.');

IF @InitialExpedition < 1
    THROW 53122, 'InitialExpedition must be at least 1.', 1;

SELECT @CharacterDate = [RecordDate]
FROM [characters].[Character]
WHERE [CharacterName] = N'Pell' AND [Active] = 1;
SELECT @AdventureDate = [RecordDate]
FROM [dbo].[Adventure]
WHERE [AdventureCode] = N'B1' AND [Active] = 1;
IF @CharacterDate IS NULL
    THROW 53123, 'Missing active Pell Character; execute the identity insert first.', 1;
IF @AdventureDate IS NULL
    THROW 53124, 'Missing active B1 Adventure; run Adventure_B1_Insert.sql first.', 1;

IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAdventure]
    WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1' AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterAdventure]
        WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1' AND [Active] = 1
          AND ([InitialExpedition] <> @InitialExpedition OR [CharacterRole] <> N'Retainer')
    )
        THROW 53125, 'Active Pell/B1 membership conflicts with provisional join or role; review before changes.', 1;
    PRINT N'Active Pell B1 retainer membership already exists; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAdventure]
    WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 53126, 'Pell B1 association has a version today; DATE PK prevents another.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterAdventure]
    (
        [CharacterName], [AdventureCode], [Active], [CharacterRecordDate],
        [AdventureRecordDate], [InitialExpedition], [CharacterRole],
        [CardImagePath], [Notes]
    )
    VALUES
    (
        N'Pell', N'B1', 1, @CharacterDate,
        @AdventureDate, @InitialExpedition, N'Retainer', @CardImagePath, @Notes
    );
    PRINT N'Inserted Pell B1 retainer membership; image path remains NULL.';
END;
GO

SELECT [RecordDate], [CharacterName], [AdventureCode], [InitialExpedition],
       [CharacterRole], [CardImagePath], [Active]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Pell' AND [AdventureCode] = N'B1'
ORDER BY [RecordDate] DESC;
GO
