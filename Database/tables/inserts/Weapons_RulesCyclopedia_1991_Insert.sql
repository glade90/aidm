/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Weapons_RulesCyclopedia_1991_Insert.sql
Repository Path : Database/tables/Weapons_RulesCyclopedia_1991_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Seed 49 named weapon references from RC1991 with distinct campaign descriptors.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Version         : 1.0.0
Created         : 2026-10-20
Last Modified   : 2026-10-20
Dependencies    : Weapons.sql
Source          : D&D Master Players' Book (1985), weapon mastery;
                  D&D Rules Cyclopedia (1991), Chapter 5; B1 party choices.

DESIGN NOTES
- 47 original RC mastery-index weapons or techniques.
- Two clearly separate campaign descriptors: Flail and generic Polearm.
- RC polearm subtype names are included individually, but party assignments
  use generic POLEARM_GENERAL where no subtype was specified.
- Weapon stats and later mastery mechanics deliberately not imported.
- Existing active rows are checked; conflicts are rejected, not overwritten.
- Safe to rerun with the same catalog. No DROP, UPDATE, or MERGE.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-20   1.0.0     Initial narrative-only weapon catalog and proficiencies.
===============================================================================
*/

USE [DnD];
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'Rules.Weapons',N'U') IS NULL
    THROW 56410, 'Rules.Weapons missing. Run Weapons.sql first.', 1;
GO
DECLARE @Catalog TABLE
(
    [WeaponCode] NVARCHAR(80) NOT NULL PRIMARY KEY,
    [WeaponName] NVARCHAR(120) NOT NULL,
    [WeaponFamily] NVARCHAR(60) NOT NULL,
    [PrimaryUse] NVARCHAR(30) NOT NULL,
    [NarrativeDescription] NVARCHAR(600) NOT NULL,
    [SourceStatus] NVARCHAR(30) NOT NULL
);
INSERT INTO @Catalog
    ([WeaponCode],[WeaponName],[WeaponFamily],[PrimaryUse],[NarrativeDescription],[SourceStatus])
VALUES
    (N'BLACKJACK', N'Blackjack', N'Club', N'Melee', N'Small weighted striking implement.', N'OfficialRC1991'),
    (N'CESTUS', N'Cestus', N'Unarmed', N'Unarmed', N'Hand covering used for striking.', N'OfficialRC1991'),
    (N'HALBERD', N'Halberd', N'Polearm', N'Melee', N'Long hafted blade and axe combination.', N'OfficialRC1991'),
    (N'LANCE', N'Lance', N'Polearm', N'Melee', N'Long thrusting weapon associated with mounted fighting.', N'OfficialRC1991'),
    (N'PIKE', N'Pike', N'Polearm', N'Melee', N'Very long infantry thrusting weapon.', N'OfficialRC1991'),
    (N'BARDICHE', N'Bardiche', N'Polearm', N'Melee', N'Pole-mounted axe blade.', N'OfficialRC1991'),
    (N'BILL', N'Bill', N'Polearm', N'Melee', N'Hooked cutting pole weapon.', N'OfficialRC1991'),
    (N'GISARME', N'Gisarme', N'Polearm', N'Melee', N'Hooked pole weapon.', N'OfficialRC1991'),
    (N'GLAIVE', N'Glaive', N'Polearm', N'Melee', N'Single-edged blade mounted on a pole.', N'OfficialRC1991'),
    (N'LOCHABER_AXE', N'Lochaber Axe', N'Polearm', N'Melee', N'Long-hafted axe with a hook.', N'OfficialRC1991'),
    (N'PARTIZAN', N'Partizan', N'Polearm', N'Melee', N'Pole-mounted thrusting blade with side projections.', N'OfficialRC1991'),
    (N'RANSEUR', N'Ranseur', N'Polearm', N'Melee', N'Polearm with projecting side points.', N'OfficialRC1991'),
    (N'SPETUM', N'Spetum', N'Polearm', N'Melee', N'Thrusting spear with side blades.', N'OfficialRC1991'),
    (N'SPONTOON', N'Spontoon', N'Polearm', N'Melee', N'Short spear-like polearm.', N'OfficialRC1991'),
    (N'VOULGE', N'Voulge', N'Polearm', N'Melee', N'Broad cutting blade on a pole.', N'OfficialRC1991'),
    (N'POLEAXE', N'Poleaxe', N'Polearm', N'Melee', N'Heavy axe-headed pole weapon.', N'OfficialRC1991'),
    (N'SHIELD_HORNED', N'Shield, Horned', N'Shield Weapon', N'Melee', N'Shield adapted with an offensive horn.', N'OfficialRC1991'),
    (N'SHIELD_KNIFE', N'Shield, Knife', N'Shield Weapon', N'Melee', N'Shield fitted with a knife edge or blade.', N'OfficialRC1991'),
    (N'SHIELD_SWORD', N'Shield, Sword', N'Shield Weapon', N'Melee', N'Shield incorporating blades.', N'OfficialRC1991'),
    (N'SHIELD_TUSKED', N'Shield, Tusked', N'Shield Weapon', N'Melee', N'Shield fitted with offensive tusks.', N'OfficialRC1991'),
    (N'STAFF', N'Staff', N'Staff', N'Melee', N'Long wooden staff used to strike or defend.', N'OfficialRC1991'),
    (N'SWORD_TWO_HANDED', N'Sword, Two-Handed', N'Sword', N'Melee', N'Large sword commonly wielded in two hands.', N'OfficialRC1991'),
    (N'WHIP', N'Whip', N'Flexible', N'Melee', N'Flexible lash used at close range.', N'OfficialRC1991'),
    (N'AXE_BATTLE', N'Axe, Battle', N'Axe', N'Melee', N'Heavy fighting axe.', N'OfficialRC1991'),
    (N'CLUB', N'Club or Torch', N'Club', N'Melee', N'Club or torch used as a striking weapon; the source groups these together.', N'OfficialRC1991'),
    (N'HAMMER_WAR', N'Hammer, War', N'Hammer', N'Melee', N'Hammer designed for combat.', N'OfficialRC1991'),
    (N'MACE', N'Mace', N'Blunt', N'Melee', N'One-handed blunt striking weapon.', N'OfficialRC1991'),
    (N'SWORD_BASTARD', N'Sword, Bastard', N'Sword', N'Melee', N'Large sword between a normal and two-handed sword.', N'OfficialRC1991'),
    (N'SWORD_NORMAL', N'Sword, Normal', N'Sword', N'Melee', N'Standard sword, called Long Sword in our character descriptions.', N'OfficialRC1991'),
    (N'SWORD_SHORT', N'Sword, Short', N'Sword', N'Melee', N'Shorter sword suited to close fighting.', N'OfficialRC1991'),
    (N'BLOWGUN', N'Blowgun', N'Missile', N'Missile', N'Tube used to propel small darts.', N'OfficialRC1991'),
    (N'BOLA', N'Bola', N'Thrown', N'Thrown', N'Weighted cords thrown toward a target.', N'OfficialRC1991'),
    (N'BOW_LONG', N'Bow, Long', N'Bow', N'Missile', N'Long bow for shooting arrows.', N'OfficialRC1991'),
    (N'BOW_SHORT', N'Bow, Short', N'Bow', N'Missile', N'Short bow for shooting arrows.', N'OfficialRC1991'),
    (N'CROSSBOW_HEAVY', N'Crossbow, Heavy', N'Crossbow', N'Missile', N'Heavy bow mounted on a stock.', N'OfficialRC1991'),
    (N'CROSSBOW_LIGHT', N'Crossbow, Light', N'Crossbow', N'Missile', N'Light crossbow firing quarrels or bolts.', N'OfficialRC1991'),
    (N'SLING', N'Sling', N'Missile', N'Missile', N'Flexible projectile sling, usually with stones.', N'OfficialRC1991'),
    (N'AXE_HAND', N'Axe, Hand', N'Axe', N'MeleeAndThrown', N'Small one-handed axe that may also be thrown.', N'OfficialRC1991'),
    (N'DAGGER', N'Dagger', N'Dagger', N'MeleeAndThrown', N'Short knife suitable for melee or throwing.', N'OfficialRC1991'),
    (N'HAMMER_THROWING', N'Hammer, Throwing', N'Thrown', N'Thrown', N'Small balanced hammer used as a thrown weapon.', N'OfficialRC1991'),
    (N'JAVELIN', N'Javelin', N'Thrown', N'Thrown', N'Light spear intended for throwing.', N'OfficialRC1991'),
    (N'NET', N'Net', N'Thrown', N'Thrown', N'Net used to entangle an opponent.', N'OfficialRC1991'),
    (N'SPEAR', N'Spear', N'Polearm', N'MeleeAndThrown', N'Thrusting pole weapon that can also be thrown.', N'OfficialRC1991'),
    (N'TOSSED_OBJECT', N'Tossed Object', N'Improvised', N'Thrown', N'Improvised tossed object such as a stone or a thrown flask.', N'OfficialRC1991'),
    (N'TRIDENT', N'Trident', N'Polearm', N'MeleeAndThrown', N'Three-pronged spear.', N'OfficialRC1991'),
    (N'BOXING', N'Boxing', N'Unarmed', N'Unarmed', N'Unarmed striking technique.', N'OfficialRC1991'),
    (N'WRESTLING', N'Wrestling', N'Unarmed', N'Unarmed', N'Unarmed grappling technique.', N'OfficialRC1991'),
    (N'POLEARM_GENERAL', N'Polearm (Unspecified)', N'Polearm', N'Melee', N'Campaign grouping for an unspecified polearm; does not grant familiarity with every polearm type.', N'CampaignDescriptor'),
    (N'FLAIL_GENERAL', N'Flail', N'Flail', N'Melee', N'Campaign narrative category for flail training; not on the Rules Cyclopedia weapon-mastery index.', N'CampaignDescriptor');

IF (SELECT COUNT(*) FROM @Catalog) <> 49
    THROW 56411, 'Expected exactly 49 weapon catalog entries.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS
    (
        SELECT 1 FROM @Catalog x
        JOIN [Rules].[Weapons] w
          ON w.[RulesetCode]=N'MentzerBECMI'
         AND w.[WeaponCode]=x.[WeaponCode] AND w.[Active]=1
        WHERE w.[WeaponName] <> x.[WeaponName]
           OR w.[WeaponFamily] <> x.[WeaponFamily]
           OR w.[PrimaryUse] <> x.[PrimaryUse]
           OR w.[SourceStatus] <> x.[SourceStatus]
           OR w.[CatalogCode] <> N'RC1991_WEAPON_MASTERY_NARRATIVE'
           OR w.[NarrativeDescription] <> x.[NarrativeDescription]
           OR w.[NarrativeOnly] <> 1
    )
        THROW 56412, 'A weapon catalog entry already exists with conflicting details.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Catalog x JOIN [Rules].[Weapons] w
          ON w.[RecordDate]=CONVERT(DATE,SYSUTCDATETIME())
         AND w.[RulesetCode]=N'MentzerBECMI'
         AND w.[WeaponCode]=x.[WeaponCode] AND w.[Active]=0
        WHERE NOT EXISTS
        (SELECT 1 FROM [Rules].[Weapons] a
          WHERE a.[RulesetCode]=N'MentzerBECMI' AND a.[WeaponCode]=x.[WeaponCode] AND a.[Active]=1)
    )
        THROW 56413, 'An inactive weapon catalog version already uses today''s DATE key.', 1;

    INSERT INTO [Rules].[Weapons]
    ([RecordDate],[RulesetCode],[WeaponCode],[Active],[WeaponName],
     [WeaponFamily],[PrimaryUse],[CatalogCode],[SourceStatus],
     [NarrativeDescription],[NarrativeOnly],[SourceReference],[NotesMarkdown])
    SELECT CONVERT(DATE,SYSUTCDATETIME()), N'MentzerBECMI',
        x.[WeaponCode],1,x.[WeaponName],x.[WeaponFamily],x.[PrimaryUse],
        N'RC1991_WEAPON_MASTERY_NARRATIVE',x.[SourceStatus],
        x.[NarrativeDescription],1,
        CASE WHEN x.[SourceStatus]=N'OfficialRC1991'
            THEN N'D&D Rules Cyclopedia (TSR, 1991), Chapter 5, Weapon Mastery Tables'
            ELSE N'B1 campaign descriptor; compare D&D Rules Cyclopedia (1991), Chapter 5'
        END,
        CASE WHEN x.[WeaponCode]=N'POLEARM_GENERAL'
          THEN N'Player deliberately did not specify a particular polearm. No automatic familiarity with every subtype.'
        WHEN x.[WeaponCode]=N'FLAIL_GENERAL'
          THEN N'Player explicitly chose flail; not part of the referenced official mastery index. Narrative assignment only.'
        WHEN x.[WeaponCode]=N'SWORD_NORMAL'
          THEN N'Alias: Long Sword in player character profiles. Standard sword under later BECMI naming.'
        WHEN x.[WeaponCode] IN (N'BOXING',N'WRESTLING')
          THEN N'Official mastery index unarmed technique, not a physical item.'
        ELSE NULL END
    FROM @Catalog x
    WHERE NOT EXISTS
    (SELECT 1 FROM [Rules].[Weapons] w
      WHERE w.[RulesetCode]=N'MentzerBECMI' AND w.[WeaponCode]=x.[WeaponCode] AND w.[Active]=1);

    DECLARE @Added INT = @@ROWCOUNT;
    IF (SELECT COUNT(*) FROM @Catalog x JOIN [Rules].[Weapons] w
          ON w.[WeaponCode]=x.[WeaponCode]
         AND w.[RulesetCode]=N'MentzerBECMI' AND w.[Active]=1) <> 49
        THROW 56414, 'Weapon catalog row verification failed.', 1;
    COMMIT TRANSACTION;
    PRINT CONCAT(N'Inserted ',@Added,N' weapon catalog records; expected 49 active entries verified.');
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
