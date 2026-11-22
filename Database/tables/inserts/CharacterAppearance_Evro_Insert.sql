/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterAppearance_Evro_Insert.sql
Repository Path : Database/tables/CharacterAppearance_Evro_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Evro's approved physical appearance for Adventure B1.
                  Descriptions reflect established character art; no images
                  or scene-specific picture metadata are stored in this table.
Target Server   : PEQUOD (default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterAppearance
Version         : 1.1.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql, CharacterAppearance.sql (v1.1.0)

DESIGN NOTES
- Name 'Evro' is the natural character identifier.
- 'B1' identifies In Search of the Unknown; no Expedition number is stored.
- Evro's battle damage is commemorated as an enduring upper-arm scar by
  the player's explicit decision; the exact left/right side is unconfirmed.
- Dark hair, beard, frame and rough face follow the accepted image references.
- Eye colour is left NULL: no canonical colour has been approved.
- Equipment, including plate armour and polearm, is deliberately excluded:
  it changes with the adventure and does not define his body or face.
- If an active Evro/B1 appearance already exists, do not overwrite it.
  A later change should be inserted as a new, dated version in a transaction.

CHANGE LOG
Date         Version   Change
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Initial illustration-related Evro insert proposal.
2026-10-18   1.1.0     Replace with canonical appearance descriptors and
                        provenance notes; remove image/path/expedition fields.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'characters.CharacterAppearance', N'U') IS NULL
    THROW 51210, 'Missing characters.CharacterAppearance. Run the revised creation script first.', 1;

IF COL_LENGTH(N'characters.CharacterAppearance', N'HeightDescription') IS NULL
   OR COL_LENGTH(N'characters.CharacterAppearance', N'ImagePath') IS NOT NULL
    THROW 51211, 'An old/incompatible CharacterAppearance design is installed. Do not run this insert.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM [characters].[Character]
    WHERE [CharacterName] = N'Evro' AND [Active] = 1
)
    THROW 51212, 'Evro has no active row in characters.Character; insert Character first.', 1;

IF EXISTS
(
    SELECT 1
    FROM [characters].[CharacterAppearance]
    WHERE [CharacterName] = N'Evro'
      AND [Adventure] = N'B1'
      AND [Active] = 1
)
BEGIN
    PRINT N'Evro already has an active appearance for B1. Existing record preserved.';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM [characters].[CharacterAppearance]
    WHERE [CharacterName] = N'Evro'
      AND [Adventure] = N'B1'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
BEGIN
    THROW 51213,
          'An Evro/B1 version already exists today. DATE-based PK permits only one version per day; do not overwrite.',
          1;
END
ELSE
BEGIN
    INSERT INTO [characters].[CharacterAppearance]
    (
        [CharacterName], [Adventure], [Active],
        [HeightDescription], [BuildDescription],
        [HairColor], [HairDescription], [FacialHair], [EyeColor],
        [FaceDescription], [Scars], [OverallImpression], [AppearanceNotes]
    )
    VALUES
    (
        N'Evro',
        N'B1',
        1,
        N'Tall and imposing; exact height not established.',
        N'Exceptionally muscular and broad-shouldered; massive arms, powerful chest, thick neck and large hands.',
        N'Dark brown',
        N'Long, thick, unkempt, slightly wavy; falls around his face and shoulders.',
        N'Heavy, full dark beard and moustache, kept rough and untrimmed.',
        NULL,
        N'Weather-beaten, heavily browed and rough-featured, with a square jaw and an intense, wary stare.',
        N'Deep, visible scar on his upper fighting arm following the Quasqueton troglodyte attack; exact arm side not yet fixed.',
        N'A formidable, intimidating presence; his expression is alert and shrewd, sometimes breaking into an unexpectedly mischievous grin.',
        N'## Appearance continuity notes

' +
        N'- **Art reference:** Two existing illustrations of Evro (the wine-barrel scene and the purple-cavern scene) establish his massive frame, unkempt dark hair, thick beard and rugged facial features.
' +
        N'- **Scar provenance:** During Expedition 12, Turn 4, a troglodyte wounded Evro for 7 HP, leaving him at 1/8. The player subsequently decided that the encounter leaves a prominent, lasting scar on his fighting arm.
' +
        N'- **Side of scar:** Not established; avoid asserting left or right until the player chooses.
' +
        N'- **Eye colour:** Not established; left NULL rather than invented.
' +
        N'- **Clothing and equipment:** His rough fur-trimmed outfit is an illustrative reference, not a permanent clothing requirement. Armour, shields and weapons change and belong in adventure/character equipment records.
' +
        N'- **Scope:** These are Evro''s canonical physical traits for Adventure B1, independent of any single image or expedition.'
    );

    PRINT N'Inserted Evro canonical appearance for B1.';
END;
GO

-- Read-only verification.
SELECT
    [RecordDate], [CharacterName], [Adventure], [Active],
    [HeightDescription], [BuildDescription], [HairColor],
    [HairDescription], [FacialHair], [EyeColor],
    [FaceDescription], [Scars], [OverallImpression], [AppearanceNotes]
FROM [characters].[CharacterAppearance]
WHERE [CharacterName] = N'Evro' AND [Adventure] = N'B1'
ORDER BY [RecordDate] DESC;
GO
