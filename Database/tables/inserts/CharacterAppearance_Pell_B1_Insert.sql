/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAppearance_Pell_B1_Insert.sql
Repository Path : Database/tables/CharacterAppearance_Pell_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Establish Pell's B1 visual identity from approved party artwork and card scene.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Table           : characters.CharacterAppearance
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Character_Pell_Insert.sql; CharacterAppearance.sql (v1.1.0)

DESIGN NOTES
- Canonical visual references: the supplied purple-cavern crossbow image,
  barrel-hauling image, and the selected fleeing-giant-rat card art.
- Hair: chestnut/brown, long, windblown/wavy; dark facial stubble.
- Eyes, exact height, scars not established; unknown values remain NULL.
- A deep green travelling cloak and light crossbow recur in art but are
  outfit/equipment choices rather than permanent bodily features.
- No image path is stored here (that goes on CharacterAdventure).
- Record is per ADVENTURE B1, never per expedition.

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

IF OBJECT_ID(N'characters.CharacterAppearance', N'U') IS NULL
    THROW 53110, 'Missing characters.CharacterAppearance. Run CharacterAppearance.sql first.', 1;
IF COL_LENGTH(N'characters.CharacterAppearance', N'HeightDescription') IS NULL
    OR COL_LENGTH(N'characters.CharacterAppearance', N'AppearanceNotes') IS NULL
    OR COL_LENGTH(N'characters.CharacterAppearance', N'ImagePath') IS NOT NULL
    THROW 53111, 'Incompatible CharacterAppearance schema; no insert made.', 1;
IF NOT EXISTS
(
    SELECT 1 FROM [characters].[Character]
    WHERE [CharacterName] = N'Pell' AND [Active] = 1
)
    THROW 53112, 'Insert the Pell Character row before Appearance.', 1;
GO

DECLARE @Notes NVARCHAR(MAX) = CONVERT(NVARCHAR(MAX), N'## Pell — Appearance continuity for B1

- **Image references:** supplied party images show Pell aiming his crossbow in purple caverns and bracing behind a large wine barrel; the approved character-card scene depicts him shooting at the fleeing giant rat in the torchlit Quasqueton corridor.
- **Hair:** medium-to-long, slightly wavy/tousled chestnut-brown hair, sometimes tied loosely at the back.
- **Face:** adult human male, dark/light beard stubble, sharply focused eyes, determined expression.
- **Visual palette:** often a weathered deep-green cloak, cream linen sleeves, brown leather straps, bracers and travelling equipment; these are artistic choices, not permanently fixed clothes.
- **Weapons/equipment:** a light crossbow in the card art, and sword/shield in front-line fighting. Weapon choice is not a physiological descriptor.
- **Eye color and scars:** neither fixed by player; do not invent either.
- **Scene:** Expedition 12 giant-rat encounter while moving wine barrels; Pell shoots a fleeing rat. No lasting injury has been established for Pell.');

IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAppearance]
    WHERE [CharacterName] = N'Pell' AND [Adventure] = N'B1' AND [Active] = 1
)
    PRINT N'Active Pell/B1 appearance already exists; preserved.';
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAppearance]
    WHERE [CharacterName] = N'Pell' AND [Adventure] = N'B1'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 53113, 'Pell/B1 already has an appearance version dated today.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[CharacterAppearance]
    (
        [CharacterName], [Adventure], [Active], [HeightDescription],
        [BuildDescription], [HairColor], [HairDescription], [FacialHair],
        [EyeColor], [FaceDescription], [Scars], [OverallImpression],
        [AppearanceNotes]
    )
    VALUES
    (
        N'Pell', N'B1', 1,
        N'Adult human of ordinary stature; exact height not established.',
        N'Lean and wiry; agile rather than broad or heavily muscular.',
        N'Chestnut brown',
        N'Long, loose and slightly wavy/tousled, sometimes partly pulled back.',
        N'Short, scruffy dark-brown beard and moustache / stubble.',
        NULL,
        N'Angular adult face, defined jaw and alert expression; concentrated gaze when aiming.',
        NULL,
        N'Alert, practical, and determined supporting fighter; recognizable for his long brown hair and focused look.',
        @Notes
    );
    PRINT N'Inserted Pell B1 physical appearance.';
END;
GO

SELECT [RecordDate], [CharacterName], [Adventure], [Active],
       [HairColor], [HairDescription], [FacialHair], [EyeColor], [Scars]
FROM [characters].[CharacterAppearance]
WHERE [CharacterName] = N'Pell' AND [Adventure] = N'B1'
ORDER BY [RecordDate] DESC;
GO
