/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : ClassLevel_Mentzer_Basic_Insert.sql
Repository Path : Database/tables/ClassLevel_Mentzer_Basic_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert seven Mentzer Basic classes at levels 1-3 (21 rows).
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : dbo
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/ClassLevel.sql
Source          : 1983 Mentzer D&D Basic Rules, user-supplied PDF (reference seed).

DESIGN NOTES
- Published tables in the user-supplied 1983 Mentzer Basic Players Manual,
  printed pages 24-25, 28, 37, 43-47.
- MaxXP is next level minimum minus one, inclusive; at level 3 it is NULL
  because the Expert level-4 threshold is not supplied in this Basic volume.
- Spell slot columns give maximum prepared/cast spells by spell power level.
- Turning codes: N (no effect), T (automatic), or 2d6 target string.
- Existing matching active entries are not overwritten; divergent core XP,
  title, hit dice, spell slots or saves raise a deliberate error.
- All changes transactional; source comments retained in class notes.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Populate the 21 level reference entries.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
    THROW 51910, 'Missing dbo.ClassLevel; run ClassLevel.sql first.', 1;
GO

SET XACT_ABORT ON;
DECLARE @Seed TABLE
(
    [Class] NVARCHAR(40) NOT NULL,
    [Level] SMALLINT NOT NULL,
    [MinXP] INT NOT NULL,
    [MaxXP] INT NULL,
    [Title] NVARCHAR(100) NOT NULL,
    [PrimeRequisite] NVARCHAR(100) NOT NULL,
    [HitDieSides] TINYINT NOT NULL,
    [HitDiceAtLevel] SMALLINT NOT NULL,
    [SaveDeathPoison] TINYINT NOT NULL,
    [SaveMagicWands] TINYINT NOT NULL,
    [SaveParalysisStone] TINYINT NOT NULL,
    [SaveDragonBreath] TINYINT NOT NULL,
    [SaveRodsStavesSpells] TINYINT NOT NULL,
    [SpellSlotsLevel1] TINYINT NOT NULL,
    [SpellSlotsLevel2] TINYINT NOT NULL,
    [SpellSlotsLevel3] TINYINT NOT NULL,
    [SpellSlotsLevel4] TINYINT NOT NULL,
    [SpellSlotsLevel5] TINYINT NOT NULL,
    [SpellSlotsLevel6] TINYINT NOT NULL,
    [SpellSlotsLevel7] TINYINT NOT NULL,
    [SpellSlotsLevel8] TINYINT NOT NULL,
    [SpellSlotsLevel9] TINYINT NOT NULL,
    [TurnSkeleton] NVARCHAR(10) NULL,
    [TurnZombie] NVARCHAR(10) NULL,
    [TurnGhoul] NVARCHAR(10) NULL,
    [TurnWight] NVARCHAR(10) NULL,
    [ThiefOpenLocksPct] TINYINT NULL,
    [ThiefFindTrapsPct] TINYINT NULL,
    [ThiefRemoveTrapsPct] TINYINT NULL,
    [ThiefClimbWallsPct] TINYINT NULL,
    [ThiefMoveSilentlyPct] TINYINT NULL,
    [ThiefHideInShadowsPct] TINYINT NULL,
    [ThiefPickPocketsPct] TINYINT NULL,
    [ThiefHearNoiseD6Max] TINYINT NULL,
    [ClassFeaturesMarkdown] NVARCHAR(MAX) NULL,
    [AdvancementNotesMarkdown] NVARCHAR(MAX) NULL,
    [SourceReference] NVARCHAR(300) NOT NULL,
    PRIMARY KEY ([Class],[Level])
);

INSERT INTO @Seed
(
    [Class], [Level], [MinXP], [MaxXP], [Title], [PrimeRequisite], [HitDieSides], [HitDiceAtLevel], [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone], [SaveDragonBreath], [SaveRodsStavesSpells], [SpellSlotsLevel1], [SpellSlotsLevel2], [SpellSlotsLevel3], [SpellSlotsLevel4], [SpellSlotsLevel5], [SpellSlotsLevel6], [SpellSlotsLevel7], [SpellSlotsLevel8], [SpellSlotsLevel9], [TurnSkeleton], [TurnZombie], [TurnGhoul], [TurnWight], [ThiefOpenLocksPct], [ThiefFindTrapsPct], [ThiefRemoveTrapsPct], [ThiefClimbWallsPct], [ThiefMoveSilentlyPct], [ThiefHideInShadowsPct], [ThiefPickPocketsPct], [ThiefHearNoiseD6Max], [ClassFeaturesMarkdown], [AdvancementNotesMarkdown], [SourceReference]
)
VALUES
    ( N'Cleric', 1, 0, 1499, N'Acolyte', N'Wisdom', 6, 1, 11, 12, 14, 16, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'7', N'9', N'11', N'N', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Can turn undead from level 1. Wears any armour and shield; uses blunt weapons only. Cleric spells begin at level 2. Turn codes: N = cannot turn, T = automatic, numbers are targets on 2d6.', N'First level: 1d6 HD, cleric turning of skeletons 7, zombies 9, ghouls 11; no spells.', N'1983 Mentzer Basic Players Manual pp. 24-25' ),
    ( N'Cleric', 2, 1500, 2999, N'Adept', N'Wisdom', 6, 2, 11, 12, 14, 16, 15, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'T', N'7', N'9', N'11', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Can turn undead from level 1. Wears any armour and shield; uses blunt weapons only. Cleric spells begin at level 2. Turn codes: N = cannot turn, T = automatic, numbers are targets on 2d6.', N'Advancing to level 2: gain one additional d6 hit die; may prepare one first-level cleric spell; skeletons automatically turned, zombies 7, ghouls 9, wights 11.', N'1983 Mentzer Basic Players Manual pp. 24-25' ),
    ( N'Cleric', 3, 3000, NULL, N'Priest (or Priestess)', N'Wisdom', 6, 3, 11, 12, 14, 16, 15, 2, 0, 0, 0, 0, 0, 0, 0, 0, N'T', N'T', N'7', N'9', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Can turn undead from level 1. Wears any armour and shield; uses blunt weapons only. Cleric spells begin at level 2. Turn codes: N = cannot turn, T = automatic, numbers are targets on 2d6.', N'Advancing to level 3: gain one additional d6 hit die; two first-level cleric spells; skeletons and zombies automatically turned, ghouls 7, wights 9.', N'1983 Mentzer Basic Players Manual pp. 24-25' ),
    ( N'Fighter', 1, 0, 1999, N'Veteran', N'Strength', 8, 1, 12, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'May wear any armour, use a shield, and use any weapon. No spell casting or special class power at Basic levels 1-3.', N'First level: one d8 hit die, Fighter title Veteran, full weapon/armour access.', N'1983 Mentzer Basic Players Manual p. 28' ),
    ( N'Fighter', 2, 2000, 3999, N'Warrior', N'Strength', 8, 2, 12, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'May wear any armour, use a shield, and use any weapon. No spell casting or special class power at Basic levels 1-3.', N'Advancing to level 2: gain one d8 hit die and the title Warrior; no additional Basic-set class power.', N'1983 Mentzer Basic Players Manual p. 28' ),
    ( N'Fighter', 3, 4000, NULL, N'Swordmaster', N'Strength', 8, 3, 12, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'May wear any armour, use a shield, and use any weapon. No spell casting or special class power at Basic levels 1-3.', N'Advancing to level 3: gain one d8 hit die and the title Swordmaster; no additional Basic-set class power.', N'1983 Mentzer Basic Players Manual p. 28' ),
    ( N'Magic-User', 1, 0, 2499, N'Medium', N'Intelligence', 4, 1, 13, 14, 13, 16, 15, 1, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Uses dagger only; cannot wear armour or shield. Casts magic-user spells; a level-1 spellbook initially contains two first-level spells even though only one can be cast per preparation.', N'First level: one d4 hit die, one first-level spell casting; initial spellbook contains two first-level spells.', N'1983 Mentzer Basic Players Manual p. 37' ),
    ( N'Magic-User', 2, 2500, 4999, N'Seer', N'Intelligence', 4, 2, 13, 14, 13, 16, 15, 2, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Uses dagger only; cannot wear armour or shield. Casts magic-user spells; a level-1 spellbook initially contains two first-level spells even though only one can be cast per preparation.', N'Advancing to level 2: gain one d4 hit die; first-level spell capacity rises from one to two.', N'1983 Mentzer Basic Players Manual p. 37' ),
    ( N'Magic-User', 3, 5000, NULL, N'Conjurer', N'Intelligence', 4, 3, 13, 14, 13, 16, 15, 2, 1, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Uses dagger only; cannot wear armour or shield. Casts magic-user spells; a level-1 spellbook initially contains two first-level spells even though only one can be cast per preparation.', N'Advancing to level 3: gain one d4 hit die; still two first-level spells, plus one second-level spell casting.', N'1983 Mentzer Basic Players Manual p. 37' ),
    ( N'Thief', 1, 0, 1199, N'Apprentice', N'Dexterity', 4, 1, 13, 14, 13, 16, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 15, 10, 10, 87, 20, 10, 20, 2, N'May wear leather armour, no shield; can use missiles and one-handed weapons. Backstab when truly unnoticed: +4 on the hit roll and double damage. Has eight thief skills recorded in numeric columns.', N'First level: one d4 hit die, backstab and all eight listed thief abilities at level-1 rates.', N'1983 Mentzer Basic Players Manual pp. 43-44' ),
    ( N'Thief', 2, 1200, 2399, N'Footpad', N'Dexterity', 4, 2, 13, 14, 13, 16, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 20, 15, 15, 88, 25, 15, 25, 2, N'May wear leather armour, no shield; can use missiles and one-handed weapons. Backstab when truly unnoticed: +4 on the hit roll and double damage. Has eight thief skills recorded in numeric columns.', N'Advancing to level 2: gain one d4 hit die; skill chances improve as recorded in the thief numeric columns.', N'1983 Mentzer Basic Players Manual pp. 43-44' ),
    ( N'Thief', 3, 2400, NULL, N'Robber', N'Dexterity', 4, 3, 13, 14, 13, 16, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 25, 20, 20, 89, 30, 20, 30, 3, N'May wear leather armour, no shield; can use missiles and one-handed weapons. Backstab when truly unnoticed: +4 on the hit roll and double damage. Has eight thief skills recorded in numeric columns.', N'Advancing to level 3: gain one d4 hit die; all thief skill chances improve further, and Hear Noise succeeds on 1-3 on 1d6.', N'1983 Mentzer Basic Players Manual pp. 43-44' ),
    ( N'Dwarf', 1, 0, 2199, N'Dwarven Veteran', N'Strength', 8, 1, 8, 9, 10, 13, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Infravision 60 feet; detect certain stonework/traps/sloping corridors on 1-2 on 1d6 when specifically checking. Any armour/shield; small or normal-sized weapons, but no two-handed sword or longbow.', N'First level: one d8 hit die and baseline dwarven vision, detection, armour and weapons.', N'1983 Mentzer Basic Players Manual p. 45' ),
    ( N'Dwarf', 2, 2200, 4399, N'Dwarven Warrior', N'Strength', 8, 2, 8, 9, 10, 13, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Infravision 60 feet; detect certain stonework/traps/sloping corridors on 1-2 on 1d6 when specifically checking. Any armour/shield; small or normal-sized weapons, but no two-handed sword or longbow.', N'Advancing to level 2: gain one d8 hit die and the title Dwarven Warrior; Basic-set class features remain.', N'1983 Mentzer Basic Players Manual p. 45' ),
    ( N'Dwarf', 3, 4400, NULL, N'Dwarven Swordmaster', N'Strength', 8, 3, 8, 9, 10, 13, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Infravision 60 feet; detect certain stonework/traps/sloping corridors on 1-2 on 1d6 when specifically checking. Any armour/shield; small or normal-sized weapons, but no two-handed sword or longbow.', N'Advancing to level 3: gain one d8 hit die and the title Dwarven Swordmaster; Basic-set class features remain.', N'1983 Mentzer Basic Players Manual p. 45' ),
    ( N'Elf', 1, 0, 3999, N'Veteran-Medium', N'Strength and Intelligence', 6, 1, 12, 13, 13, 15, 15, 1, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Infravision 60 feet, detect hidden/secret doors on 1-2 on 1d6 when checking, immune to ghoul paralysis, uses any armour/shield/weapon, and casts magic-user spells.', N'First level: one d6 hit die and one first-level magic-user spell; elf detection, sight and paralysis immunity apply.', N'1983 Mentzer Basic Players Manual p. 46' ),
    ( N'Elf', 2, 4000, 7999, N'Warrior-Seer', N'Strength and Intelligence', 6, 2, 12, 13, 13, 15, 15, 2, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Infravision 60 feet, detect hidden/secret doors on 1-2 on 1d6 when checking, immune to ghoul paralysis, uses any armour/shield/weapon, and casts magic-user spells.', N'Advancing to level 2: gain one d6 hit die; first-level spell capacity rises to two.', N'1983 Mentzer Basic Players Manual p. 46' ),
    ( N'Elf', 3, 8000, NULL, N'Swordmaster-Conjurer', N'Strength and Intelligence', 6, 3, 12, 13, 13, 15, 15, 2, 1, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Infravision 60 feet, detect hidden/secret doors on 1-2 on 1d6 when checking, immune to ghoul paralysis, uses any armour/shield/weapon, and casts magic-user spells.', N'Advancing to level 3: gain one d6 hit die; retains two first-level spells and gains one second-level spell casting.', N'1983 Mentzer Basic Players Manual p. 46' ),
    ( N'Halfling', 1, 0, 1999, N'Halfling Veteran', N'Strength and Dexterity', 6, 1, 8, 9, 10, 13, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Can hide outdoors (detected only 10% of the time with cover) and in dungeon shadows on 1-2 on 1d6. +2 armour class bonus versus attacks by creatures larger than man-sized, +1 missile hit, and +1 optional individual initiative. Limited to smaller weapons; no longbow or pole arm.', N'First level: one d6 hit die, hiding and size-related combat bonuses.', N'1983 Mentzer Basic Players Manual p. 47' ),
    ( N'Halfling', 2, 2000, 3999, N'Halfling Warrior', N'Strength and Dexterity', 6, 2, 8, 9, 10, 13, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Can hide outdoors (detected only 10% of the time with cover) and in dungeon shadows on 1-2 on 1d6. +2 armour class bonus versus attacks by creatures larger than man-sized, +1 missile hit, and +1 optional individual initiative. Limited to smaller weapons; no longbow or pole arm.', N'Advancing to level 2: gain one d6 hit die and the title Halfling Warrior; Basic-set class features remain.', N'1983 Mentzer Basic Players Manual p. 47' ),
    ( N'Halfling', 3, 4000, NULL, N'Halfling Swordmaster', N'Strength and Dexterity', 6, 3, 8, 9, 10, 13, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'Can hide outdoors (detected only 10% of the time with cover) and in dungeon shadows on 1-2 on 1d6. +2 armour class bonus versus attacks by creatures larger than man-sized, +1 missile hit, and +1 optional individual initiative. Limited to smaller weapons; no longbow or pole arm.', N'Advancing to level 3: gain one d6 hit die and the title Halfling Swordmaster; Basic-set class features remain.', N'1983 Mentzer Basic Players Manual p. 47' );

IF (SELECT COUNT(*) FROM @Seed) <> 21
    THROW 51911, 'Expected exactly 21 Basic rules rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Detect conflicting published rule entries; do not change them silently.
    IF EXISTS
    (
        SELECT 1
        FROM @Seed AS s
        JOIN [dbo].[ClassLevel] AS c
          ON c.[RulesetCode] = N'MentzerBECMI'
         AND c.[Class] = s.[Class] AND c.[Level] = s.[Level]
         AND c.[Active] = 1
        WHERE c.[MinXP] <> s.[MinXP]
           OR ISNULL(c.[MaxXP], -1) <> ISNULL(s.[MaxXP], -1)
           OR c.[Title] <> s.[Title]
           OR c.[HitDieSides] <> s.[HitDieSides]
           OR c.[HitDiceAtLevel] <> s.[HitDiceAtLevel]
           OR c.[SaveDeathPoison] <> s.[SaveDeathPoison]
           OR c.[SaveMagicWands] <> s.[SaveMagicWands]
           OR c.[SaveParalysisStone] <> s.[SaveParalysisStone]
           OR c.[SaveDragonBreath] <> s.[SaveDragonBreath]
           OR c.[SaveRodsStavesSpells] <> s.[SaveRodsStavesSpells]
           OR c.[SpellSlotsLevel1] <> s.[SpellSlotsLevel1]
           OR c.[SpellSlotsLevel2] <> s.[SpellSlotsLevel2]
    )
       THROW 51912, 'An active ClassLevel conflicts with Basic source values. Review; no overwrite.', 1;

    INSERT INTO [dbo].[ClassLevel]
    (
        [RulesetCode], [Class], [Level], [MinXP], [MaxXP], [Title], [PrimeRequisite], [HitDieSides], [HitDiceAtLevel], [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone], [SaveDragonBreath], [SaveRodsStavesSpells], [SpellSlotsLevel1], [SpellSlotsLevel2], [SpellSlotsLevel3], [SpellSlotsLevel4], [SpellSlotsLevel5], [SpellSlotsLevel6], [SpellSlotsLevel7], [SpellSlotsLevel8], [SpellSlotsLevel9], [TurnSkeleton], [TurnZombie], [TurnGhoul], [TurnWight], [ThiefOpenLocksPct], [ThiefFindTrapsPct], [ThiefRemoveTrapsPct], [ThiefClimbWallsPct], [ThiefMoveSilentlyPct], [ThiefHideInShadowsPct], [ThiefPickPocketsPct], [ThiefHearNoiseD6Max], [ClassFeaturesMarkdown], [AdvancementNotesMarkdown], [SourceReference], [Active]
    )
    SELECT
        N'MentzerBECMI', s.[Class], s.[Level], s.[MinXP], s.[MaxXP], s.[Title], s.[PrimeRequisite], s.[HitDieSides], s.[HitDiceAtLevel], s.[SaveDeathPoison], s.[SaveMagicWands], s.[SaveParalysisStone], s.[SaveDragonBreath], s.[SaveRodsStavesSpells], s.[SpellSlotsLevel1], s.[SpellSlotsLevel2], s.[SpellSlotsLevel3], s.[SpellSlotsLevel4], s.[SpellSlotsLevel5], s.[SpellSlotsLevel6], s.[SpellSlotsLevel7], s.[SpellSlotsLevel8], s.[SpellSlotsLevel9], s.[TurnSkeleton], s.[TurnZombie], s.[TurnGhoul], s.[TurnWight], s.[ThiefOpenLocksPct], s.[ThiefFindTrapsPct], s.[ThiefRemoveTrapsPct], s.[ThiefClimbWallsPct], s.[ThiefMoveSilentlyPct], s.[ThiefHideInShadowsPct], s.[ThiefPickPocketsPct], s.[ThiefHearNoiseD6Max], s.[ClassFeaturesMarkdown], s.[AdvancementNotesMarkdown], s.[SourceReference], 1
    FROM @Seed AS s
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [dbo].[ClassLevel] AS c
        WHERE c.[RulesetCode] = N'MentzerBECMI'
          AND c.[Class] = s.[Class] AND c.[Level] = s.[Level]
          AND c.[Active] = 1
    );

    IF (SELECT COUNT(*) FROM [dbo].[ClassLevel]
        WHERE [RulesetCode] = N'MentzerBECMI'
          AND [Level] BETWEEN 1 AND 3 AND [Active] = 1) <> 21
       THROW 51913, 'Expected 21 active Basic ClassLevel records; check existing entries.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT [Class], [Level], [MinXP], [MaxXP], [Title],
       [SpellSlotsLevel1], [SpellSlotsLevel2],
       [TurnSkeleton], [TurnZombie], [TurnGhoul], [TurnWight]
FROM [dbo].[ClassLevel]
WHERE [RulesetCode] = N'MentzerBECMI' AND [Level] BETWEEN 1 AND 3 AND [Active] = 1
ORDER BY [Class], [Level];
GO
