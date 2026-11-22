/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAppearance_Ralt_B1_Insert.sql
Repository Path : Database/tables/CharacterAppearance_Ralt_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert lasting Ralt appearance for B1 (no image path).
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAppearance
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Character_Ralt_Insert.sql; CharacterAppearance.sql (v1.1.0+)

DESIGN NOTES
- B1 appearance from the approved handsome black-haired scholarly portrait.
- Eye color, exact height and permanent scars remain NULL (not confirmed).
- Wardrobe cues live in appearance notes, NOT separate equipment columns.
- Adventure=B1; no Expedition number and no image file path.
- Never modifies an already-active version.

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


IF OBJECT_ID(N'characters.CharacterAppearance', N'U') IS NULL
    THROW 53210, 'Missing characters.CharacterAppearance.', 1;
IF COL_LENGTH(N'characters.CharacterAppearance', N'HeightDescription') IS NULL
   OR COL_LENGTH(N'characters.CharacterAppearance', N'AppearanceNotes') IS NULL
   OR COL_LENGTH(N'characters.CharacterAppearance', N'ImagePath') IS NOT NULL
    THROW 53211, 'Incompatible CharacterAppearance table; review schema.', 1;
IF NOT EXISTS (SELECT 1 FROM [characters].[Character]
               WHERE [CharacterName] = N'Ralt' AND [Active] = 1)
    THROW 53212, 'Active Ralt identity missing; run Character_Ralt_Insert.sql.', 1;
GO

DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## Ralt Gaither — canonical B1 appearance

- **Portrait references:** the user''s preferred candlelit library portrait and the approved Quasqueton Room 12 illustration establish his face and preferred silhouette.
- **Hair and face:** long, lustrous black hair; symmetrical refined features; clean-shaven; intense intelligent look. Exact height and eye color have not been established.
- **Style and bearing:** exquisitely fashionable black garments with ornate gold embroidery, fine pale shirt, and an aristocratic manner. These are consistent image cues, not permanent biological traits.
- **Emblem:** the visible pendant is arcane-looking jewelry; it is NOT identified as a patron''s holy symbol or a magical item.
- **Room 12 image:** ornate oak double doors, dusty polished red-granite floor with white granite R & Z monogram, three large oak tables, chairs and dusty upholstered divans. Library shelves and candlelit details follow the chosen illustration; do not treat all artwork as verified physical dungeon state.
- **No physical scars confirmed.** Do not invent them.
- **Purpose:** enduring description for B1; no expedition or image path belongs here.');

IF EXISTS (SELECT 1 FROM [characters].[CharacterAppearance]
           WHERE [CharacterName] = N'Ralt' AND [Adventure] = N'B1'
             AND [Active] = 1)
    PRINT N'Active Ralt B1 appearance already exists; preserved.';
ELSE IF EXISTS (SELECT 1 FROM [characters].[CharacterAppearance]
                WHERE [CharacterName] = N'Ralt' AND [Adventure] = N'B1'
                  AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME()))
    THROW 53213, 'Ralt B1 appearance already dated today; DATE key prevents a second.', 1;
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
        N'Ralt', N'B1', 1,
        N'Adult human; exact height not established.',
        N'Slender and refined rather than visibly muscular; upright, deliberate bearing.',
        N'Black',
        N'Long, thick, glossy, slightly wavy black hair, parted around the face and falling past the shoulders.',
        N'Clean-shaven.',
        NULL,
        N'Handsome, fine-boned and symmetrical features, defined cheekbones, dark brows and a cool, scrutinizing gaze.',
        NULL,
        N'Exquisitely groomed, aloof and aristocratic; composed in manner, quietly disdainful in expression.',
        @Notes
    );
    PRINT N'Inserted Ralt B1 appearance.';
END;
GO

SELECT [RecordDate], [CharacterName], [Adventure], [Active],
       [HeightDescription], [BuildDescription], [HairColor],
       [HairDescription], [FacialHair], [EyeColor], [Scars]
FROM [characters].[CharacterAppearance]
WHERE [CharacterName] = N'Ralt' AND [Adventure] = N'B1'
ORDER BY [RecordDate] DESC;
GO
