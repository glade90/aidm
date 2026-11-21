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
Version         : 0.1.0 (SOURCE CHECKED / INACTIVE)
Created         : 2026-11-21
Dependencies    : Database/tables/Monster.sql v0.3 (D1/D2 diameters, Z height)
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
            N'Ordinary close combat: a Troglodyte has THREE separate attacks in a round, two claws and one bite, each with its own Hit roll and, on hit, 1d4 damage. It can change colours and hide by rock walls, causing opponents to be surprised on a party-side surprise d6 of 1-4 when the camouflage is applicable; this is PRE-COMBAT ENCOUNTER responsibility, never a bonus ordinary Combat turn. Its oily stench affects HUMANS and DEMI-HUMANS who are exposed to it: unless the affected individual succeeds at a Saving Throw versus Poison, apply the owner-named, source-tagged RETCHING condition. A RETCHING affected character suffers a penalty of -2 to that character''s Hit rolls while fighting a TROGLODYTE in hand-to-hand combat. Do not apply -2 to damage, Armor Class, Poison saving throws, missile attacks, spells or attacks against unrelated targets. This state does NOT have the Centipede NAUSEATED effect (no ten-day duration, half movement or action prohibition). Source does not specify exact stench radius, repeat-save cadence or expiry; these are undecided, not silently invented. The Encounter/scene provides explicit exposure facts for prototype; generic saving-throw/state tools and validated Combat Agent proposals commit changes. Never apply RETCHING automatically solely because a Troglodyte appears in a roster. Record actual victim, exposure source, save result and modifier provenance.',
            5.00, 5.00, 6.00,
            N'Owner default 5ft-diameter circular humanoid footprint; estimated 6ft height. Mentzer provides no Troglodyte dimensions.',
            NULL, NULL,
            N'Encounter fixture TROG-T001: 5 Troglodytes, HP [15,12,9,13,11], party Alho/Evro/Sho/Ralt; party surprise d6=4 (surprised via 1-4 rule), monster side d6=3 (not surprised via normal 1-2). These facts belong to TEST/ENCOUNTER OneNote, not the species row. Original monster artwork is not yet created. RETCHING is a new distinct state label for stench. Preserve unresolved exposure/expiry rulings.'
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
