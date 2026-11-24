/*
===============================================================================
Golden Braid / AIDM / B1 S16 — Goblin (1983 Mentzer Basic)
FILE: MonsterTestScenario_Mentzer_Basic_Goblin_Insert.sql
TARGET: DnD.[Test].[MonsterTestScenario] (PEQUOD, SQL Server 2016+)
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
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
 THROW 56941,'Test.MonsterTestScenario missing',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WITH (UPDLOCK,HOLDLOCK) WHERE [ScenarioCode]=N'GOBLIN-T001')
 BEGIN
  INSERT INTO [Test].[MonsterTestScenario] ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],[FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],[MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
  VALUES (N'GOBLIN-T001',N'Four ordinary Goblins in torchlit dungeon (B1 S16 species)',N'MentzerBECMI',N'GOBLIN',1,N'Specified',0,N'1983 Mentzer Basic DM Rulebook Goblin p.31; B1 monster stocklist entry #16 selects species only; new independent 2026-11-22 test fixture.',4,N'[{"actor_id":"Alho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load from actual party data; do not manufacture player statistics."},{"actor_id":"Evro","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load from actual party data; do not manufacture player statistics."},{"actor_id":"Sho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load from actual party data; do not manufacture player statistics."},{"actor_id":"Ralt","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load from actual party data; do not manufacture player statistics."}]',N'[{"actor_id":"GOB-T001-1","species":"GOBLIN","role":"ordinary","hit_dice":"1-1","hp_roll":{"expression":"1d8-1 (minimum 1)","faces":[6],"result":5},"hp_start":5,"armor_class":6,"attack_as":"up to 1 HD monster attack row","attacks_per_round":1,"weapon":"Sword (normal)","weapon_kind":"melee","variable_weapon_damage":"1d8","standard_weapon_damage":"1d6","weapon_requires_two_hands":false,"weapon_damage_modifier":0,"daylight_hit_modifier":-1,"morale":7,"saving_throws":"Normal Man","equipment_source":"synthetic encounter loadout, not species default"},{"actor_id":"GOB-T001-2","species":"GOBLIN","role":"ordinary","hit_dice":"1-1","hp_roll":{"expression":"1d8-1 (minimum 1)","faces":[6],"result":5},"hp_start":5,"armor_class":6,"attack_as":"up to 1 HD monster attack row","attacks_per_round":1,"weapon":"Spear","weapon_kind":"melee_or_thrown","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","weapon_requires_two_hands":false,"weapon_damage_modifier":0,"daylight_hit_modifier":-1,"morale":7,"saving_throws":"Normal Man","equipment_source":"synthetic encounter loadout, not species default"},{"actor_id":"GOB-T001-3","species":"GOBLIN","role":"ordinary","hit_dice":"1-1","hp_roll":{"expression":"1d8-1 (minimum 1)","faces":[2],"result":1},"hp_start":1,"armor_class":6,"attack_as":"up to 1 HD monster attack row","attacks_per_round":1,"weapon":"Short Bow","weapon_kind":"missile","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","weapon_requires_two_hands":true,"weapon_damage_modifier":0,"daylight_hit_modifier":-1,"morale":7,"saving_throws":"Normal Man","equipment_source":"synthetic encounter loadout, not species default"},{"actor_id":"GOB-T001-4","species":"GOBLIN","role":"ordinary","hit_dice":"1-1","hp_roll":{"expression":"1d8-1 (minimum 1)","faces":[4],"result":3},"hp_start":3,"armor_class":6,"attack_as":"up to 1 HD monster attack row","attacks_per_round":1,"weapon":"Mace","weapon_kind":"melee","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","weapon_requires_two_hands":false,"weapon_damage_modifier":0,"daylight_hit_modifier":-1,"morale":7,"saving_throws":"Normal Man","equipment_source":"synthetic encounter loadout, not species default"}]',N'{"published_range":"2-8 ordinary dungeon","synthetic_dice_method":"1d8, reroll result 1 to sample 2..8 uniformly; Mentzer does not specify the distribution method","dice_faces":[4],"result":4}',N'{"party":{"expression":"1d6","faces":[6],"surprised_on":[1,2],"is_surprised":false},"goblins":{"expression":"1d6","faces":[3],"surprised_on":[1,2],"is_surprised":false},"one_roll_per_side":true,"inherent_goblin_surprise_modifier":null}',N'{"setting":"ordinary underground stone dungeon with arched passage, dim torchlight, no natural daylight","dungeon_lair":false,"outdoors":false,"full_daylight":false,"artificial_lighting":"wall torches","light_within_vision":true,"dire_wolf_riders":0,"king_present":false,"bodyguards_present":false,"scene_directive":"Do not automatically force combat; let Encounter represent hostility, approach, player choices and standard surprise","visual_reference":"stock illustration; not authoritative scene geometry"}',N'{"combat_engine_receives":"authoritative species version + per-actor weapon/HP and contextual rule snapshot; Combat does not query SQL","ordinary_hit_roll_modifier_in_scene":0,"full_daylight_ordinary_goblin_hit_modifier":-1,"damage_modifier":0,"save_as":"Normal Man","base_morale":7,"weapon_choice":"per-actor encounter roster; no species default","canonical_weapon_table":"Mentzer Basic variable weapon damage where enabled","starting_hp":[5,5,1,3],"total_hp":14,"no_lair_variant":true}',N'assets/monsters/AIDM_GOBLIN_S16_Dungeon_Stock_Illustration.webp',N'Fixture uses synthetic fixed 1d8 reroll-1 count and independent Goblin HP and side surprise dice. Not B1 stocked HP/count. No king, bodyguards, outdoor wolves or daylight in scene. Full-daylight penalty is source-backed Combat rule tested with an injected independent light condition in test cases. No test execution recorded.');
  PRINT N'Inserted GOBLIN-T001 ordinary dungeon encounter';
 END
 ELSE PRINT N'Existing GOBLIN-T001 preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],[ReadyForExecution],[SurpriseJson],[IllustrationPath]
FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode]=N'GOBLIN-T001';
GO