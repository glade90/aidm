/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAppearance_Sho-Rembo_B1_Insert.sql
Repository Path : Database/tables/CharacterAppearance_Sho-Rembo_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert canonical B1 visual features of Sho; no image path.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAppearance
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; Character_Sho-Rembo_Insert.sql; CharacterAppearance.sql

DESIGN NOTES
- No expedition or picture link here; only enduring visual identity.
- Eye colour and lasting scars have not been established and remain NULL.
- Tan cloak, brooch, goggles, hair streaks and hand axe documented in notes.
- Does not replace any existing approved active appearance.

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

IF OBJECT_ID(N'characters.CharacterAppearance', N'U') IS NULL
    THROW 52200, 'Missing characters.CharacterAppearance.', 1;
IF NOT EXISTS (SELECT 1 FROM [characters].[Character]
               WHERE [CharacterName] = N'Sho-Rembo' AND [Active] = 1)
    THROW 52201, 'Insert Sho-Rembo into Character first.', 1;
GO
DECLARE @Notes NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'## B1 appearance continuity

- **Visual references:** user-supplied party portraits and the approved new illustration of Sho poised to drink from a pool in Quasqueton''s Room of Pools.
- **Hair:** abundant copper-red/russet curls with conspicuous **cyan/turquoise streaks**. These are a conscious artistic choice, not a magical effect established in the campaign.
- **Face:** warm and freckled; bright, irrepressibly cheerful smile. Eye colour is not canonically settled and remains NULL.
- **Eye protection:** distinctive small round brass-framed medieval spectacles/goggles, worn beneath a riveted helmet. Treat the eyewear as part of her recognizable look in future images.
- **Reference outfit:** practical **tan** cloak, layered adventuring gear; **cyan-jewel brooch** on cloak. Her arrows, when pictured, use a red-and-cyan fletching pattern to match her hair.
- **Weapons:** her signature melee weapon is a **hand axe**, NEVER a sword. She knows how to use a shortbow, but the B1 Expedition 12 sheet records that her bow and arrows passed to Alho, so do not treat a depicted bow as a present inventory item.
- **Scars:** no enduring scar confirmed. The rat bite in Expedition 12 healed; do not add a permanent mark unless the player approves one.
- **Height, eye colour and exact age appearance:** not numerically or canonically established; avoid invented precision.
');
IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAppearance]
    WHERE [CharacterName] = N'Sho-Rembo' AND [Adventure] = N'B1'
      AND [Active] = 1
)
    PRINT N'Active Sho-Rembo/B1 appearance already exists; preserved.';
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[CharacterAppearance]
    WHERE [CharacterName] = N'Sho-Rembo' AND [Adventure] = N'B1'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 52202, 'Sho B1 appearance already versioned today; review before adding a second date version.', 1;
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
      N'Sho-Rembo', N'B1', 1,
      N'Short, of typical halfling stature; exact height undetermined.',
      N'Compact and sturdy, energetic and exceptionally enduring; not notably strong.',
      N'Copper-red / russet with cyan streaks',
      N'Thick, springy curls with bright cyan-turquoise streaks around her face and under her helmet.',
      NULL, NULL,
      N'Bright, lively, expressive, freckled face with a big mischievous smile; usually wears round brass-framed eye protection.',
      NULL,
      N'An irrepressibly friendly, hardy halfling with a mischievous grin, a practical adventurer''s bearing and striking red-and-cyan curls.',
      @Notes
    );
    PRINT N'Inserted Sho B1 canonical appearance.';
END;
GO
SELECT [RecordDate], [CharacterName], [Adventure], [HairColor],
       [HairDescription], [EyeColor], [Scars], [Active]
FROM [characters].[CharacterAppearance]
WHERE [CharacterName] = N'Sho-Rembo' AND [Adventure] = N'B1';
GO
