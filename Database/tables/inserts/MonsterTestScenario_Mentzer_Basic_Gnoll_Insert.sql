/*
===============================================================================
Golden Braid / AIDM — GNOLL-T001 original, individually rolled combat fixture
File: Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Gnoll_Insert.sql
Target: PEQUOD DnD.[Test].[MonsterTestScenario]
Source: Mentzer 1983 Basic Dungeon Masters Rulebook, Gnoll p.30
Die faces: count 1d6 [4] -> 4; individual HP 2d8 [1,4]=5,
           [8,6]=14, [8,1]=9, [4,6]=10 (total 38).
Surprise: party 1d6 [3], gnolls 1d6 [5]; neither surprised.
B1 S12 selects species ONLY. No B1 monster HP or encounter count imported.
The artwork depicts one representative Gnoll, not four; scenario art is NULL.
Specified only; requires approved weapons and character stats before execution.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
 THROW 56802,N'Test.MonsterTestScenario missing; install Test schema/table.',1;
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
 (N'GNOLL-T001',
  N'Four Gnolls — weapon damage +1, no leader',
  N'MentzerBECMI',
  N'GNOLL',
  1,
  N'Specified',
  0,
  N'Mentzer 1983 Basic Dungeon Masters Rulebook, Gnoll p.30; B1 S12 only selects the species; 2026-11-22 synthetic, fixed roll fixture.',
  4,
  N'[{"actor_id":"Alho","source":"existing canonical character","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load actual character attributes; none are invented by Gnoll fixture."},{"actor_id":"Evro","source":"existing canonical character","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load actual character attributes; none are invented by Gnoll fixture."},{"actor_id":"Sho","source":"existing canonical character","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load actual character attributes; none are invented by Gnoll fixture."},{"actor_id":"Ralt","source":"existing canonical character","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load actual character attributes; none are invented by Gnoll fixture."}]',
  N'[{"actor_id":"GNOLL-1","species":"GNOLL","role":"ordinary","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[1,4],"total":5},"hp_start":5,"max_hp":5,"armor_class":5,"attack_profile":"2 HD monster attack row","attacks":"one weapon attack","weapon_ref":null,"weapon_requirement":"Encounter must supply actual rules-validated equipment before live combat.","damage_rule":"by equipped weapon + 1 damage","save_as":"Fighter 2","morale":8},{"actor_id":"GNOLL-2","species":"GNOLL","role":"ordinary","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[8,6],"total":14},"hp_start":14,"max_hp":14,"armor_class":5,"attack_profile":"2 HD monster attack row","attacks":"one weapon attack","weapon_ref":null,"weapon_requirement":"Encounter must supply actual rules-validated equipment before live combat.","damage_rule":"by equipped weapon + 1 damage","save_as":"Fighter 2","morale":8},{"actor_id":"GNOLL-3","species":"GNOLL","role":"ordinary","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[8,1],"total":9},"hp_start":9,"max_hp":9,"armor_class":5,"attack_profile":"2 HD monster attack row","attacks":"one weapon attack","weapon_ref":null,"weapon_requirement":"Encounter must supply actual rules-validated equipment before live combat.","damage_rule":"by equipped weapon + 1 damage","save_as":"Fighter 2","morale":8},{"actor_id":"GNOLL-4","species":"GNOLL","role":"ordinary","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[4,6],"total":10},"hp_start":10,"max_hp":10,"armor_class":5,"attack_profile":"2 HD monster attack row","attacks":"one weapon attack","weapon_ref":null,"weapon_requirement":"Encounter must supply actual rules-validated equipment before live combat.","damage_rule":"by equipped weapon + 1 damage","save_as":"Fighter 2","morale":8}]',
  N'{"expression":"1d6","faces":[4],"result":4,"normal_range":[1,6],"provenance":"fixture roll recorded during user review; not B1 module encounter"}',
  N'{"phase":"ENCOUNTER","party":{"expression":"1d6","faces":[3],"is_surprised":false,"surprised_on":[1,2]},"monsters":{"expression":"1d6","faces":[5],"is_surprised":false,"surprised_on":[1,2]},"result":"Neither side surprised; normal initiative and no special Gnoll threshold"}',
  N'{"environment":"synthetic dungeon approach","source":"Mentzer species; scenario not taken from B1 room","encounter_type":"ordinary","leader_present":false,"leader_threshold_count":20,"opponents_visible":true,"weapons":"not prescribed by Mentzer; must resolve per actor through approved weapon data before executable","gnoll_behaviour":["threaten","steal","bully","extort","parley attempt","withdraw","attack"],"special_surprise":false,"geometry":"unestablished; avoid inventing distances","adventurers":"Alho Evro Sho Ralt from canonical party","special_modifier":"only weapon damage +1, not to Hit","original_image":"One representative Gnoll; cannot depict exactly four"}',
  N'{"phase":"ENCOUNTER_TO_COMBAT","species":"GNOLL","monster_count":4,"starting_hp":[5,14,9,10],"total_hp":38,"leader_count":0,"armor_class":5,"attack_profile":"2 HD","damage_modifier":1,"damage_modifier_applies_to":"weapon damage only","surprise":"none","requires_equipped_weapon_before_combat":true,"combat_performs_database_reads":false}',
  NULL,
  N'Four Gnolls: 1d6 count face 4. Individual 2d8 rolls GNOLL-1 [1,4]=5; GNOLL-2 [8,6]=14; GNOLL-3 [8,1]=9; GNOLL-4 [4,6]=10; total 38 HP. Normal surprise d6 party=3, gnolls=5; neither surprised. No leader, because count 4 not 20. Species artwork depicts one Gnoll and is linked through Rules.Monster; no exact-count scenario image. Equipment and character stats must be supplied from canonical/approved data, not guessed. Specified, ReadyForExecution=0, not run or UAT passed.');
 INSERT INTO [Test].[MonsterTestScenario]
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 SELECT s.[ScenarioCode], s.[ScenarioName], s.[RulesetCode], s.[PrimaryMonsterCode], s.[FixtureRevision], s.[ScenarioStatus], s.[ReadyForExecution], s.[OriginReference], s.[MonsterCount], s.[PartyRosterJson], s.[MonsterRosterJson], s.[CountRollJson], s.[SurpriseJson], s.[SceneFactsJson], s.[ExpectedHandoffJson], s.[IllustrationPath], s.[Notes]
 FROM @Seed AS s
 WHERE NOT EXISTS
 (
  SELECT 1 FROM [Test].[MonsterTestScenario] AS old WITH (UPDLOCK,HOLDLOCK)
  WHERE old.[ScenarioCode]=s.[ScenarioCode]
 );
 DECLARE @Inserted INT=@@ROWCOUNT;
 COMMIT;
 PRINT CONCAT(N'Inserted ',@Inserted,N' Gnoll scenario record(s); not executed.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],[ReadyForExecution],
       [CountRollJson],[MonsterRosterJson],[SurpriseJson],[IllustrationPath]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode]=N'GNOLL-T001';
GO
