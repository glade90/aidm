/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAdventure_Ralt_B1_Insert.sql
Repository Path : Database/tables/CharacterAdventure_Ralt_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Link Ralt to B1 with initial expedition, PC role and optional card image.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAdventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character_Ralt_Insert.sql; Adventure_B1_Insert.sql; CharacterAdventure.sql

DESIGN NOTES
- InitialExpedition = 3 is PROVISIONAL; no confirmed first-joining log found.
- The earliest B1 Expedition 1 party reference lists Farned, Glendor,
  Feggener and Krago, NOT Ralt; a later exact joining number must be audited.
- CharacterRole='PlayerCharacter', unlike Pell's Retainer role.
- CardImagePath stays NULL until user's final Windows path is known.
- An image exists in this workspace, but no Windows path is assumed.
- Parent version dates are derived from active Character/Adventure rows.

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


IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
    THROW 53220, 'Missing characters.CharacterAdventure.', 1;
IF OBJECT_ID(N'dbo.Adventure', N'U') IS NULL
    THROW 53221, 'Missing dbo.Adventure.', 1;
GO

-- PROVISIONAL: exact starting expedition awaits historical confirmation.
-- Change this value BEFORE first execution if older logs show a different number.
DECLARE @InitialExpedition INT = 3;
DECLARE @CharacterDate DATE;
DECLARE @AdventureDate DATE;
DECLARE @CardImagePath NVARCHAR(1024) = NULL; -- Set only to an actual Windows image-library path.
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## Ralt Gaither in B1

- **Role:** PlayerCharacter, party caller, quartermaster and treasurer. Wilberd the Silent organized the company and retains the deeper purpose; Ralt gives many of its visible commands.
- **InitialExpedition:** provisional placeholder 3. The party led by Farned in Expedition 1 had no Ralt. Ralt was present by later expeditions, but the precise first expedition has not been verified. Review `@InitialExpedition` BEFORE running.
- **Art:** chosen B1 portrait depicts Ralt in Quasqueton''s Room 12 library, holding an old book in refined black-and-gold robes. The scene shows the module''s polished red granite floor and R & Z monogram. Final Windows image-library path is not yet provided and CardImagePath remains NULL.
- **Relationship:** Wilberd has guided Ralt for ten years, since Ralt was nineteen and Wilberd fifty-seven. Both use the relationship; future loyalty or betrayal remains unwritten.
- **Motivation:** acquire enough arcane knowledge and power to master even the cosmos; Ralt considers godhood an achievable end rather than a metaphor.
- **Notable moral conflict:** Ralt sought to kill prisoner K6 after freedom had been promised; Wilberd stopped him and freed the kobold. No murder of K6 occurred.
- **Style of conduct:** posh, disdainful, calculating, unscrupulous. He will deceive or kill when he believes it advances his endgame.');

IF @InitialExpedition < 2
    THROW 53222, 'Ralt was not among the Expedition 1 party; review the joining expedition.', 1;
SELECT @CharacterDate = [RecordDate]
FROM [characters].[Character]
WHERE [CharacterName] = N'Ralt' AND [Active] = 1;
SELECT @AdventureDate = [RecordDate]
FROM [dbo].[Adventure]
WHERE [AdventureCode] = N'B1' AND [Active] = 1;
IF @CharacterDate IS NULL
    THROW 53223, 'Missing active Ralt identity; run Character_Ralt_Insert.sql.', 1;
IF @AdventureDate IS NULL
    THROW 53224, 'Missing active B1; run Adventure_B1_Insert.sql.', 1;

IF EXISTS (SELECT 1 FROM [characters].[CharacterAdventure]
           WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
             AND [Active] = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM [characters].[CharacterAdventure]
               WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
                 AND [Active] = 1
                 AND ([InitialExpedition] <> @InitialExpedition
                      OR [CharacterRole] <> N'PlayerCharacter'))
        THROW 53225, 'Active Ralt B1 membership conflicts with role/join date; review history.', 1;
    PRINT N'Active Ralt/B1 membership already exists; preserved.';
END
ELSE IF EXISTS (SELECT 1 FROM [characters].[CharacterAdventure]
                WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
                  AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME()))
    THROW 53226, 'Ralt B1 membership has a DATE-key record today.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterAdventure]
    (
        [CharacterName], [AdventureCode], [Active],
        [CharacterRecordDate], [AdventureRecordDate],
        [InitialExpedition], [CharacterRole], [CardImagePath], [Notes]
    )
    VALUES
    (
        N'Ralt', N'B1', 1, @CharacterDate, @AdventureDate,
        @InitialExpedition, N'PlayerCharacter', @CardImagePath, @Notes
    );
    PRINT N'Inserted Ralt B1 membership; initial expedition is provisional.';
END;
GO

SELECT [RecordDate], [CharacterName], [AdventureCode], [Active],
       [InitialExpedition], [CharacterRole], [CardImagePath]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Ralt' AND [AdventureCode] = N'B1'
ORDER BY [RecordDate] DESC;
GO
