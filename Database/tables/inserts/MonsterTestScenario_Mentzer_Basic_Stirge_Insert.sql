/*
Golden Braid / AIDM
File: Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Stirge_Insert.sql
Target: DnD.[Test].[MonsterTestScenario]
Source: 1983 Mentzer Basic DM Rulebook Stirge printed p38.
Nine Stirges: COUNT 1d10 [9]=9; each HP 1d8 [3,4,8,7,8,8,6,2,8].
Surprise party d6=[2] (surprised), Stirges d6=[5] (not surprised).
These are actual independent saved rolls, NOT a curated six-Stirge count.
B1 S11 is ONLY species selection. One row per encounter.
All tests Specified, not ready; creature art is species-only, not exact nine.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
 THROW 56710,'Test.MonsterTestScenario missing',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @Seed TABLE
 (
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
 INSERT INTO @Seed ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 VALUES
 (N'STIRGE-T001',
  N'Nine Stirges — diving attacks, attachment and blood draining',
  N'MentzerBECMI',
  N'STIRGE',
  1,
  N'Specified',
  0,
  N'1983 Mentzer Basic Dungeon Masters Rulebook, Stirge p.38; original fair 1d10/1d8/1d6 fixture rolls on 2026-11-21; AIDM-DES-001.7 S11.',
  9,
  N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve approved current canonical attributes at Encounter bootstrap; never invent party HP or species."},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve approved current canonical attributes at Encounter bootstrap; never invent party HP or species."},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve approved current canonical attributes at Encounter bootstrap; never invent party HP or species."},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve approved current canonical attributes at Encounter bootstrap; never invent party HP or species."}]',
  N'[{"actor_id":"STIRGE-1","species":"STIRGE","role":"ordinary","hp_start":3,"max_hp":3,"hp_dice":{"expression":"1d8","faces":[3],"total":3},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-2","species":"STIRGE","role":"ordinary","hp_start":4,"max_hp":4,"hp_dice":{"expression":"1d8","faces":[4],"total":4},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-3","species":"STIRGE","role":"ordinary","hp_start":8,"max_hp":8,"hp_dice":{"expression":"1d8","faces":[8],"total":8},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-4","species":"STIRGE","role":"ordinary","hp_start":7,"max_hp":7,"hp_dice":{"expression":"1d8","faces":[7],"total":7},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-5","species":"STIRGE","role":"ordinary","hp_start":8,"max_hp":8,"hp_dice":{"expression":"1d8","faces":[8],"total":8},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-6","species":"STIRGE","role":"ordinary","hp_start":8,"max_hp":8,"hp_dice":{"expression":"1d8","faces":[8],"total":8},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-7","species":"STIRGE","role":"ordinary","hp_start":6,"max_hp":6,"hp_dice":{"expression":"1d8","faces":[6],"total":6},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-8","species":"STIRGE","role":"ordinary","hp_start":2,"max_hp":2,"hp_dice":{"expression":"1d8","faces":[2],"total":2},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null},{"actor_id":"STIRGE-9","species":"STIRGE","role":"ordinary","hp_start":8,"max_hp":8,"hp_dice":{"expression":"1d8","faces":[8],"total":8},"armor_class":7,"hit_dice":"1*","save_as":"Fighter 2","morale":9,"ground_ft_round":10,"flight_ft_round":60,"attack":"beak 1d3; on successful hit attach; then 1d3 automatic drain per round","attached_to":null}]',
  N'{"expression":"1d10","faces":[9],"result":9,"range":[1,10],"roll_method":"independent fair die via secure random sampling at fixture creation","source":"Mentzer Basic Stirge number appearing; NOT B1 module monster count"}',
  N'{"phase":"ENCOUNTER","party":{"expression":"1d6","faces":[2],"surprised_on":[1,2],"is_surprised":true},"monsters":{"expression":"1d6","faces":[5],"surprised_on":[1,2],"is_surprised":false},"result":"party surprised; nine stirges not surprised; ordinary surprise round before normal initiative","modifier":"NO special Stirge surprise rule"}',
  N'{"environment":"torchlit stone dungeon passage with high ceiling; flying stirges approach from overhead","origin":"synthetic neutral test scene; B1 S11 only selects species","flight_available":true,"altitude":"not numerically established: require explicit future Geometry fixture","attachment_model":"source actor Stirge ID -> victim actor ID; one independent edge per Stirge; multiple attached attackers may share a victim","initial_attached_actor_ids":[],"first_flying_attack":"plus 2 Hit modifier only when qualified as first flying Hit Roll against an opponent; modifier not damage","target_switch_scope":"exact source wording retained; novel requalification against a different opponent requires BON adjudication, not an automatic reset","saving_throw":"NONE for attachment or blood drain","behaviour":"birdlike blood feeders; may descend, attach and drink; players may flee or attempt removal","detachment":"source specifies no special remove check or voluntary end; discretionary ruling deferred","player_stat_source":"canonical character records only","termination":"stop draining if Stirge dead; other termination handling source-checked as undecided"}',
  N'{"phase":"ENCOUNTER_TO_COMBAT","species":"STIRGE","count":9,"starting_hp":[3,4,8,7,8,8,6,2,8],"total_hp":54,"surprise":{"party":true,"monsters":false},"attack_bonus_first_flying_hit":2,"attachment":"per-Stirge immutable ID linked to actual victim; ongoing 1d3 drain/round no Hit roll","combat_database_access":false,"source_reference":"Rules.Monster version-specific snapshot"}',
  NULL,
  N'ACTUAL rolls: 1d10=[9] -> nine Stirges; nine independent 1d8=[3,4,8,7,8,8,6,2,8] => total54 HP; side surprise 1d6 party=[2], Stirges=[5]. Ordinary rule party surprised, Stirges not. Species art depicts a few Stirges and is not used as exact nine-Stirge encounter illustration. Current character attributes loaded from canonical party. No B1-specific HP/count. Test scenario Specified/ReadyForExecution=0, not run or UAT passed.');
 INSERT INTO [Test].[MonsterTestScenario]
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 SELECT s.[ScenarioCode], s.[ScenarioName], s.[RulesetCode], s.[PrimaryMonsterCode], s.[FixtureRevision], s.[ScenarioStatus], s.[ReadyForExecution], s.[OriginReference], s.[MonsterCount], s.[PartyRosterJson], s.[MonsterRosterJson], s.[CountRollJson], s.[SurpriseJson], s.[SceneFactsJson], s.[ExpectedHandoffJson], s.[IllustrationPath], s.[Notes]
 FROM @Seed AS s
 WHERE NOT EXISTS
 (
  SELECT 1 FROM [Test].[MonsterTestScenario] AS existing WITH (UPDLOCK,HOLDLOCK)
  WHERE existing.[ScenarioCode]=s.[ScenarioCode]
 );
 DECLARE @Inserted INT=@@ROWCOUNT;
 COMMIT;
 PRINT CONCAT(N'Inserted ',@Inserted,N' Stirge scenario(s) as Specified.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],
       [ReadyForExecution],[CountRollJson],[MonsterRosterJson],[SurpriseJson]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode]=N'STIRGE-T001';
GO
