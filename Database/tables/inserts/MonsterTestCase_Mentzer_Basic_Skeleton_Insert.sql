/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestCase_Mentzer_Basic_Skeleton_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestCase_Mentzer_Basic_Skeleton_Insert.sql
Project         : Golden Braid / AIDM / B1 stocklist S14
Purpose         : 27 source-checked Combat/Encounter/Deferred Skeleton case definitions.
Target          : PEQUOD, SQL Server 2016+, DnD
Version         : 0.1.0, SourceChecked or Specified, NOT active/executed
Created         : 2026-11-22
Sources         : 1983 Mentzer Basic DM Rulebook p.37 (Skeleton), Players
                  Manual pp.25 (Turning) and 59-60 (weapons/holy water).
Boundary        : B1 Monster List #14 selects species only; never reuse its
                  preassigned monster counts, Hit Points or item data.
                  Turning mechanics are ALREADY tracked in existing story
                  AIDM-DES-001.7.10. No duplicate implementation story.
                  Equipment belongs to the encounter, not every Skeleton.
                  SourceChecked/Specified = NOT approved, activated or passed.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestCase',N'U') IS NULL
 THROW 56920,'Test.MonsterTestCase missing',1;
IF NOT EXISTS (
 SELECT 1 FROM [Test].[MonsterTestScenario]
 WHERE [ScenarioCode]=N'SKELETON-T001'
) THROW 56921,'SKELETON-T001 scenario missing; run scenario insert first',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @Seed TABLE (
 [ScenarioCode] NVARCHAR(80) NOT NULL,
 [TestCaseCode] NVARCHAR(80) NOT NULL,
 [SequenceNo] INT NOT NULL,
 [TestName] NVARCHAR(180) NOT NULL,
 [TestPhase] NVARCHAR(40) NOT NULL,
 [TestStatus] NVARCHAR(20) NOT NULL,
 [TestRevision] INT NOT NULL,
 [GivenText] NVARCHAR(MAX) NOT NULL,
 [ExpectedText] NVARCHAR(MAX) NOT NULL,
 [DiceFixtureJson] NVARCHAR(MAX) NULL,
 [AdditionalDataJson] NVARCHAR(MAX) NULL,
 [LinkedStoryRef] NVARCHAR(80) NULL,
 [AutomatedTestRef] NVARCHAR(500) NULL,
 [Notes] NVARCHAR(MAX) NULL,
 PRIMARY KEY ([ScenarioCode],[TestCaseCode]),
 UNIQUE ([ScenarioCode],[SequenceNo])
 );
 INSERT INTO @Seed
 ([ScenarioCode], [TestCaseCode], [SequenceNo], [TestName], [TestPhase], [TestStatus], [TestRevision], [GivenText], [ExpectedText], [DiceFixtureJson], [AdditionalDataJson], [LinkedStoryRef], [AutomatedTestRef], [Notes])
 VALUES
 (N'SKELETON-T001', N'SKELETON-C01', 1, N'One ordinary weapon attack per eligible round', N'COMBAT', N'Specified', 1, N'SKELETON-1 is armed with an ordinary sword and active in a legal attack round.', N'Resolve exactly one sword Hit roll and, if successful, one damage roll; no extra skeletal claw or bite.', N'{"hit_d20":17,"damage_d8":5}', N'{"attacks_per_round":1,"weapon":"Sword (normal)","variable_damage":true}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C02', 2, N'Normal sword uses d8 variable weapon damage', N'COMBAT', N'Specified', 1, N'SKELETON-1 makes one successful normal sword strike under the optional variable damage rule; d8=5.', N'Damage is 5 (on 1d8), not 1d6 or an invented rapier die.', N'{"damage_d8":5}', N'{"actor":"SKELETON-1","weapon":"Sword (normal)"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C03', 3, N'Mace uses d6 variable weapon damage', N'COMBAT', N'Specified', 1, N'SKELETON-2 successfully strikes with mace; variable weapon damage d6=4.', N'Apply 4 HP damage, without special anti-living or anti-undead modifier.', N'{"damage_d6":4}', N'{"actor":"SKELETON-2","weapon":"Mace"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C04', 4, N'Battle axe uses d8 and two hands', N'COMBAT', N'Specified', 1, N'SKELETON-3 strikes successfully with battle axe; damage d8=7. No shield is equipped.', N'Apply 7 HP damage, require two hands; no shield AC benefit or extra attack.', N'{"damage_d8":7}', N'{"actor":"SKELETON-3","weapon":"Battle Axe","two_handed":true}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C05', 5, N'Spear uses d6 variable weapon damage', N'COMBAT', N'Specified', 1, N'SKELETON-4 attacks with spear in melee and hits; variable weapon damage d6=3.', N'Apply 3 damage on one attack. Do not also throw the same spear in that round.', N'{"damage_d6":3}', N'{"actor":"SKELETON-4","weapon":"Spear"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C06', 6, N'Club uses d4 variable weapon damage', N'COMBAT', N'Specified', 1, N'SKELETON-5 hits with club; variable damage d4=2.', N'Apply exactly 2 HP damage.', N'{"damage_d4":2}', N'{"actor":"SKELETON-5","weapon":"Club"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C07', 7, N'Pole arm uses d10 and two hands', N'COMBAT', N'Specified', 1, N'SKELETON-6 successfully strikes with pole arm; damage d10=8; shield not equipped.', N'Apply 8 HP damage with two hands; no shield benefit.', N'{"damage_d10":8}', N'{"actor":"SKELETON-6","weapon":"Pole Arm","two_handed":true}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C08', 8, N'Two-handed weapons always lose individual initiative', N'COMBAT', N'Specified', 1, N'SKELETON-3 carries Battle Axe, SKELETON-6 carries Pole Arm; their allies carry ordinary one-hand weapons; both sides have rolled initiative.', N'Delay the actions of the two two-handed wielders according to Mentzer individual initiative penalty; do not apply penalty to all six or let a winning side cancel the penalty.', N'{"party_initiative_1d6":1,"skeleton_side_initiative_1d6":6}', N'{"penalised_actor_ids":["SKELETON-3","SKELETON-6"],"never_assign_shields":true}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C09', 9, N'Standard damage when variable weapon damage disabled', N'COMBAT', N'Specified', 1, N'Same six Skeletons, but optional variable weapon damage OFF. SKELETON-5 hits with club; standard damage 1d6=4.', N'Use 1d6=4, not the club variable d4; keep source weapon identity unchanged.', N'{"standard_damage_d6":4}', N'{"actor":"SKELETON-5","variable_weapon_damage":false}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C10', 10, N'Hit and damage follow generic one-HD Skeleton statistics', N'COMBAT', N'Specified', 1, N'A Skeleton has AC7, HD1, 1d8 fixed starting HP from roster; it takes a successful legal attack for 4 damage.', N'Subtract 4 from that actor only; do not share HP or change species AC based on the illustrational cloak/shield.', N'{"incoming_damage":4}', N'{"actor":"SKELETON-1","hp_start":6,"hp_remaining":2}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C11', 11, N'Zero HP destroys the corresponding Skeleton', N'COMBAT', N'Specified', 1, N'SKELETON-5 has four starting HP, receives 4 or more legal damage.', N'Set SKELETON-5 as defeated; it cannot make further attack rolls. Other Skeletons remain independent actors.', N'{"incoming_damage":4}', N'{"actor":"SKELETON-5","hp_start":4,"hp_remaining":0}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C12', 12, N'Sleep has no effect on undead Skeletons', N'COMBAT', N'Specified', 1, N'Valid Sleep spell resolves over a group including SKELETON-1 and ordinary living creatures.', N'Do not select or affect Skeletons, regardless of their 1 Hit Die; do not ask Skeletons to roll a save.', NULL, N'{"creature_tag":"undead","spell":"Sleep"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C13', 13, N'Charm does not affect Skeletons', N'COMBAT', N'Specified', 1, N'A Charm spell attempts to affect SKELETON-1.', N'Apply source-backed Charm immunity; no charmed condition and no unsupported chance or saving throw.', NULL, N'{"creature_tag":"undead","effect":"Charm"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C14', 14, N'Mind reading fails against Skeleton', N'COMBAT', N'Specified', 1, N'A mind reading effect targets an animated Skeleton.', N'No thoughts can be read: Skeleton is immune; do not invent intelligence, mental command disclosure or saving throw.', NULL, N'{"effect":"mind_reading"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C15', 15, N'Morale 12 fights until destroyed', N'COMBAT', N'Specified', 1, N'One of six Skeletons falls in combat; other Skeletons have Morale 12 and are not Turned.', N'Ordinary morale cannot make Skeletons retreat or surrender; a lawful Turning result may still force flight. Do not replace this with a universal immunity to fleeing.', NULL, N'{"morale":12,"turning_active":false}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C16', 16, N'Holy water causes 1d8 against undead on a hit', N'COMBAT', N'Specified', 1, N'A vial of holy water successfully hits an undead Skeleton and breaks; rolled holy water d8=6.', N'Apply 6 damage under the generic holy-water-vs-undead rule; miss or unbroken vial does not deliver damage.', N'{"holy_water_d8":6}', N'{"item":"Holy Water","hit":true,"vial_breaks":true}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-C17', 17, N'No bonus damage for blunt weapons without a rule', N'COMBAT', N'Specified', 1, N'A character hits a Skeleton with a normal mace, which already uses a base 1d6 under optional weapon damage.', N'Do not double or alter damage merely because a Skeleton has bones; its monster entry specifies no blunt vulnerability.', N'{"mace_damage_d6":3}', N'{"damage_expected":3}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E01', 18, N'Mentzer normal appearance and six independent HP', N'ENCOUNTER', N'Specified', 1, N'Roll recorded 3d4 faces [1,3,2] for number appearing; roll a separate d8 per Skeleton [6,5,3,2,4,7].', N'Spawn six separate actors with stable IDs and HP respectively 6,5,3,2,4,7; 27 total. Never import the B1 S14 stock count or HP.', N'{"number_appearing_3d4":[1,3,2],"hp_1d8":[6,5,3,2,4,7]}', N'{"count":6,"hp_total":27}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E02', 19, N'One surprise roll per side', N'ENCOUNTER', N'Specified', 1, N'Party surprise d6=2; Skeleton side d6=3.', N'Party surprised, Skeletons not surprised; one roll per side, not six independent Skeleton surprise rolls.', N'{"party_surprise_d6":2,"skeleton_side_surprise_d6":3}', N'{"party_surprised":true,"skeletons_surprised":false}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E03', 20, N'Equipment is actor-specific, not species default', N'ENCOUNTER', N'Specified', 1, N'Roster has six Skeleton actors with distinct ordinary Mentzer weapons: Sword, Mace, Battle Axe, Spear, Club, Pole Arm.', N'Encounter supplies per-actor equipment; species remains generic by-weapon. No rapier and no six identical weapons.', NULL, N'{"weapon_names":["Sword (normal)","Mace","Battle Axe","Spear","Club","Pole Arm"]}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E04', 21, N'Guard role does not create extra combat abilities', N'ENCOUNTER', N'Specified', 1, N'Six Skeletons guard a dungeon passage under a creator order.', N'Encounter can narrate and select guard targets using scene facts, but grants no extra attacks, armor, magical fear, perception or initiative merely from guardian role.', NULL, N'{"role":"guard","species":"SKELETON"}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E05', 22, N'Avoided encounter does not force an attack sequence', N'ENCOUNTER', N'Specified', 1, N'Party detects six Skeletons and withdraws before entering their guarded space; no combat declaration.', N'Encounter respects player withdrawal and dungeon context; do not force damage rolls merely because Skeletons are Chaotic.', NULL, N'{"party_action":"withdraw","combat_started":false}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E06', 23, N'Movement: 60 feet per turn, 20 per round', N'ENCOUNTER', N'Specified', 1, N'A Skeleton is unTurned and moves on unobstructed dungeon ground.', N'Use 60 ft/turn exploration and 20 ft/round encounter movement; no speed boost from weapon type.', NULL, N'{"movement_ft_turn":60,"movement_ft_round":20}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-E07', 24, N'No invented surprise or special treasure', N'ENCOUNTER', N'Specified', 1, N'Skeletons have no special surprise threshold; Treasure Type Nil.', N'Resolve standard one-die-per-side surprise; do not add species surprise modifiers or invented carried treasure. Scenario equipment does not create treasure automatically.', NULL, N'{"treasure_type":"Nil","special_surprise":false}', N'AIDM-DES-001.7', NULL, NULL),
 (N'SKELETON-T001', N'SKELETON-L01', 25, N'Shared Cleric Turning result integration', N'DEFERRED_LIFECYCLE', N'Deferred', 1, N'Cleric attempts Turning on a mixed encounter including Skeleton actors; generic Turning story already exists.', N'Once AIDM-DES-001.7.10 is implemented, resolve generic cleric Turning by level and table, assign selected Skeleton actor IDs from HD affected, without building a Skeleton-only Turning routine.', N'{"cleric_level":1,"turning_2d6":[3,4],"affected_hd_2d6":[4,3]}', N'{"existing_story":"AIDM-DES-001.7.10","turning_threshold_first_level":7}', N'AIDM-DES-001.7.10', NULL, N'Deferred integration evidence only; linked existing story; do not create duplicate Build Story.'),
 (N'SKELETON-T001', N'SKELETON-L02', 26, N'Turned Skeletons retreat and may return', N'DEFERRED_LIFECYCLE', N'Deferred', 1, N'Generic Turning successfully affects a subset of Skeletons; hypothetical 1d10=6 rounds away.', N'Future shared Turning/Encounter integration should move affected actors away, keep 1-10 round lifecycle and apply DM decision or 2d6 reaction 8+ for potential return. Not a species-specific implementation.', N'{"turning_duration_1d10":6,"return_reaction_2d6":[4,4]}', N'{"existing_story":"AIDM-DES-001.7.10","reaction_8_plus_returns":true}', N'AIDM-DES-001.7.10', NULL, N'Deferred until shared undead Turning lifecycle is implemented and tested.'),
 (N'SKELETON-T001', N'SKELETON-L03', 27, N'Concurrent two-handed initiative integration', N'DEFERRED_LIFECYCLE', N'Deferred', 1, N'Two actors wield 2-handed weapons while other four have ordinary one-handed melee weapons; both sides roll one initiative die.', N'Integration into current initiative resolver needs explicit per-attacker ordering without penalising one-handed allies. Confirm with existing generic weapon initiative rules.', N'{"party_initiative_1d6":2,"skeleton_side_initiative_1d6":5}', N'{"two_handed_ids":["SKELETON-3","SKELETON-6"]}', N'AIDM-DES-001.7', NULL, N'Scenario acceptance deferred until existing initiative engine implements Mentzer two-handed rule consistently.');
 INSERT INTO [Test].[MonsterTestCase]
 ([ScenarioCode], [TestCaseCode], [SequenceNo], [TestName], [TestPhase], [TestStatus], [TestRevision], [GivenText], [ExpectedText], [DiceFixtureJson], [AdditionalDataJson], [LinkedStoryRef], [AutomatedTestRef], [Notes])
 SELECT s.[ScenarioCode], s.[TestCaseCode], s.[SequenceNo], s.[TestName], s.[TestPhase], s.[TestStatus], s.[TestRevision], s.[GivenText], s.[ExpectedText], s.[DiceFixtureJson], s.[AdditionalDataJson], s.[LinkedStoryRef], s.[AutomatedTestRef], s.[Notes]
 FROM @Seed AS s
 WHERE NOT EXISTS (
  SELECT 1 FROM [Test].[MonsterTestCase] AS existing WITH (UPDLOCK,HOLDLOCK)
  WHERE existing.[ScenarioCode]=s.[ScenarioCode]
    AND existing.[TestCaseCode]=s.[TestCaseCode]
 );
 DECLARE @Inserted INT=@@ROWCOUNT;
 COMMIT;
 PRINT CONCAT(N'Inserted ',@Inserted,N' Skeleton case definitions; existing rows preserved.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],
       [TestPhase],[TestStatus],[LinkedStoryRef]
FROM [Test].[MonsterTestCase]
WHERE [ScenarioCode]=N'SKELETON-T001'
ORDER BY [SequenceNo];
GO