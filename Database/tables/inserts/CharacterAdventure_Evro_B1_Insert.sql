/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAdventure_Evro_B1_Insert.sql
Repository Path : Database/tables/CharacterAdventure_Evro_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Associate Evro with B1 from Expedition 12 and select his
                  troglodyte-fight illustration as his B1 character-card image.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAdventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql + Character_Evro_Insert.sql
                  Adventure.sql + Adventure_B1_Insert.sql
                  CharacterAdventure.sql

DESIGN NOTES
- Evro first joined the party in Expedition 12, not Expedition 1.
- The image path is preserved verbatim as provided by the user, including
  the repeated D&D/ImageLibrary folders and 'BarelySurving' spelling.
- The chosen image shows his severe troglodyte injury and polearm; it is a
  narrative depiction, not proof of hidden game-state details.
- The Notes Markdown records why this image was chosen.
- Finds the presently active Character/Adventure versions for FK dates.
- Does not overwrite or duplicate any already-active Evro/B1 association.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Register Evro in B1 from Expedition 12, with his
                        chosen battle illustration as optional card image.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
    THROW 51410, 'Missing characters.CharacterAdventure. Execute its CREATE script first.', 1;

DECLARE @CharacterVersionDate DATE;
DECLARE @AdventureVersionDate DATE;

SELECT @CharacterVersionDate = [RecordDate]
FROM [characters].[Character]
WHERE [CharacterName] = N'Evro' AND [Active] = 1;

SELECT @AdventureVersionDate = [RecordDate]
FROM [dbo].[Adventure]
WHERE [AdventureCode] = N'B1' AND [Active] = 1;

IF @CharacterVersionDate IS NULL
    THROW 51411, 'No active Evro Character row; run Character_Evro_Insert.sql first.', 1;
IF @AdventureVersionDate IS NULL
    THROW 51412, 'No active B1 Adventure row; run Adventure_B1_Insert.sql first.', 1;

IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAdventure]
    WHERE [CharacterName] = N'Evro' AND [AdventureCode] = N'B1'
      AND [Active] = 1
)
BEGIN
    PRINT N'Evro already has an active B1 association; no changes applied.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAdventure]
    WHERE [CharacterName] = N'Evro' AND [AdventureCode] = N'B1'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
BEGIN
    THROW 51413,
        'Evro/B1 has an association row dated today. DATE key does not allow another version today.', 1;
END
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
        N'Evro', N'B1', 1,
        @CharacterVersionDate, @AdventureVersionDate,
        12, N'Retainer',
        N'C:\Users\glade\OneDrive\Documents\Admin\Games\D&D\ImageLibrary\D&D\ImageLibrary\character_evro_B1_BarelySurvingTroglodyteAttack.png',
        N'## B1 character-card illustration

The selected card image shows Evro fighting a troglodyte with his polearm near the upper crossroads during **Expedition 12, Turn 4**. Evro suffered **7 points of damage**, falling from 8 HP to 1 HP, but survived the fight. The player selected this image after correcting the original axe to a polearm and refining the hand position. The lasting wound to his fighting arm also informs his separate CharacterAppearance record.

This is the chosen illustrative image for Adventure B1. It is not a photograph or a new combat adjudication.'
    );
    PRINT N'Inserted Evro/B1 CharacterAdventure association.';
END;
GO

SELECT [RecordDate], [CharacterName], [AdventureCode], [InitialExpedition],
       [CharacterRole], [CardImagePath], [Notes], [Active]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Evro' AND [AdventureCode] = N'B1'
ORDER BY [RecordDate] DESC;
GO
