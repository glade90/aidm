/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestScenario_Mentzer_Basic_Skeleton_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Skeleton_Insert.sql
Project         : Golden Braid / AIDM / B1 stocklist S14
Purpose         : Scenario SKELETON-T001; six independently rolled armed Skeletons.
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
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
 THROW 56910,'Test.MonsterTestScenario missing',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @Seed TABLE (
 [ScenarioCode] NVARCHAR(80) NOT NULL PRIMARY KEY,
 [ScenarioName] NVARCHAR(160) NOT NULL,
 [RulesetCode] NVARCHAR(80) NOT NULL,
 [PrimaryMonsterCode] NVARCHAR(80) NOT NULL,
 [FixtureRevision] INT NOT NULL,
 [ScenarioStatus] NVARCHAR(20) NOT NULL,
 [ReadyForExecution] BIT NOT NULL,
 [OriginReference] NVARCHAR(500) NOT NULL,
 [MonsterCount] INT NOT NULL,
 [PartyRosterJson] NVARCHAR(MAX) NOT NULL,
 [MonsterRosterJson] NVARCHAR(MAX) NOT NULL,
 [CountRollJson] NVARCHAR(MAX) NULL,
 [SurpriseJson] NVARCHAR(MAX) NULL,
 [SceneFactsJson] NVARCHAR(MAX) NOT NULL,
 [ExpectedHandoffJson] NVARCHAR(MAX) NULL,
 [IllustrationPath] NVARCHAR(500) NULL,
 [Notes] NVARCHAR(MAX) NULL
 );
 INSERT INTO @Seed
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 VALUES
 (N'SKELETON-T001',
  N'Six armed Skeletons with different Mentzer Basic weapons',
  N'MentzerBECMI',
  N'SKELETON',
  1,
  N'Specified',
  0,
  N'1983 Mentzer Basic DM Rulebook p.37, Players Manual pp.25,59-60; S14 approved synthetic count, individual HP and surprise fixtures on 2026-11-22.',
  6,
  N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"load canonical PC state at Encounter setup; no fictional party HP or spell/equipment inventory"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"load canonical PC state at Encounter setup; no fictional party HP or spell/equipment inventory"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"load canonical PC state at Encounter setup; no fictional party HP or spell/equipment inventory"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"load canonical PC state at Encounter setup; no fictional party HP or spell/equipment inventory"}]',
  N'[{"actor_id":"SKELETON-1","species":"SKELETON","role":"ordinary_undead","hp_start":6,"max_hp":6,"hp_dice":{"expression":"1d8","faces":[6],"total":6},"armor_class":7,"hit_dice":"1","save_as":"Fighter 1","morale":12,"movement_ft_turn":60,"movement_ft_round":20,"attacks_per_round":1,"weapon":{"name":"Sword (normal)","damage_variable":"1d8","damage_standard":"1d6","two_handed":false,"always_loses_individual_initiative":false},"shield_equipped":false,"undead":true,"can_be_turned":true},{"actor_id":"SKELETON-2","species":"SKELETON","role":"ordinary_undead","hp_start":5,"max_hp":5,"hp_dice":{"expression":"1d8","faces":[5],"total":5},"armor_class":7,"hit_dice":"1","save_as":"Fighter 1","morale":12,"movement_ft_turn":60,"movement_ft_round":20,"attacks_per_round":1,"weapon":{"name":"Mace","damage_variable":"1d6","damage_standard":"1d6","two_handed":false,"always_loses_individual_initiative":false},"shield_equipped":false,"undead":true,"can_be_turned":true},{"actor_id":"SKELETON-3","species":"SKELETON","role":"ordinary_undead","hp_start":3,"max_hp":3,"hp_dice":{"expression":"1d8","faces":[3],"total":3},"armor_class":7,"hit_dice":"1","save_as":"Fighter 1","morale":12,"movement_ft_turn":60,"movement_ft_round":20,"attacks_per_round":1,"weapon":{"name":"Battle Axe","damage_variable":"1d8","damage_standard":"1d6","two_handed":true,"always_loses_individual_initiative":true},"shield_equipped":false,"undead":true,"can_be_turned":true},{"actor_id":"SKELETON-4","species":"SKELETON","role":"ordinary_undead","hp_start":2,"max_hp":2,"hp_dice":{"expression":"1d8","faces":[2],"total":2},"armor_class":7,"hit_dice":"1","save_as":"Fighter 1","morale":12,"movement_ft_turn":60,"movement_ft_round":20,"attacks_per_round":1,"weapon":{"name":"Spear","damage_variable":"1d6","damage_standard":"1d6","two_handed":false,"always_loses_individual_initiative":false},"shield_equipped":false,"undead":true,"can_be_turned":true},{"actor_id":"SKELETON-5","species":"SKELETON","role":"ordinary_undead","hp_start":4,"max_hp":4,"hp_dice":{"expression":"1d8","faces":[4],"total":4},"armor_class":7,"hit_dice":"1","save_as":"Fighter 1","morale":12,"movement_ft_turn":60,"movement_ft_round":20,"attacks_per_round":1,"weapon":{"name":"Club","damage_variable":"1d4","damage_standard":"1d6","two_handed":false,"always_loses_individual_initiative":false},"shield_equipped":false,"undead":true,"can_be_turned":true},{"actor_id":"SKELETON-6","species":"SKELETON","role":"ordinary_undead","hp_start":7,"max_hp":7,"hp_dice":{"expression":"1d8","faces":[7],"total":7},"armor_class":7,"hit_dice":"1","save_as":"Fighter 1","morale":12,"movement_ft_turn":60,"movement_ft_round":20,"attacks_per_round":1,"weapon":{"name":"Pole Arm","damage_variable":"1d10","damage_standard":"1d6","two_handed":true,"always_loses_individual_initiative":true},"shield_equipped":false,"undead":true,"can_be_turned":true}]',
  N'{"expression":"3d4","faces":[1,3,2],"total":6,"range":[3,12],"source":"Mentzer Skeleton dungeon number appearing; independently recorded synthetic die faces, NOT B1 stock"}',
  N'{"phase":"ENCOUNTER","party":{"expression":"1d6","faces":[2],"is_surprised":true,"surprised_on":[1,2]},"monsters":{"expression":"1d6","faces":[3],"is_surprised":false,"surprised_on":[1,2]},"single_roll_per_side":true}',
  N'{"environment":"synthetic abandoned stone crypt, torchlight and ruined guard chamber, not a B1 module room","initial_skeleton_stance":"six armed undead guards between the party and passage; no automatic surprise or attack beyond rolled encounter and scenario rules","guard_instruction":"stand guard and repel intruders; whether parley or immediate hostility is possible depends on DM scene","weapon_damage_option":"Mentzer optional Variable Weapon Damage: ON for this fixture; when OFF, all six use 1d6 standard damage","equipment_by_actor":{"SKELETON-1":"Sword (normal)","SKELETON-2":"Mace","SKELETON-3":"Battle Axe","SKELETON-4":"Spear","SKELETON-5":"Club","SKELETON-6":"Pole Arm"},"undead_rules":"Sleep/Charm/mind-reading immunity; Holy Water 1d8 on success; cleric Turning per existing AIDM-DES-001.7.10","unknowns":"No rapier in Mentzer Basic; no blunt-weapon special damage specified; no skeleton-only undead code","geometry":"positioning and cover supplied by future Encounter/Geometry, not invented from picture","player_stats":"canonical records only"}',
  N'{"phase":"ENCOUNTER_TO_COMBAT","species":"SKELETON","count":6,"starting_hp":[6,5,3,2,4,7],"total_hp":27,"skeleton_actors":["SKELETON-1","SKELETON-2","SKELETON-3","SKELETON-4","SKELETON-5","SKELETON-6"],"surprise":{"party":true,"monsters":false},"attacks_per_round_per_skeleton":1,"variable_weapon_damage_enabled":true,"two_handed_ids":["SKELETON-3","SKELETON-6"],"turning_mechanic":"existing shared AIDM-DES-001.7.10","combat_database_access":false}',
  N'assets/monsters/AIDM_SKELETON-T001_Six_Skeletons_Mentzer_Weapons.webp',
  N'S14 synthetic Encounter fixture (not B1 stock count/HP). 3d4=[1,3,2] gives six Skeletons; 1d8 HP=[6,5,3,2,4,7] total 27. Surprise party d6=2, skeleton side d6=3. One weapon each: Sword(normal), Mace, Battle Axe, Spear, Club, Pole Arm. Under optional variable damage, respectively d8,d6,d8,d6,d4,d10. Two-handed Battle Axe and Pole Arm disallow shield and force those wielders to lose initiative. Turning delegated to existing AIDM-DES-001.7.10. Specified/Not Ready, no UAT/execution.');
 INSERT INTO [Test].[MonsterTestScenario]
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 SELECT s.[ScenarioCode], s.[ScenarioName], s.[RulesetCode], s.[PrimaryMonsterCode], s.[FixtureRevision], s.[ScenarioStatus], s.[ReadyForExecution], s.[OriginReference], s.[MonsterCount], s.[PartyRosterJson], s.[MonsterRosterJson], s.[CountRollJson], s.[SurpriseJson], s.[SceneFactsJson], s.[ExpectedHandoffJson], s.[IllustrationPath], s.[Notes]
 FROM @Seed AS s
 WHERE NOT EXISTS (
  SELECT 1 FROM [Test].[MonsterTestScenario] AS existing WITH (UPDLOCK,HOLDLOCK)
  WHERE existing.[ScenarioCode]=s.[ScenarioCode]
 );
 DECLARE @Inserted INT=@@ROWCOUNT;
 COMMIT;
 PRINT CONCAT(N'Inserted ',@Inserted,N' Skeleton scenario(s) as Specified/Not Ready.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],
       [ReadyForExecution],[CountRollJson],[SurpriseJson],[IllustrationPath]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode]=N'SKELETON-T001';
GO