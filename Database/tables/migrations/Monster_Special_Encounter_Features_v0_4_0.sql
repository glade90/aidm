/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Special_Encounter_Features_v0_4_0.sql
Repository Path : Database/tables/migrations/Monster_Special_Encounter_Features_v0_4_0.sql
Project         : Golden Braid / AIDM — PEQUOD DnD
Purpose         : Add SpecialEncounterFeatures; separate approved owner intent:
                  mechanical surprise/scene AND nontechnical social, parley,
                  stand-off, avoidance, tactics, ecology, lair, retreat and mood.
Target Server   : SQL Server 2016+, PEQUOD, DnD.Rules.Monster
Created         : 2026-11-21
Dependencies    : Existing Monster v0.3 (D1/D2/Z). From v0.1/v0.2 first run
                  Monster_Diameter_Footprint_v0_3_0.sql.
Notes           : Safe to rerun. Never overwrites Approved/Active or altered
                  combat prose. Old exact source-checked seed prose is converted
                  to combat-only; manually edited prose is left unchanged.
                  New records use Monster.sql and seed v0.4. No SQL server
                  invocation is made by the Git commit.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
    THROW 56571, 'Rules.Monster missing: run new Monster.sql and seed; no migration needed.', 1;
IF COL_LENGTH(N'Rules.Monster', N'D1Feet') IS NULL
    THROW 56572, 'Expected Monster v0.3 D1/D2 diameter fields: migrate earlier geometry first.', 1;
GO

SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;
    IF COL_LENGTH(N'Rules.Monster', N'SpecialEncounterFeatures') IS NULL
    BEGIN
        -- SQL Server will fill previous rows with empty prose, preserving data.
        ALTER TABLE [Rules].[Monster]
        ADD [SpecialEncounterFeatures] NVARCHAR(MAX) NOT NULL
            CONSTRAINT [DF_Monster_SpecialEncounterFeatures] DEFAULT (N'') WITH VALUES;
        PRINT N'Added SpecialEncounterFeatures to existing Rules.Monster.';
    END
    ELSE
        PRINT N'SpecialEncounterFeatures already exists. No column added.';
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- SQL Server compiles this batch AFTER the new column is committed.
BEGIN TRY
    BEGIN TRAN;
    DECLARE @Known TABLE
    (
        [MonsterCode] NVARCHAR(80) NOT NULL PRIMARY KEY,
        [LegacyCombat] NVARCHAR(MAX) NOT NULL,
        [CombatOnly] NVARCHAR(MAX) NOT NULL,
        [EncounterOnly] NVARCHAR(MAX) NOT NULL
    );
    INSERT INTO @Known
        ([MonsterCode], [LegacyCombat], [CombatOnly], [EncounterOnly])
    VALUES
        (N'ORC', N'Use the encounter roster to identify each Orc''s role and current conditions; do not create roles, equipment, starting HP or targets from this species row. A fighting Orc in daylight suffers -1 to its Hit roll; this is not a damage or Armor Class penalty. A specifically designated ordinary Orc group leader has 8 starting HP supplied by encounter setup and adds +1 to damage after a successful weapon hit. If that leader dies, the surviving group''s morale value becomes 6 instead of 8, but roll a morale check only when the generic Mentzer morale procedure next requires one; death alone does not create a bonus check. A tribal chieftain is a distinct, explicitly identified encounter role with 15 starting HP, attacks using the 4-HD monster attack table and adds +2 damage after a successful weapon hit; do not also add the ordinary leader''s +1. The daylight -1 Hit penalty applies to the chieftain as well. These rules are conditions for the Combat Agent to interpret and propose; generic deterministic tools validate and apply them. Do not infer numerical morale penalties merely from Orc fear of strong foes.',
         N'Ordinary Orcs attack once with equipped weapon using the authorised Combat roster''s hit table and damage profile. A fighting Orc, including a chieftain, has -1 to its Hit roll in daylight; this changes neither AC nor damage. The explicitly assigned ordinary group leader has 8 starting HP supplied before combat and +1 damage on successful weapon hits, not +1 Hit. Confirmed death of that leader changes the surviving group''s morale from 8 to 6 but creates NO additional unscheduled morale check: use the next normal generic check. A separate tribal chieftain has 15 starting HP supplied by Encounter, attacks on the 4-HD hit table and adds +2 weapon damage, NOT an additional ordinary leader +1. Combat Agent proposes appropriate signed modifiers by actor and event; generic deterministic tools validate and commit effects. All attack rolls, damage rolls, morale triggers and state transitions must be journalled.',
         N'Nocturnal, quarrelsome, ill-tempered omnivorous humanoids, normally dwelling underground; likely hostile but may threaten, bargain, talk, stand off, obey a stronger leader or retreat when intimidated. They are cautious around foes larger or stronger than themselves; this is a behavioural preference, not an automatic fear or Hit penalty. Typical weapons are swords, spears, axes or clubs; nonleaders are not competent with siege/mechanical weapons such as catapults. Orcs commonly form groups with an ordinary leader; a chieftain belongs to separately identified large tribal contexts. Normally 2-8 Orcs, 10-60 in a lair. Tribes may have equal male/female numbers and two young per two adults; possible Ogre support on a 1-in-6 chance per twenty tribal Orcs. Optional Expert-only troll presence (1-in-10 chance) applies ONLY if the Expert overlay is enabled, not in the current Mentzer Basic game. Orcs may serve in larger Chaotic armies. Encounter chooses group count, roles, weapons, environment, intentions, reaction, negotiation and whether combat begins, and supplies daylight to Combat. No special surprise range is stated: normal two-side surprise procedure when appropriate. Never force combat or import B1-specific encounter stats.'),
        (N'GIANT_CENTIPEDE', N'A Giant Centipede attacks once by biting. If its Hit roll misses, no poison saving throw or damage is caused. If its bite hits, the bite itself causes zero HP damage; the bitten target must make a Saving Throw versus Poison. A successful save causes no illness or condition. A failed save applies the owner-approved named condition NAUSEATED to the actual victim. It lasts ten days of in-game time, allows movement at half normal speed, and forbids other physical actions while active. It is not death, continuing HP poison damage, a second saving throw, or complete immobility. The current prototype Combat test only checks the correct bite/save trigger, zero damage, and initial NAUSEATED assignment; enforcing movement/action limits, lasting time, persistence and expiry belongs to generic future lifecycle story AIDM-DES-001.7.5. The Combat Agent selects the relevant Poison save/effect proposal; generic tools resolve and commit state.',
         N'One bite attack. A miss triggers neither HP damage nor saving throw. A successful bite deals zero HP damage and obliges the actual bitten actor to Save vs Poison using that victim''s saving-throw profile, not the centipede''s Save As. Success causes no additional effect; failure assigns generic NAUSEATED to the correct actor. Source effect lasts ten in-game days and permits only half-speed movement, forbidding other physical actions; the CURRENT Combat fixture checks only initial named-state assignment and no bite damage. World-time duration, movement/action restrictions, cross-encounter persistence and expiry belong to generic lifecycle Build AIDM-DES-001.7.5. No automatic death, extra HP poison damage or save on miss. Source attribution and each hit/save are journalled.',
         N'Approximately one foot long, crawling on many legs; prefers damp, dark dungeon areas. Many may gather around moist stone, debris or refuse; its appearance and movement can be described to players and may provoke caution, avoidance, inspection or parley attempts, without presuming intelligent conversation or forcing combat. Mentzer number appearing 2-8 normally, 1-8 in a lair. No unusual surprise threshold or special hiding/surprise bonus stated: standard side-based surprise when relevant. A poisonous bite is NOT an ambient exposure: do not apply NAUSEATED merely because the creature is seen or approaches. If anyone remains ill after a fight, future Expedition/Bookkeeper world-time service preserves the condition; Encounter does not prematurely expire it. No made-up stench radius or extra mechanics.'),
        (N'CARRION_CRAWLER', N'The Carrion Crawler can make eight independent tentacle Hit rolls in a round, each against a legal target chosen by its Combat Agent within the permitted attack/target sequence. A miss causes neither damage nor saving throw. Each tentacle hit deals zero HP damage but requires the struck target to save versus Paralysis; a failed save marks that individual PARALYZED. The crawler generally prefers an unparalysed viable opponent over wasting further attacks on a helpless target and may distribute its permitted attacks among eligible foes. When it is no longer under attack and prey is paralysed, it seeks to feed; do not invent a new bite-damage schedule or automatic death. Generic PARALYZED rules: the victim remains conscious but cannot move, speak, attack or cast; attacks against a paralysed victim automatically hit and need only a damage roll. Base paralysis typically lasts 2d4 dungeon turns unless overridden; Cure Light Wounds can instead remove paralysis without healing HP. The initial crawler Combat test requires only separate attacks, correct-target saves and PARALYZED assignment; lifecycle/recovery/automatic-hit verification is deferred to generic story AIDM-DES-001.7.6. No species-specific hardcoded Python branch.',
         N'A living Carrion Crawler has eight tentacles which may each make a separately journalled Hit roll in the same round when eligible. Every tentacle hit causes zero HP damage and one Save vs Paralysis for the actual target; a miss causes neither save nor paralysis. On failed save, apply PARALYZED to the correct victim; no invented tentacle poison or bite damage. Generic PARALYZED state leaves the victim conscious but unable to move, speak, attack or cast, with attacks on paralysed victims automatically hitting and default duration 2d4 dungeon turns unless source changes it. This current Combat fixture verifies only independent hits/saves and initial PARALYZED assignment; ongoing expiry, auto-hit and cure are separately owned by AIDM-DES-001.7.6. A monster agent may prefer still-active targets during attacks; all rolls and effect commits remain deterministic and audited.',
         N'A revolting roughly nine-foot scavenger, feeding on carrion and helpless prey, crawling along floors, walls and ceilings with many short legs and eight probing mouth tentacles. Found in deep, filthy, dank dungeon areas; narrate sound, smell, investigation, discovery and fear without inventing numerical surprise/fear mechanics. Number appearing 1-4 normally; 0 in lair in the Mentzer table. No special surprise threshold documented; generic two-side procedure only. A crawler generally engages viable threats rather than wasting tentacles on already paralysed prey, and attempts to approach helpless prey to feed when no one threatens it; do not invent automatic death or bite damage. Players may decide to fight, attempt parley or a stand-off, avoid it, or flee; recognise FLEE intent and hand off unresolved escape to Encounter/Expedition, not automatic successful escape. Wall/ceiling movement, spatial approach, exits, chase and feeding outcomes are deferred to Encounter/Geometry/Expedition. CRAW-T001 tests four crawlers as an intentionally dangerous, unbalanced stress encounter; do not quietly rebalance or script a wipe.'),
        (N'GIANT_CRAB_SPIDER', N'Camouflage allows the Crab Spider to surprise enemies on party-side surprise die results 1-4 on 1d6, rather than the normal 1-2; the spiders'' own vulnerability to being surprised is the ordinary 1-2. Resolve this at the generic Encounter surprise boundary, using one roll per side; do not roll per spider or automatically grant a surprise round. After its first attack, the spider is visible and may be targeted normally. In combat it makes one bite attack: a miss causes no damage and no poison save; a hit causes 1d8 direct HP damage and requires the victim to Save versus Poison, adding +2 to that victim''s save roll because the venom is weak. A successful save avoids poison while keeping the bite damage. On failed save, assign generic POISONED to the actual victim, source attributed to that spider; the full source effect can cause delayed death in 1d4 dungeon turns, NOT immediate death on the bite. Current combat acceptance checks only HP damage, the correct +2 Poison save and initial POISONED state; timing/recovery is deferred to AIDM-DES-001.7.7. Fire avoidance is tactical behaviour, not a guaranteed fear effect or numeric modifier. The spider does not create webs.',
         N'A Giant Crab Spider has one bite attack per eligible round. If it misses, there is no HP damage or poison saving throw. A successful bite deals 1d8 HP damage and separately triggers Save vs Poison for the actual victim with +2 to the victim''s save roll due to weak venom. Pass avoids the poison but not initial bite damage; fail marks the correct actor POISONED with source spider identified. In the full rule the venom can cause delayed death after 1d4 dungeon turns, but current Combat fixture checks only initial POISONED assignment, not timer, death, treatment or expiry; generic lifecycle is AIDM-DES-001.7.7. The +2 is NOT an attack or damage bonus. No extra web attack, fire fear penalty, automatic morale check, or immediate fatal poison. Deterministic tools resolve damage, saves and state changes.',
         N'Five-foot-long, relatively unintelligent carnivorous spider with mottled camouflaging colour; moves across walls and ceilings and can drop suddenly upon prey. It DOES NOT create webs. In suitable camouflage, its presence changes the opposing party''s surprise threshold from the normal 1-2 on d6 to 1-4 on d6. Its own group still uses normal vulnerability to surprise 1-2 on d6; one roll PER SIDE, not one per spider. After its initial attack the spider becomes visible and targetable normally. Often retreats from conspicuous fire, but a torch does not automatically impose a numerical Hit, AC, morale or damage penalty, nor trigger an extra morale check; cautious, avoidance, retreat, tactical intimidation and reaction/parley may be interpreted by Encounter within source rules. No forced attack if creatures can avoid or stand off. Appears 1-4 normally/in lair. Scenes specify available walls/ceiling/lighting and whether camouflage is physically applicable; no assumed surprise in an unsuitable environment. Keep the CRAB-T001 fixed surprise result (party 5, spider group 2: spiders surprised) in the Scenario table, not in this species definition. Artwork is DRAFT with incorrect webs and adventurer figures: never treat it as approved reference art.');
    -- Only original inactive draft rows, and only when field is still empty.
    -- If source text was manually changed, leave that COMBAT text untouched;
    -- still add reviewable encounter guidance without losing owner edits.
    UPDATE m
       SET [SpecialEncounterFeatures] = k.[EncounterOnly],
           [SpecialAttacksFeatures] =
              CASE WHEN m.[SpecialAttacksFeatures] = k.[LegacyCombat]
                   THEN k.[CombatOnly] ELSE m.[SpecialAttacksFeatures] END
    FROM [Rules].[Monster] AS m
    JOIN @Known AS k ON k.[MonsterCode] = m.[MonsterCode]
    WHERE m.[RulesetCode] = N'MentzerBECMI'
      AND m.[Active] = 0 AND m.[SourceStatus] = N'SourceChecked'
      AND m.[SpecialEncounterFeatures] = N'';
    DECLARE @Backfilled INT = @@ROWCOUNT;

    -- Troglodyte source guidance is separately registered in v0.4 seed/migration.
    UPDATE m
       SET [SpecialEncounterFeatures] = N'Intelligent, upright reptilian humanoids with short tails, long legs and a spiny comb on head and arms. Colour-changing camouflage against rock walls can surprise opponents on 1-4 on their party-side d6 when appropriate; troglodytes themselves use the ordinary 1-2 surprise vulnerability. Scene and walls must support camouflage; use one surprise roll per side, never one per monster. They are generally hateful and aggressive toward most other creatures, but can be approached for parley, avoidance, threats, stand-off, retreat, or other attempts without forcing predetermined battle. Their foul oily stench can affect exposed humans and demi-humans; the Encounter/scene must supply actor-specific exposure evidence, not infer everyone exposed from mere roster presence. Source leaves radius, re-save interval and expiry unspecified: defer rather than invent. Encounter prepares surprise, scene, stench exposure and roster and passes them to Combat. Mentzer appears 1-8 normally or 5-40 in lair. Humanoid ellipse full diameters D1=D2=5 ft are AIDM modelling convention, not Mentzer mechanics.',
           [SpecialAttacksFeatures] =
              CASE WHEN m.[SpecialAttacksFeatures] LIKE N'Ordinary close combat: a Troglodyte has THREE separate attacks%'
                   THEN N'Ordinary close combat: a Troglodyte has THREE separate attacks in a round, two claws and one bite, each with its own Hit roll and, on hit, 1d4 damage. Its oily stench affects humans and demi-humans exposed according to validated Encounter scene facts: a failed Save vs Poison assigns the owner-approved RETCHING state to the actual victim; while fighting a Troglodyte hand-to-hand, the affected victim has -2 on Hit rolls. This is not a damage, AC, missile, spell or universal melee penalty, and NOT the Giant Centipede ten-day NAUSEATED illness. The monster entry does not specify exposure radius, repeat-save cadence or expiry, so the Combat Agent may not invent those. Exact exposure, actor, source and saving throw outcome are journalled using generic tools. Each of the three attacks is separately resolved.'
                   ELSE m.[SpecialAttacksFeatures] END
    FROM [Rules].[Monster] AS m
    WHERE m.[RulesetCode] = N'MentzerBECMI'
      AND m.[MonsterCode] = N'TROGLODYTE'
      AND m.[Active] = 0 AND m.[SourceStatus] = N'SourceChecked'
      AND m.[SpecialEncounterFeatures] = N'';

    DECLARE @TroglodytesBackfilled INT = @@ROWCOUNT;
    COMMIT;
    PRINT CONCAT(N'Updated ', @Backfilled, N' original species rows and ',
                 @TroglodytesBackfilled, N' Troglodyte row(s).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT [RulesetCode], [MonsterCode], [RecordDate], [SourceStatus], [Active],
       LEN([SpecialAttacksFeatures]) AS [CombatGuidanceChars],
       LEN([SpecialEncounterFeatures]) AS [EncounterGuidanceChars]
FROM [Rules].[Monster]
ORDER BY [MonsterCode], [RecordDate] DESC;
GO
