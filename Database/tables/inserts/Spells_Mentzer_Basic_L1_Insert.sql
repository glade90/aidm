/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Spells_Mentzer_Basic_L1_Insert.sql
Repository Path : Database/tables/Spells_Mentzer_Basic_L1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Seed every official first-level Cleric and Magic-User spell.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Spells
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Spells.sql (and Rules.sql)
Source          : 1983 Mentzer D&D Basic Players Manual, printed pp. 25-27, 35, 38-41; DM Rulebook p. 18.

DESIGN NOTES
- Exactly 8 first-level Cleric and 12 first-level Magic-User records.
- 17 unique spell names; 3 names have class-specific variants.
- Source descriptions are concise paraphrases of the original 1983 rules.
- Damage, range, duration, effect, saves and differences are documented.
- Magic Missile duration conflict (p.35 vs p.40) remains explicit.
- Rerunnable: never update, deactivate or duplicate existing approved rows.
- Abort the entire transaction if any active row disagrees with catalog facts.
- Spellbook membership and memorization are not seeded here.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial implementation and source-checked design.
===============================================================================
*/

USE [DnD];
GO
IF OBJECT_ID(N'Rules.Spells',N'U') IS NULL
    THROW 56010, 'Rules.Spells missing; run Spells.sql first.', 1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;
    DECLARE @SourceRows TABLE
    (
        [SpellClass] NVARCHAR(40) NOT NULL,
        [ListPosition] TINYINT NOT NULL,
        [SpellCode] NVARCHAR(60) NOT NULL,
        [SpellName] NVARCHAR(120) NOT NULL,
        [RangeText] NVARCHAR(140) NOT NULL,
        [RangeFeet] SMALLINT NULL,
        [DurationText] NVARCHAR(180) NOT NULL,
        [DurationTurns] SMALLINT NULL,
        [DurationRounds] SMALLINT NULL,
        [EffectText] NVARCHAR(600) NOT NULL,
        [DamageHealingText] NVARCHAR(180) NULL,
        [SavingThrowText] NVARCHAR(300) NULL,
        [ReversibleInExpert] BIT NOT NULL,
        [RulesMarkdown] NVARCHAR(MAX) NOT NULL,
        [SourceReference] NVARCHAR(320) NOT NULL
    );

    INSERT INTO @SourceRows
    ([SpellClass],[ListPosition],[SpellCode],[SpellName],[RangeText],
     [RangeFeet],[DurationText],[DurationTurns],[DurationRounds],
     [EffectText],[DamageHealingText],[SavingThrowText],
     [ReversibleInExpert],[RulesMarkdown],[SourceReference])
    VALUES
    (N'Cleric', 1, N'CURE_LIGHT_WOUNDS', N'Cure Light Wounds', N'Touch', NULL, N'Permanent', NULL, NULL, N'One living creature', N'Heals 1d6+1 HP, or removes paralysis', NULL, 1, N'## Cure Light Wounds (Cleric 1)

Heals 1d6+1 points, never above normal maximum HP; instead may remove paralysis without healing damage. May be cast on self. Reversal comes with Expert rules for level-4 clerics.', N'Mentzer Basic Players Manual, printed p. 26'),
    (N'Cleric', 2, N'DETECT_EVIL', N'Detect Evil', N'120''', 120, N'6 turns', 6, NULL, N'Everything within 120''', NULL, NULL, 1, N'## Detect Evil (Cleric 1)

Reveals glowing evilly enchanted objects and creatures intending harm; Chaotic alignment is not automatically evil. Traps and poison are not detected as evil. Reversal is an Expert cleric option.', N'Mentzer Basic Players Manual, printed p. 26'),
    (N'Cleric', 3, N'DETECT_MAGIC', N'Detect Magic', N'0 (caster)', 0, N'2 turns', 2, NULL, N'Magical things within 60''', NULL, NULL, 0, N'## Detect Magic (Cleric 1)

Magical objects, creatures and locations glow in the vision of the caster; spell does not identify their properties. Range 0 designates spell centered on caster; detection radius 60 feet.', N'Mentzer Basic Players Manual, printed p. 26'),
    (N'Cleric', 4, N'LIGHT', N'Light', N'120''', 120, N'12 turns', 12, NULL, N'Light in a 30''-diameter volume', NULL, N'Creature targeted in eyes may save to avoid blindness', 1, N'## Light (Cleric 1)

Creates torch-bright light in a 30-foot-diameter globe, optionally carried by an object. A creature targeted in the eyes saves or is blinded for the duration. Cleric version lasts 12 turns, unlike Magic-User version. Reversal later under Expert rules.', N'Mentzer Basic Players Manual, printed p. 26'),
    (N'Cleric', 5, N'PROTECTION_FROM_EVIL', N'Protection from Evil', N'0 (caster)', 0, N'12 turns', 12, NULL, N'Caster only', NULL, N'+1 on caster saving throws while active', 0, N'## Protection from Evil (Cleric 1)

Attacks against the caster suffer -1 to hit; caster gains +1 on all saving throws. Enchanted/summoned/controlled creatures cannot touch caster, unless caster attacks; the -1/+1 benefits continue. Does not stop Magic Missile. Duration differs from Magic-User version.', N'Mentzer Basic Players Manual, printed p. 27'),
    (N'Cleric', 6, N'PURIFY_FOOD_AND_WATER', N'Purify Food and Water', N'10''', 10, N'Permanent', NULL, NULL, N'One ration or six waterskins, or comparable ordinary food/water', NULL, NULL, 0, N'## Purify Food and Water (Cleric 1)

Makes spoiled or poisoned food and water safe: one ration, six waterskins, or enough normal food for twelve people. Mud settles into drinkable water. Does not affect living creatures.', N'Mentzer Basic Players Manual, printed p. 27'),
    (N'Cleric', 7, N'REMOVE_FEAR', N'Remove Fear', N'Touch', NULL, N'2 turns', 2, NULL, N'One living creature', NULL, N'For magical fear, new spell save with bonus of caster level (maximum +6); natural 1 fails', 1, N'## Remove Fear (Cleric 1)

Calms one creature and removes ordinary fear. Against magical fear, grants a fresh saving throw vs spells with cleric-level bonus capped at +6, even if original effect permitted no save. Reversal is an Expert cleric option.', N'Mentzer Basic Players Manual, printed p. 27'),
    (N'Cleric', 8, N'RESIST_COLD', N'Resist Cold', N'0 (caster)', 0, N'6 turns', 6, NULL, N'All creatures within 30'' of moving caster', N'Cold damage reduced by 1 per die (minimum 1/die)', N'+2 saves against cold attacks', 0, N'## Resist Cold (Cleric 1)

Protects everyone within 30 feet against freezing temperatures, gives +2 on saving throws against cold, and reduces cold damage by 1 point per die, minimum 1 point per die. Effect travels with caster.', N'Mentzer Basic Players Manual, printed p. 27'),
    (N'Magic-User', 1, N'CHARM_PERSON', N'Charm Person', N'120''', 120, N'Special: until broken or successful later save', NULL, NULL, N'One living ''person''', NULL, N'Saving throw vs Spells negates; later repeated saves vary by target INT', 0, N'## Charm Person (Magic-User 1)

Target regards caster as a trusted friend; limited to human-like creatures, not animals, magically created creatures, or beings larger than ogres. New saves occur over days/weeks/months based on Intelligence. Casting harmful magic or attacking victim breaks charm. Instructions require shared language.', N'Mentzer Basic Players Manual, printed p. 39'),
    (N'Magic-User', 2, N'DETECT_MAGIC', N'Detect Magic', N'0 (caster)', 0, N'2 turns', 2, NULL, N'Magical things within 60''', NULL, NULL, 0, N'## Detect Magic (Magic-User 1)

Visible magical objects, creatures and places within 60 feet glow to caster. Magic hidden behind solid objects remains physically unseen. Range 0 denotes caster-centered perception.', N'Mentzer Basic Players Manual, printed p. 39'),
    (N'Magic-User', 3, N'FLOATING_DISC', N'Floating Disc', N'0 (caster)', 0, N'6 turns', 6, NULL, N'Invisible waist-height disc following caster within 6''', NULL, NULL, 0, N'## Floating Disc (Magic-User 1)

Carries at most 5,000 cn (500 lb). Waist-high and follows within 6 feet; cannot serve as weapon or appear where an object/creature stands. Contents drop when spell ends.', N'Mentzer Basic Players Manual, printed p. 39'),
    (N'Magic-User', 4, N'HOLD_PORTAL', N'Hold Portal', N'10''', 10, N'2d6 turns', NULL, NULL, N'One door, gate or similar portal', NULL, NULL, 0, N'## Hold Portal (Magic-User 1)

Magically holds portal shut. Knock opens it. Creatures with at least 3 Hit Dice more than caster may force open in a round; portal relocks if allowed to close during duration.', N'Mentzer Basic Players Manual, printed p. 39'),
    (N'Magic-User', 5, N'LIGHT', N'Light', N'120''', 120, N'6 turns + 1 turn per caster level', NULL, NULL, N'Light in a 30''-diameter volume', NULL, N'Targeted creature may save to avoid blindness', 0, N'## Light (Magic-User 1)

Creates torch-bright light, optionally carried by an object; may blind target on failed save. This Magic-User variant has level-based duration; cleric version lasts 12 turns.', N'Mentzer Basic Players Manual, printed p. 40'),
    (N'Magic-User', 6, N'MAGIC_MISSILE', N'Magic Missile', N'150''', 150, N'1 round (detailed description); quick table says 1 turn', NULL, 1, N'One or more magical glowing arrows', N'1d6+1 damage per missile, automatic hit', N'No saving throw against missile', 0, N'## Magic Missile (Magic-User 1)

Automatically strikes a visible target when released. Each missile deals 1d6+1 damage; adds two missiles every five caster levels (three at level 6). Missile persists beside caster until fired or duration expires. SOURCE CONFLICT: detailed spell description printed p. 40 specifies 1 round; quick reference printed p. 35 specifies 1 turn. This catalog adopts the detailed description and retains the discrepancy.', N'Mentzer Basic Players Manual, printed p. 40, 35'),
    (N'Magic-User', 7, N'PROTECTION_FROM_EVIL', N'Protection from Evil', N'0 (caster)', 0, N'6 turns', 6, NULL, N'Caster only', NULL, N'+1 caster saving throws; enemies -1 hit rolls', 0, N'## Protection from Evil (Magic-User 1)

Invisible protection gives enemy attacks -1 to hit and caster +1 all saving throws. Enchanted creatures cannot touch unless caster attacks; Magic Missile unaffected. Magic-User duration is 6 turns; Cleric duration is 12.', N'Mentzer Basic Players Manual, printed p. 40'),
    (N'Magic-User', 8, N'READ_LANGUAGES', N'Read Languages', N'0 (caster)', 0, N'2 turns', 2, NULL, N'Caster only', NULL, NULL, 0, N'## Read Languages (Magic-User 1)

Allows caster to read, but not speak, unfamiliar languages, codes, maps, and symbols while spell lasts. Does not replace Read Magic for magical runes.', N'Mentzer Basic Players Manual, printed p. 40'),
    (N'Magic-User', 9, N'READ_MAGIC', N'Read Magic', N'0 (caster)', 0, N'1 turn', 1, NULL, N'Caster only', NULL, NULL, 0, N'## Read Magic (Magic-User 1)

Allows caster to read unfamiliar magical words and runes on scrolls and items. Once a particular writing is understood using Read Magic, the caster may read that same magical writing later without recasting. A magic-user can read own spellbook without casting. DM Rulebook recommends Read Magic as first starting spell.', N'Mentzer Basic Players Manual, printed p. 40'),
    (N'Magic-User', 10, N'SHIELD', N'Shield', N'0 (caster)', 0, N'2 turns', 2, NULL, N'Caster only', NULL, N'Can save vs Spells separately against Magic Missiles', 0, N'## Shield (Magic-User 1)

Creates barrier granting AC 2 against missile attacks and AC 4 against other attacks, replacing lower protection. Allows save vs Spells for each incoming Magic Missile to negate that missile.', N'Mentzer Basic Players Manual, printed p. 40-41'),
    (N'Magic-User', 11, N'SLEEP', N'Sleep', N'240''', 240, N'4d4 turns', NULL, NULL, N'2d8 Hit Dice of eligible living creatures in 40'' x 40'' area', NULL, N'No saving throw', 0, N'## Sleep (Magic-User 1)

Affects living creatures of 4+1 Hit Dice or less, excluding undead and very large beings such as dragons; total affected Hit Dice rolled as 2d8 by DM. Affected creatures sleep 4d4 turns. Physical disturbance wakes them; edged weapon can kill a sleeping victim with one blow.', N'Mentzer Basic Players Manual, printed p. 41'),
    (N'Magic-User', 12, N'VENTRILOQUISM', N'Ventriloquism', N'60''', 60, N'2 turns', 2, NULL, N'Voice apparently comes from one item or location', NULL, NULL, 0, N'## Ventriloquism (Magic-User 1)

Makes caster voice appear to originate from a chosen object, creature or place within range.', N'Mentzer Basic Players Manual, printed p. 41');

    IF (SELECT COUNT(*) FROM @SourceRows) <> 20
       OR (SELECT COUNT(*) FROM @SourceRows WHERE SpellClass=N'Cleric') <> 8
       OR (SELECT COUNT(*) FROM @SourceRows WHERE SpellClass=N'Magic-User') <> 12
        THROW 56011, 'Unexpected spell reference count; no data modified.', 1;

    -- Only catalog rows that match the full approved reference can be skipped.
    IF EXISTS
    (
        SELECT 1
        FROM @SourceRows s
        JOIN [Rules].[Spells] t
          ON t.[RulesetCode]=N'MentzerBECMI'
         AND t.[SpellClass]=s.[SpellClass]
         AND t.[SpellLevel]=1 AND t.[SpellCode]=s.[SpellCode]
         AND t.[Active]=1
        WHERE t.[SpellName]<>s.[SpellName]
           OR t.[ListPosition]<>s.[ListPosition]
           OR t.[RangeText]<>s.[RangeText]
           OR ISNULL(t.[RangeFeet],-1)<>ISNULL(s.[RangeFeet],-1)
           OR t.[DurationText]<>s.[DurationText]
           OR ISNULL(t.[DurationTurns],-1)<>ISNULL(s.[DurationTurns],-1)
           OR ISNULL(t.[DurationRounds],-1)<>ISNULL(s.[DurationRounds],-1)
           OR t.[EffectText]<>s.[EffectText]
           OR ISNULL(t.[DamageHealingText],N'')<>ISNULL(s.[DamageHealingText],N'')
           OR ISNULL(t.[SavingThrowText],N'')<>ISNULL(s.[SavingThrowText],N'')
           OR t.[ReversibleInExpert]<>s.[ReversibleInExpert]
           OR t.[RulesMarkdown]<>s.[RulesMarkdown]
           OR t.[SourceReference]<>s.[SourceReference]
    )
        THROW 56012, 'At least one active spell differs from this approved seed; review versions, no overwrite.', 1;

    -- DATE-based primary key prohibits reusing a retired row on this date.
    IF EXISTS
    (
        SELECT 1 FROM @SourceRows s
        JOIN [Rules].[Spells] t
          ON t.[RulesetCode]=N'MentzerBECMI' AND t.[SpellClass]=s.[SpellClass]
         AND t.[SpellLevel]=1 AND t.[SpellCode]=s.[SpellCode]
         AND t.[RecordDate]=CONVERT(DATE,SYSUTCDATETIME())
        WHERE t.[Active]=0
    )
        THROW 56013, 'A retired same-date spell version exists; DATE PK blocks fresh version today.', 1;

    INSERT INTO [Rules].[Spells]
    ([RulesetCode],[SpellClass],[SpellLevel],[SpellCode],[Active],
     [SpellName],[ListPosition],[RangeText],[RangeFeet],
     [DurationText],[DurationTurns],[DurationRounds],[EffectText],
     [DamageHealingText],[SavingThrowText],[ReversibleInExpert],
     [RulesMarkdown],[SourceReference])
    SELECT N'MentzerBECMI', s.[SpellClass], 1, s.[SpellCode], 1,
           s.[SpellName],s.[ListPosition],s.[RangeText],s.[RangeFeet],
           s.[DurationText],s.[DurationTurns],s.[DurationRounds],s.[EffectText],
           s.[DamageHealingText],s.[SavingThrowText],s.[ReversibleInExpert],
           s.[RulesMarkdown],s.[SourceReference]
    FROM @SourceRows s
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [Rules].[Spells] t
        WHERE t.[RulesetCode]=N'MentzerBECMI'
          AND t.[SpellClass]=s.[SpellClass] AND t.[SpellLevel]=1
          AND t.[SpellCode]=s.[SpellCode] AND t.[Active]=1
    );
    PRINT CONCAT(N'Inserted ',@@ROWCOUNT,N' first-level spell entries; existing matching entries preserved.');
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT [SpellClass],[ListPosition],[SpellName],[RangeText],[DurationText],
       [EffectText],[ReversibleInExpert]
FROM [Rules].[Spells]
WHERE [RulesetCode]=N'MentzerBECMI' AND [SpellLevel]=1 AND [Active]=1
ORDER BY [SpellClass],[ListPosition];
GO
