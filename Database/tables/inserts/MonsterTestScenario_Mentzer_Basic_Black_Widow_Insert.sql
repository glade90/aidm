/* Golden Braid / AIDM — Black Widow Spider fixed encounter
Target: DnD.[Test].[MonsterTestScenario]; one row per encounter.
B1 S10 selects species only; test counts, HP and surprise are synthetic.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
 THROW 56675,'Test.MonsterTestScenario table missing',1;
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
 (N'WIDOW-T001',
  N'Two Black Widows — webbed lair, poison and escape',
  N'MentzerBECMI',
  N'GIANT_BLACK_WIDOW_SPIDER',
  1,
  N'Specified',
  0,
  N'1983 Mentzer Basic DM Rulebook Giant Spider/Black Widow p37; Players Manual Web spell; B1 S10 species selection only.',
  2,
  N'[{"actor_id":"Alho","source":"canonical existing party character","hp_start":null,"armor_class":null,"strength":null,"notes":"Resolve stats and Strength from canonical character record at test bootstrap"},{"actor_id":"Evro","source":"canonical existing party character","hp_start":null,"armor_class":null,"strength":null,"notes":"Resolve stats and Strength from canonical character record at test bootstrap"},{"actor_id":"Sho","source":"canonical existing party character","hp_start":null,"armor_class":null,"strength":null,"notes":"Resolve stats and Strength from canonical character record at test bootstrap"},{"actor_id":"Ralt","source":"canonical existing party character","hp_start":null,"armor_class":null,"strength":null,"notes":"Resolve stats and Strength from canonical character record at test bootstrap"}]',
  N'[{"actor_id":"WIDOW-1","hp_start":15,"hp_faces":[6,5,4],"species":"GIANT_BLACK_WIDOW_SPIDER","armor_class":6,"hit_dice":"3*","attacks":"1 bite","damage":"2d6 plus Poison save","morale":8,"save_as":"Fighter 2"},{"actor_id":"WIDOW-2","hp_start":13,"hp_faces":[2,7,4],"species":"GIANT_BLACK_WIDOW_SPIDER","armor_class":6,"hit_dice":"3*","attacks":"1 bite","damage":"2d6 plus Poison save","morale":8,"save_as":"Fighter 2"}]',
  N'{"expression":"1d3","faces":[2],"result":2,"synthetic_fixture":true}',
  N'{"phase":"ENCOUNTER","party":{"d6":5,"surprised_on":[1,2],"is_surprised":false},"monsters":{"d6":4,"surprised_on":[1,2],"is_surprised":false},"result":"neither side surprised; normal 1-2 per side"}',
  N'{"environment":"webbed underground lair, dark stone chamber","webs":{"source":"natural","preexisting":true,"spider_movement_round_ft":40,"spider_normal_movement_round_ft":20,"entrapment":"explicit precombat scene fact or verified contact, NOT every bite","condition":"WEB_ENTANGLED","escape":"Mentzer Web spell break-free rules","flammable":true,"fire_damage_and_timing":"NOT automatically imported from magical spell; later approved adjudication"},"branches":["party not web-entangled","party member explicitly web-entangled"],"poison":{"on_hit":"2d6 bite damage + Save vs Poison","failed_save":"POISONED with death due one dungeon turn","bonus_to_save":0},"behaviour":"predator; often avoids fire","no_special_surprise":true,"player_choices":["fight","escape","burn webs","stand off","withdraw"]}',
  N'{"monster_count":2,"starting_hp":[15,13],"surprise":"neither","web_state":"explicit scenario branch, not automatically inferred","combat_queries_database":false,"versioned_source":"Rules.Monster"}',
  NULL,
  N'WIDOW-1 3d8=[6,5,4] HP15; WIDOW-2 3d8=[2,7,4] HP13; 1d3=2 appearing. Source has no special surprise. Scene contains two alternative web exposure branches; player canonical statistics are not fabricated. Generated illustration depicts one spider, so no two-spider scenario illustration is assigned. Specified only, UAT not complete.');
 INSERT INTO [Test].[MonsterTestScenario]
 ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
 SELECT s.[ScenarioCode], s.[ScenarioName], s.[RulesetCode], s.[PrimaryMonsterCode], s.[FixtureRevision], s.[ScenarioStatus], s.[ReadyForExecution], s.[OriginReference], s.[MonsterCount], s.[PartyRosterJson], s.[MonsterRosterJson], s.[CountRollJson], s.[SurpriseJson], s.[SceneFactsJson], s.[ExpectedHandoffJson], s.[IllustrationPath], s.[Notes]
 FROM @Seed s
 WHERE NOT EXISTS
 (
  SELECT 1 FROM [Test].[MonsterTestScenario] t WITH (UPDLOCK,HOLDLOCK)
  WHERE t.[ScenarioCode]=s.[ScenarioCode]
 );
 DECLARE @Inserted INT=@@ROWCOUNT;
 COMMIT;
 PRINT CONCAT(N'Inserted ',@Inserted,N' Black Widow scenario.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ReadyForExecution],
 [MonsterRosterJson],[SurpriseJson] FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode]=N'WIDOW-T001';
GO
