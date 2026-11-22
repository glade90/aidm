/*
FILE: Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Shrieker_Insert.sql
Golden Braid / AIDM / AIDM-DES-001.7 / Shrieker S13
Mentzer 1983 Basic DM Rulebook, Shrieker printed p37.
SHRIEKER-T001: previously saved four Shrieker rolled fixture.
SHRIEKER-T002: independent one Shrieker movement-trigger fixture.
Source-checked Encounter/Expedition definitions only. No Combat-specific test.
All status Specified, ReadyForExecution=0; no execution or UAT claims.
Owner ruling one ALARM per group does not imply a cap on arriving groups.
Rerunnable; existing Test scenario rows are never overwritten.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
 THROW 56810,'Test.MonsterTestScenario missing',1;
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
 INSERT INTO @Seed
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 VALUES
 (N'SHRIEKER-T001',
  N'Four Shriekers - torchlight group alarm and delayed arrival',
  N'MentzerBECMI',
  N'SHRIEKER',
  1,
  N'Specified',
  0,
  N'Mentzer Basic 1983 Shrieker printed p37; BONNIE2 saved fair count, HP, surprise and alarm rolls.',
  4,
  N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"}]',
  N'[{"actor_id":"SHRIEKER-1","species":"SHRIEKER","hp_start":6,"max_hp":6,"hp_dice":{"expression":"3d8","faces":[1,2,3],"total":6},"armor_class":7,"hit_dice":"3","movement_ft_round":3,"attacks":"none; shriek in Encounter only","damage":"Nil"},{"actor_id":"SHRIEKER-2","species":"SHRIEKER","hp_start":6,"max_hp":6,"hp_dice":{"expression":"3d8","faces":[1,4,1],"total":6},"armor_class":7,"hit_dice":"3","movement_ft_round":3,"attacks":"none; shriek in Encounter only","damage":"Nil"},{"actor_id":"SHRIEKER-3","species":"SHRIEKER","hp_start":19,"max_hp":19,"hp_dice":{"expression":"3d8","faces":[7,7,5],"total":19},"armor_class":7,"hit_dice":"3","movement_ft_round":3,"attacks":"none; shriek in Encounter only","damage":"Nil"},{"actor_id":"SHRIEKER-4","species":"SHRIEKER","hp_start":15,"max_hp":15,"hp_dice":{"expression":"3d8","faces":[6,4,5],"total":15},"armor_class":7,"hit_dice":"3","movement_ft_round":3,"attacks":"none; shriek in Encounter only","damage":"Nil"}]',
  N'{"expression":"1d8","faces":[4],"result":4,"source":"Mentzer 1-8 in dungeon; no B1 stocked counts"}',
  N'{"phase":"ENCOUNTER","party":{"expression":"1d6","faces":[5],"surprised_on":[1,2],"is_surprised":false},"monsters":{"expression":"1d6","faces":[2],"surprised_on":[1,2],"is_surprised":true},"one_roll_per_side":true}',
  N'{"environment":"synthetic underground cavern, party carrying a torch","trigger_type":"light","trigger_distance_ft":50,"trigger_threshold_ft":60,"alarm_scope":"one alarm per simultaneously triggered Shrieker group","alarm_duration_rounds":2,"hearing_d6_by_round":[1,6],"arrival_delay_d6":[4,4],"arrives_rounds_after_success":8,"wandering_monster_identity":"unresolved until dungeon wandering-monster table supplied","wandering_monster_reaction":"not automatically hostile","multiple_successful_hearing_checks":"deferred","continuous_stimulus_retrigger":"deferred","on_death_alarm_interruption":"deferred"}',
  N'{"owner":"ENCOUNTER","time_and_scheduled_arrival":"EXPEDITION","combat":"generic incoming attacks only; no Shrieker attack","count":4,"hp":[6,6,19,15],"total_hp":46,"group_alarm_count":1,"hearing_rounds":[1,6],"positive_hearing_rounds":[2],"arrival_delay_rounds":8}',
  N'assets/monsters/AIDM_SHRIEKER_Species_Torchlit_Cavern_Illustration.webp',
  N'Previously rolled four-Shrieker fixture from BONNIE2, now captured as Specified and not executable. One group alarm is owner-approved; one responding group is NOT an approved limit.'),
 (N'SHRIEKER-T002',
  N'One Shrieker - movement-only dark passage alarm',
  N'MentzerBECMI',
  N'SHRIEKER',
  1,
  N'Specified',
  0,
  N'Mentzer Basic 1983 Shrieker printed p37; independently rolled synthetic movement-only fixture, 2026-11-22.',
  1,
  N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve from canonical record at Encounter bootstrap; do not invent stats"}]',
  N'[{"actor_id":"SHRIEKER-1","species":"SHRIEKER","hp_start":7,"max_hp":7,"hp_dice":{"expression":"3d8","faces":[3,2,2],"total":7},"armor_class":7,"hit_dice":"3","movement_ft_round":3,"attacks":"none; shriek in Encounter only","damage":"Nil"}]',
  N'{"expression":"1d8","faces":[1],"result":1,"source":"Mentzer 1-8 in dungeon; no B1 stocked counts"}',
  N'{"phase":"ENCOUNTER","party":{"expression":"1d6","faces":[2],"surprised_on":[1,2],"is_surprised":true},"monsters":{"expression":"1d6","faces":[1],"surprised_on":[1,2],"is_surprised":true},"one_roll_per_side":true}',
  N'{"environment":"synthetic unlit underground corridor; moving party; no light within 60 ft","trigger_type":"movement","trigger_distance_ft":25,"trigger_threshold_ft":30,"alarm_scope":"one alarm per simultaneously triggered Shrieker group","alarm_duration_rounds":2,"hearing_d6_by_round":[1,4],"arrival_delay_d6":[2,4],"arrives_rounds_after_success":6,"wandering_monster_identity":"unresolved until dungeon wandering-monster table supplied","wandering_monster_reaction":"not automatically hostile","multiple_successful_hearing_checks":"deferred","continuous_stimulus_retrigger":"deferred","on_death_alarm_interruption":"deferred"}',
  N'{"owner":"ENCOUNTER","time_and_scheduled_arrival":"EXPEDITION","combat":"generic incoming attacks only; no Shrieker attack","count":1,"hp":[7],"total_hp":7,"group_alarm_count":1,"hearing_rounds":[1,4],"positive_hearing_rounds":[2],"arrival_delay_rounds":6}',
  N'assets/monsters/AIDM_SHRIEKER_Species_Torchlit_Cavern_Illustration.webp',
  N'New independent roll: 1d8=1, HP 3d8=(3,2,2), party surprise=2, Shrieker surprise=1, 1d3 shriek=2, hearing 1,4 and delay 2d6=(2,4). Both surprised: timing implications deferred.');
 INSERT INTO [Test].[MonsterTestScenario]
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 SELECT s.[ScenarioCode], s.[ScenarioName], s.[RulesetCode], s.[PrimaryMonsterCode], s.[FixtureRevision], s.[ScenarioStatus], s.[ReadyForExecution], s.[OriginReference], s.[MonsterCount], s.[PartyRosterJson], s.[MonsterRosterJson], s.[CountRollJson], s.[SurpriseJson], s.[SceneFactsJson], s.[ExpectedHandoffJson], s.[IllustrationPath], s.[Notes]
 FROM @Seed s WHERE NOT EXISTS
 (SELECT 1 FROM [Test].[MonsterTestScenario] e WITH (UPDLOCK,HOLDLOCK)
  WHERE e.[ScenarioCode]=s.[ScenarioCode]);
 DECLARE @Inserted INT=@@ROWCOUNT;
 COMMIT;
 PRINT CONCAT('Inserted ',@Inserted,' Shrieker scenario definitions.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],[ReadyForExecution],[IllustrationPath]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode] IN (N'SHRIEKER-T001',N'SHRIEKER-T002')
ORDER BY [ScenarioCode];
GO
