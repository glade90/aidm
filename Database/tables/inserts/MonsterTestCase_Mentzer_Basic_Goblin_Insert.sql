/*
===============================================================================
Golden Braid / AIDM / B1 S16 — Goblin (1983 Mentzer Basic)
FILE: MonsterTestCase_Mentzer_Basic_Goblin_Insert.sql
TARGET: DnD.[Test].[MonsterTestCase] (PEQUOD, SQL Server 2016+)
SOURCE: Mentzer Dungeon Masters Rulebook, Goblin, printed p.31.
        B1 In Search of the Unknown #16 selects species ONLY;
        module-defined count, HP and scene are not imported.
NOTES: 2026-11-22. Rerunnable inserts never overwrite existing catalogue
       or test records. SourceChecked and Specified are NOT approval, test
       execution or user acceptance. SQL is not executed by commit.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestCase',N'U') IS NULL
 THROW 56942,'Test.MonsterTestCase missing',1;
IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode]=N'GOBLIN-T001')
 THROW 56943,'GOBLIN-T001 missing: deploy Goblin scenario insert first',1;
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
    [Notes] NVARCHAR(MAX) NULL
 );
 INSERT INTO @Seed ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],[TestStatus],[TestRevision],[GivenText],[ExpectedText],[DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes]) VALUES
 (N'GOBLIN-T001',N'GOB-C01',1,N'One ordinary equipped-weapon attack',N'COMBAT',N'Specified',1,N'Ordinary Goblin actor is active and has a valid melee target.',N'Resolve one attack roll using up-to-1-HD monster attack table; no innate extra attack.',N'{"attack_d20":15}',N'{"role":"ordinary","attacks_per_round":1}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C02',2,N'Normal vs variable weapon damage',N'COMBAT',N'Specified',1,N'GOB-T001-1 has sword (normal) and hits.',N'Standard Mentzer weapon mode inflicts 1d6; variable damage mode inflicts sword 1d8; no Goblin-specific damage bonus.',N'{"standard_d6":4,"sword_d8":6}',N'{"weapon":"Sword (normal)"}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C03',3,N'Full daylight penalty modifies Hit roll ONLY',N'COMBAT',N'Specified',1,N'Synthetic branch overrides the same ordinary Goblin actor environment to full daylight.',N'Apply exactly -1 to final HIT ROLL; do not subtract from damage, saving throws, initiative, Armor Class, surprise or morale.',N'{"attack_d20":13,"damage_d8":5}',N'{"full_daylight":true,"hit_modifier":-1,"damage_modifier":0,"original_scene_outdoors":false}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C04',4,N'Torchlight in dungeon is not full daylight',N'COMBAT',N'Specified',1,N'GOBLIN-T001 dungeon scene is underground, lit by wall torches without natural full daylight.',N'Do NOT apply daylight -1 to a Goblin Hit roll; normal weapon and other generic modifiers still apply.',N'{"attack_d20":13}',N'{"full_daylight":false,"lighting":"torchlight","expected_daylight_hit_modifier":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C05',5,N'No inherited Hobgoblin daylight immunity',N'COMBAT',N'Specified',1,N'Ordinary Goblin is artificially placed in an outdoor full-daylight branch.',N'Use Goblin -1 Hit, unlike the Hobgoblin species which has no daylight penalty.',N'{"attack_d20":13}',N'{"species":"GOBLIN","full_daylight":true,"expected_hit_modifier":-1}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C06',6,N'No racial attack bonus against dwarf',N'COMBAT',N'Specified',1,N'Goblin attacks a dwarf player character who is already a lawful combat target.',N'Use normal attack profile and applicable lighting; dwarf hatred does NOT add Hit or damage bonus.',N'{"attack_d20":12}',N'{"target_species":"Dwarf","racial_hit_bonus":0,"racial_damage_bonus":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C07',7,N'Ordinary HP uses 1d8-1, floor one',N'COMBAT_HANDOFF',N'Specified',1,N'Fixed roster HP dice faces are [6,6,2,4], one independent d8 per actor.',N'Combat receives HP [5,5,1,3], total 14; cannot reroll when attack begins.',N'{"hp_d8_faces":[6,6,2,4]}',N'{"hp_start":[5,5,1,3],"total_hp":14}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C08',8,N'HP minimum for one-die roll of one',N'COMBAT_HANDOFF',N'Specified',1,N'Synthetic Goblin has 1d8 face 1 under 1-1 HD.',N'Use minimum 1 HP rather than 0 or negative HP at encounter start.',N'{"hp_d8_faces":[1]}',N'{"expected_hp":1}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C09',9,N'AC 6 and Normal Man saving throw profile',N'COMBAT',N'Specified',1,N'An ordinary Goblin is instantiated with source stats.',N'Pass AC6 and Save As Normal Man; never use Fighter 1 or king attack profile for ordinary Goblin.',NULL,N'{"expected_armor_class":6,"save_as":"Normal Man"}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C10',10,N'Base Goblin morale 7 without king',N'COMBAT',N'Specified',1,N'Ordinary dungeon scene contains no king, and a normally required morale check occurs.',N'Use morale 7; no 9 leadership value, and no extra invented check.',N'{"morale_d6":[3,5]}',N'{"king_present":false,"morale":7}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C11',11,N'No built-in Hit or damage ability bonus',N'COMBAT',N'Specified',1,N'Ordinary Goblin successfully hits with mace, at night.',N'Apply weapon damage only and source modifiers actually in effect; no bonus from Goblin strength, rage or hostile intent.',N'{"attack_d20":16,"mace_damage_d6":4}',N'{"expected_innate_damage_bonus":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C12',12,N'Short bow uses weapon missile rules',N'COMBAT',N'Specified',1,N'GOB-T001-3 carries Short Bow, arrows and no melee weapon equipped.',N'Use generic missile attack/cover/range/arrow damage as defined by Mentzer weapons. No automatic melee bow attack or extra species modifier.',N'{"attack_d20":17,"arrow_d6":3}',N'{"weapon":"Short Bow","ammo":"arrow","lighting":"torchlight","exact_range_to_supply_when_executing":true}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C13',13,N'Single weapon action, no free missile-and-melee',N'COMBAT',N'Specified',1,N'A Goblin with spear or short bow has already used its weapon attack during this combat round.',N'Do not grant a second species attack or automatic second swing.',NULL,N'{"attacks_per_round":1}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C14',14,N'Attack misses cause no damage rolls',N'COMBAT',N'Specified',1,N'An ordinary Goblin misses its legal target with sword.',N'No damage applied and no extra effect created by its weapon or ancestry.',N'{"attack_d20":1}',N'{"expected_hp_damage":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-C15',15,N'Ordinary goblins do not gain royal daylight exemption',N'COMBAT',N'Specified',1,N'King absent; Goblin has role ordinary during synthetic full-daylight test.',N'Apply -1 Hit. Royal exemption is explicitly tied to king/bodyguard roles, not proximity to royalty.',N'{"attack_d20":12}',N'{"role":"ordinary","full_daylight":true,"expected_daylight_hit_modifier":-1}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E01',16,N'One ordinary encounter uses source 2-8 range',N'ENCOUNTER',N'Specified',1,N'Roll 1d8, reroll 1 as fixture method. Recorded raw face 4.',N'Number Appearing is four ordinary Goblins; do not use B1 stocked 1-8 or predefined HP.',N'{"count_d8_faces":[4]}',N'{"source_range":[2,8],"result":4,"method":"1d8 reroll 1"}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E02',17,N'Surprise uses one d6 per side',N'ENCOUNTER',N'Specified',1,N'Party rolls 6 and Goblin side rolls 3.',N'Neither side is surprised; do not roll once per individual Goblin.',N'{"party_1d6":6,"goblin_side_1d6":3}',N'{"surprised_on":[1,2],"party_surprised":false,"goblins_surprised":false}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E03',18,N'Dungeon default is no wolf mounts',N'ENCOUNTER',N'Specified',1,N'Four ordinary Goblins are encountered indoors in dungeon passage.',N'No Dire Wolf mount or mounted Goblin is spawned; source 20 percent rule is outdoors only.',NULL,N'{"outdoors":false,"mounted_goblins":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E04',19,N'No king or bodyguards in ordinary encounter',N'ENCOUNTER',N'Specified',1,N'Standard non-lair dungeon fixture; no lair composition requested.',N'Use four ordinary Goblins only, and morale 7; no fixed king HP, royal bodyguards, or leadership aura.',NULL,N'{"dungeon_lair":false,"king_present":false,"bodyguards":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E05',20,N'Infravision is 90-foot encounter capability',N'ENCOUNTER',N'Specified',1,N'Goblin in darkness has an unobstructed candidate target at 80 feet.',N'Encounter/Geometry may use source 90-foot infravision subject to scene visibility; do not convert infravision directly into Hit bonus or guaranteed surprise.',NULL,N'{"vision_range_ft":90,"distance_ft":80}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E06',21,N'Dwarf hostility belongs to Encounter',N'ENCOUNTER',N'Specified',1,N'A Goblin recognizes a dwarf and the party has not yet entered melee.',N'Model strong attack-on-sight intent while still resolving distance, reaction timing and player opportunity under normal encounter rules; no free pre-combat Hit bonus.',NULL,N'{"target_species":"Dwarf","combat_modifier":0}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E07',22,N'Four actor weapons stay in encounter roster',N'ENCOUNTER',N'Specified',1,N'Create four ordinary Goblins with source 1-1 HD and approved fixture loadout.',N'Preserve per-actor Sword, Spear, Short Bow, Mace in the Encounter-to-Combat handoff; never overwrite them with species default equipment.',NULL,N'{"weapons":["Sword (normal)","Spear","Short Bow","Mace"]}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E08',23,N'Descriptive dimensions are not attack reach',N'ENCOUNTER',N'Specified',1,N'Species D1=5, D2=5, Z=4 physical metadata is loaded by future Geometry.',N'Treat as approved modelling estimate, not automatic 5ft reach, collision or surprise modifier.',NULL,N'{"D1Feet":5,"D2Feet":5,"ZFeet":4,"source":"owner estimated"}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-E09',24,N'No forced combat from aggressive artwork',N'ENCOUNTER',N'Specified',1,N'Narrative/illustration depicts armed Goblins and the party might retreat or parley.',N'DM can present threat, combat intent or avoidance without using artwork as a compulsory initiative event.',NULL,N'{"illustration_is_nonauthoritative":true}',N'AIDM-DES-001.7',NULL,NULL),
 (N'GOBLIN-T001',N'GOB-L01',25,N'Outdoor 20 percent mounted riders',N'DEFERRED_LIFECYCLE',N'Deferred',1,N'Future encounter takes place outdoors, with source 20 percent chance of Dire Wolf rider per four Goblins.',N'Encounter must apply the source outdoor-only chance without inventing mounted combat, mount stats or rider position before Dire Wolf/riding integration.',N'{"chance_d100":17}',N'{"outdoors":true,"percentage":20,"rider_ratio":"1 in every 4"}',N'AIDM-DES-001.7',NULL,N'Future Encounter/Geometry/mount integration; NO lair/mounted fixture in S16.'),
 (N'GOBLIN-T001',N'GOB-L02',26,N'King and bodyguard role mechanics deferred',N'DEFERRED_LIFECYCLE',N'Deferred',1,N'Future independent goblin lair has Goblin king and 2-12 bodyguards.',N'Use documented king HP15/attack-as-3HD/damage+1; bodyguards HP2-12/attack-as-2HD; royal daylight exemptions; morale 9 iff king alive and with group. Do not execute in ordinary T001.',NULL,N'{"king_hp":15,"king_attack_as_hd":3,"king_damage_bonus":1,"bodyguard_count":"2-12","bodyguard_hp":"2-12","bodyguard_attack_as_hd":2,"with_king_morale":9,"base_morale":7}',N'AIDM-DES-001.7',NULL,N'Not a S16 lair encounter; king/bodyguard feature documentation remains in species Combat column.'),
 (N'GOBLIN-T001',N'GOB-L03',27,N'Illumination boundary at daylight transition',N'DEFERRED_LIFECYCLE',N'Deferred',1,N'Unknown illumination: mixed outdoor shade or magical sunlight rather than full daylight.',N'Do not invent new lighting thresholds or daylight equivalence; refer uncertain case to Rules adjudication while applying -1 whenever FULL daylight is established.',NULL,N'{"source_condition":"full daylight"}',N'AIDM-DES-001.7',NULL,N'Light transition semantics require future Encounter/Geometry/Rules design.');
 INSERT INTO [Test].[MonsterTestCase] ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],[TestStatus],[TestRevision],[GivenText],[ExpectedText],[DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
 SELECT s.[ScenarioCode],s.[TestCaseCode],s.[SequenceNo],s.[TestName],s.[TestPhase],s.[TestStatus],s.[TestRevision],s.[GivenText],s.[ExpectedText],s.[DiceFixtureJson],s.[AdditionalDataJson],s.[LinkedStoryRef],s.[AutomatedTestRef],s.[Notes] FROM @Seed AS s
 WHERE NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] AS e WITH (UPDLOCK,HOLDLOCK)
                   WHERE e.[ScenarioCode]=s.[ScenarioCode] AND e.[TestCaseCode]=s.[TestCaseCode]);
 PRINT CONCAT(N'New Goblin test definitions inserted: ',@@ROWCOUNT);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[TestPhase],[TestStatus],COUNT(*) AS [TestCount]
FROM [Test].[MonsterTestCase] WHERE [ScenarioCode]=N'GOBLIN-T001'
GROUP BY [ScenarioCode],[TestPhase],[TestStatus]
ORDER BY [ScenarioCode],[TestPhase],[TestStatus];
GO