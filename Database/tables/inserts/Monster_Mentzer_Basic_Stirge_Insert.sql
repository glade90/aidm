/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Stirge_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Stirge_Insert.sql
Project         : Golden Braid / AIDM / AIDM-DES-001.7
Target          : PEQUOD DnD.[Rules].[Monster] v0.4
Version         : 0.1.0 / SOURCE CHECKED / INACTIVE
Source          : Original 1983 Mentzer Basic DM Rulebook Stirge p.38.
Created         : 2026-11-21
Boundary        : B1 S11 selects species only, never stats, counts or HP.
                  Encounter test STIRGE-T001 is separate Test schema data.
                  This script preserves historical existing species rows.
                  The illustration shows Stirges attacking in a dungeon and
                  need not match the fixture's exact encounter size.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
 THROW 56700, 'Rules.Monster missing', 1;
IF COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D2Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 56701, 'Rules.Monster v0.4 including SpecialEncounterFeatures and diameters required', 1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS
 (
  SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
  WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'STIRGE'
 )
 BEGIN
  INSERT INTO [Rules].[Monster]
  ([RecordDate], [RulesetCode], [MonsterCode], [Active], [MonsterName], [ParentMonsterCode], [SourceStatus], [SourceReference], [HouseRuleOverlayRefs], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
  VALUES
  (CONVERT(DATE, SYSUTCDATETIME()),
   N'MentzerBECMI',
   N'STIRGE',
   0,
   N'Stirge',
   NULL,
   N'SourceChecked',
   N'1983 Mentzer Basic Dungeon Masters Rulebook, Stirge, printed p.38.',
   NULL,
   7,
   N'1*',
   N'1 beak attack',
   N'1d3 on hit; 1d3 automatic drain/round while attached',
   N'Fighter 2',
   9,
   30,
   10,
   N'Flying: 180 ft per turn, 60 ft per round.',
   N'Neutral',
   13,
   N'1-10 normally; 3-36 in lair',
   N'L',
   N'A small, birdlike blood-feeding creature with a long narrow nose or beak. Its rapid wings allow it to dive into prey, drive its beak into the body, and cling there while drinking blood. Describe the wingbeats, approach and struggle dramatically, without adding unsupported poison, disease, paralysis or other effects.',
   N'A Stirge makes one normal Hit roll on its first eligible beak attack against an opponent. A FLYING Stirge receives +2 to its first Hit Roll AGAINST ANY ONE OPPONENT because of a speedy diving attack; this modifies the Hit roll, NOT the damage roll. The exact source wording should be retained for future adjudication of target changes; do not silently grant a renewed +2 for a repeat attack on the same opponent. A successful Hit inflicts 1d3 damage and IMMEDIATELY establishes a source-tagged ATTACHED relationship from this Stirge actor to the actual victim actor (no saving throw). Thereafter it sucks blood for another 1d3 HP damage PER ROUND without further Hit rolls while the relationship remains legal, until dead. Each attacker/victim relationship must have distinct IDs and be journalled; multiple Stirges may attach to the same victim without overwriting one another. This drain is not a new conventional bite action and should not receive repeat diving bonuses. The book does not provide a special Strength DC, voluntary detachment rule, probability for pulling one off, separate hit penalties to attack an attached Stirge, or a blood-volume limit; these are DEFERRED discretionary rulings, not invented mechanics. If the Stirge is killed, its draining must cease. The source phrase ''until dead'' does not explicitly adjudicate every post-victim-death/detachment situation; the generic relationship/state service and future Encounter/Rules design must track unresolved cases rather than automatically assign an arbitrary duration. The Stirge has no poison save or poison condition. Distinguish baseline ground movement (30 ft/turn, 10 ft/round) from flight (180 ft/turn, 60 ft/round); a dive bonus requires verified flight and a qualifying first attack.',
   N'Stirges are birdlike flying blood-feeders with long beaks. They seek living victims, dive rapidly at suitable targets, attach if successful and feed; their approach, distance, ceiling position, visible flock, hunting, alarm and pursuit are narrative/tactical scene facts, not automatic extra attacks, initiative or surprise modifiers. Encounter controls arrival number (1-10 normally, 3-36 in lair), real flight state, terrain/altitude, viable targets, player choices (fight, avoid, scare away, retreat, attempt to remove the parasite, use a shield or cover), and any unresolved interaction that calls for a referee ruling. No Stirge-specific surprise threshold is written in the 1983 monster entry: use normal one-1d6-per-side surprise (1-2) unless a separate sourced situation changes it. Ground movement 30 ft/turn (10 ft/round), flying 180 ft/turn (60 ft/round); flying altitude and geometry belong to Encounter/Geometry, never inferred from the presence of wings alone. Preserve per-target first-attack provenance for the Combat Agent. Attached Stirges remain separate actors physically linked to particular victims. Attacking or detaching a living attached Stirge, including whether friendly fire is possible, lacks an explicit procedure in the monster entry and requires an approved one-off Rules Referee ruling rather than a fabricated Strength roll or automatic detach. No assumption that a flock has magical coordination, poison or special disease. Source B1 S11 is ONLY a species-review selector, never the fixture count or starting HP.',
   2,
   2,
   1,
   N'AIDM estimated 2ft×2ft full diameters and 1ft height; Mentzer gives no species dimensions.',
   N'assets/images/monsters/AIDM_STIRGE-T001_Stirge_Assault_Illustration.webp',
   NULL,
   N'Species source Frank Mentzer 1983 D&D Basic Dungeon Masters Rulebook p38, Stirge: AC7, HD1*, movement 30 (10) ground, 180 (60) flying, one attack for 1-3 damage, appearing 1-10 (3-36), save Fighter2, morale9, treasure L, Neutral, XP13; successful Hit attaches and deals 1d3, then 1d3 blood drain each round until dead; flying first Hit Roll against any one opponent +2. Size D1=2ft, D2=2ft FULL footprint diameters, estimated Z=1ft are owner-accepted modelling estimates, not Mentzer stat lines. No poison, disease or saving throw specified. For source-verifiable simulated encounter see STIRGE-T001 in Test schema, with exact dice faces and initial surprise. Artwork depicts a subset of attacking Stirges, NOT the exact rolled count of ten. SourceChecked/Active=0 remains until authorised activation.');
  PRINT N'Stirge SourceChecked inactive monster species inserted.';
 END
 ELSE PRINT N'STIRGE already exists: no overwrite or duplicate version.';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],
       [SourceStatus],[Active],[ArmorClass],[HitDiceText],[AttackPattern],
       [DamagePattern],[MovementTurnFeet],[MovementRoundFeet],
       [MovementSpecialText],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'STIRGE'
ORDER BY [RecordDate] DESC;
GO
