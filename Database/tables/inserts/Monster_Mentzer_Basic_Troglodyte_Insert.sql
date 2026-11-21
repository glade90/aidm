/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Troglodyte_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Troglodyte_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : Seed the reviewed Mentzer Basic Troglodyte species definition
                  including owner-approved RETCHING condition guidance.
Target Server   : PEQUOD (SQL Server)
Database        : DnD
Schema/Table    : Rules.Monster
Version         : 0.4.0 (SOURCE CHECKED / INACTIVE)
Created         : 2026-11-21
Dependencies    : Database/tables/Monster.sql v0.4 (includes SpecialEncounterFeatures)
Source          : Frank Mentzer, D&D Basic (1983), Dungeon Masters Rulebook
                  Troglodyte monster entry, printed p.38.
Design Review   : AIDM-DES-001.7; Combat Test TROG-T001.
===============================================================================
RULE AND STATE BOUNDARY
===============================================================================
- B1 selects species only; NEVER copy B1 monster counts, stats or HP.
- This species entry supplies baseline stats, narrative and special guidance,
  NOT the 5-Troglodyte TROG-T001 encounter roster, rolled HP or surprise dice.
- Troglodyte's stench state is OWNER NAMED RETCHING (separate from the Giant
  Centipede's NAUSEATED for ten days). Failed Save vs Poison causes -2 on Hit
  rolls in hand-to-hand combat WITH Troglodytes. Does not halve movement,
  forbid actions, affect missile attacks or apply an arbitrary timed expiry.
  The Mentzer entry does not define a stench exposure radius, saving-throw
  frequency or expiry. These remain unresolved Encounter/Rules decisions.
- Camouflage: may blend with stone walls and surprise on 1-4 on 1d6. This
  belongs to ENCOUNTER surprise resolution, NOT Combat round tests.
- R1/R2 are NOT used: D1/D2 are FULL horizontal ellipse diameters, in feet;
  humanoid default = D1=D2=5; Z=6 estimated, not official monster dimensions.
- SourceChecked / Active=0 until owner approves. No database execution here.
- Rerunnable: preserve any existing history for this ruleset/monster key.
===============================================================================
*/
USE [DnD];
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
    THROW 56560, 'Rules.Monster missing. Run Monster.sql v0.3 first.', 1;
IF COL_LENGTH(N'Rules.Monster', N'D1Feet') IS NULL
    OR COL_LENGTH(N'Rules.Monster', N'D2Feet') IS NULL
    OR COL_LENGTH(N'Rules.Monster', N'ZFeet') IS NULL
    THROW 56561, 'Rules.Monster dimensions not v0.3; review/run diameter migration first.', 1;
GO

SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[Monster] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RulesetCode] = N'MentzerBECMI'
          AND [MonsterCode] = N'TROGLODYTE'
    )
    BEGIN
        INSERT INTO [Rules].[Monster]
        (
            [RecordDate], [RulesetCode], [MonsterCode], [Active],
            [MonsterName], [ParentMonsterCode], [SourceStatus],
            [SourceReference], [HouseRuleOverlayRefs],
            [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern],
            [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet],
            [MovementSpecialText], [Alignment], [XPValue],
            [NumberAppearingText], [TreasureType],
            [GeneralDescription], [SpecialAttacksFeatures],
            [SpecialEncounterFeatures],
            [D1Feet], [D2Feet], [ZFeet], [SizeBasis],
            [IllustrationPath], [MapIconPath], [NotesMarkdown]
        )
        VALUES
        (
            CONVERT(DATE, SYSUTCDATETIME()),
            N'MentzerBECMI', N'TROGLODYTE', 0,
            N'Troglodyte', NULL, N'SourceChecked',
            N'1983 Mentzer D&D Basic Dungeon Masters Rulebook, Troglodyte, printed p.38.',
            N'AIDM naming overlay: RETCHING state (no change to original -2 melee-Hit rule). AIDM humanoid default ellipse diameters D1=D2=5 ft.',
            5, N'2*', N'2 claws and 1 bite', N'1d4 / 1d4 / 1d4',
            N'Fighter 2', 9, 120.00, 40.00,
            N'Chameleon-like camouflage against rock walls; surprise is Encounter, not Combat.',
            N'Chaotic', 30, N'1-8 normally; 5-40 in lair', N'A',
            N'An intelligent, upright reptilian humanoid with a short tail, long legs, and a spiny comb on its head and arms. It can use its hands much like a human. Its skin changes colour to blend with the stone walls of underground passages. Hostile to most other creatures, it exudes a dreadful oily stench. Let the Dungeon Master narrate its mottled scales, searching claws, low stance and overpowering odour without making additional numerical rules.',
            N'Ordinary close combat: a Troglodyte has THREE separate attacks in a round, two claws and one bite, each with its own Hit roll and, on hit, 1d4 damage. Its oily stench affects humans and demi-humans exposed according to validated Encounter scene facts: a failed Save vs Poison assigns the owner-approved RETCHING state to the actual victim; while fighting a Troglodyte hand-to-hand, the affected victim has -2 on Hit rolls. This is not a damage, AC, missile, spell or universal melee penalty, and NOT the Giant Centipede ten-day NAUSEATED illness. The monster entry does not specify exposure radius, repeat-save cadence or expiry, so the Combat Agent may not invent those. Exact exposure, actor, source and saving throw outcome are journalled using generic tools. Each of the three attacks is separately resolved.',
            N'Intelligent, upright reptilian humanoids with short tails, long legs and a spiny comb on head and arms. Colour-changing camouflage against rock walls can surprise opponents on 1-4 on their party-side d6 when appropriate; troglodytes themselves use the ordinary 1-2 surprise vulnerability. Scene and walls must support camouflage; use one surprise roll per side, never one per monster. They are generally hateful and aggressive toward most other creatures, but can be approached for parley, avoidance, threats, stand-off, retreat, or other attempts without forcing predetermined battle. Their foul oily stench can affect exposed humans and demi-humans; the Encounter/scene must supply actor-specific exposure evidence, not infer everyone exposed from mere roster presence. Source leaves radius, re-save interval and expiry unspecified: defer rather than invent. Encounter prepares surprise, scene, stench exposure and roster and passes them to Combat. Mentzer appears 1-8 normally or 5-40 in lair. Humanoid ellipse full diameters D1=D2=5 ft are AIDM modelling convention, not Mentzer mechanics.',
            5.00, 5.00, 6.00,
            N'Owner default 5ft-diameter circular humanoid footprint; estimated 6ft height. Mentzer provides no Troglodyte dimensions.',
            NULL, NULL,
            N'Original monster artwork not yet created. This is a reusable species definition only: encounter count, rolled HP, party, surprise die faces and test cases live in separate OneNote pages. RETCHING is a distinct stench-effect state label; exposure/resaving/expiry remain unresolved pending Encounter and Rules review.'
        );
        PRINT N'Inserted SourceChecked inactive Troglodyte species definition.';
    END
    ELSE
    BEGIN
        PRINT N'Existing TROGLODYTE version(s) preserved; no duplicate insert or overwrite.';
    END;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- Read-only review
SELECT [RecordDate], [RulesetCode], [MonsterCode], [MonsterName],
       [SourceStatus], [Active], [ArmorClass], [HitDiceText],
       [AttackPattern], [DamagePattern], [Morale],
       [D1Feet], [D2Feet], [ZFeet], [IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [MonsterCode] = N'TROGLODYTE'
ORDER BY [RecordDate] DESC;
GO
