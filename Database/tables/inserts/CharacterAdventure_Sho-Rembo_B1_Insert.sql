/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAdventure_Sho-Rembo_B1_Insert.sql
Repository Path : Database/tables/CharacterAdventure_Sho-Rembo_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Connect Sho to B1: provisional Expedition 3 retainer, later PC.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAdventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Adventure.sql; Adventure_B1_Insert.sql; Character.sql; CharacterAdventure.sql

DESIGN NOTES
- InitialExpedition=3 is PROVISIONAL based on player's recollection.
- CharacterRole='PlayerCharacter' represents her current adventure status.
- Her original role was Brandon's retainer; conversion date unspecified.
- CardImagePath is NULL until the user supplies the file's final location.
- Relational keys refer to presently active Character and Adventure versions.

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

IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
    THROW 52300, 'Missing characters.CharacterAdventure.', 1;
GO
DECLARE @CharacterDate DATE;
DECLARE @AdventureDate DATE;
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## Sho-Rembo in B1

- **First expedition:** provisionally Expedition 3, initially serving as a retainer of Brandon. This is the player''s recollection and needs confirmation against older expedition records.
- **Later role:** Sho became a player character at an as-yet-unrecorded point. CharacterRole reflects her current status, not the original hiring arrangement.
- **Selected card artwork:** Sho at a pool in the Room of Pools, in round glasses, with copper-red hair and cyan streaks, tan cloak, cyan brooch, hand axe and red/cyan arrow fletching. Save its actual Windows path before filling CardImagePath; the original illustration must not be confused with current equipment inventory.
- **Current weapons:** hand axe and Shield +1; Sho passed her shortbow and arrows to Alho during Expedition 12.
');
SELECT @CharacterDate = [RecordDate] FROM [characters].[Character]
WHERE [CharacterName] = N'Sho-Rembo' AND [Active] = 1;
SELECT @AdventureDate = [RecordDate] FROM [dbo].[Adventure]
WHERE [AdventureCode] = N'B1' AND [Active] = 1;
IF @CharacterDate IS NULL
    THROW 52301, 'No active Sho identity; run Character_Sho-Rembo_Insert.sql.', 1;
IF @AdventureDate IS NULL
    THROW 52302, 'No active B1 Adventure; run Adventure_B1_Insert.sql.', 1;
IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAdventure]
    WHERE [CharacterName] = N'Sho-Rembo'
      AND [AdventureCode] = N'B1' AND [Active] = 1
)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterAdventure]
        WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
          AND [Active] = 1 AND [InitialExpedition] <> 3
    )
        THROW 52303, 'An active Sho/B1 association has a different InitialExpedition. Review; no overwrite.', 1;
    PRINT N'Active Sho/B1 association already exists; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAdventure]
    WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 52304, 'Sho/B1 CharacterAdventure has a version today; cannot insert another with the DATE PK.', 1;
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
        N'Sho-Rembo', N'B1', 1, @CharacterDate, @AdventureDate,
        3, N'PlayerCharacter', NULL, @Notes
    );
    PRINT N'Inserted Sho/B1 membership; card image path awaits local file path.';
END;
GO
SELECT [RecordDate], [CharacterName], [AdventureCode],
       [InitialExpedition], [CharacterRole], [CardImagePath], [Active]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Sho-Rembo' AND [AdventureCode] = N'B1';
GO
