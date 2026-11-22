/* Golden Braid AIDM B1 S18 Zombie — test scenario
FILE: MonsterTestScenario_Mentzer_Basic_Zombie_Insert.sql
TARGET: DnD.[Test].[MonsterTestScenario] (PEQUOD SQL Server 2016+)
SOURCE: 1983 Mentzer Basic Dungeon Masters Rulebook, Zombie printed p.39.
B1 stocklist selects species only; synthetic encounter is independent.
2026-11-22. Idempotent insert-only; Specified/SourceChecked NOT execution, approval or UAT.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL THROW 57181,'Test.MonsterTestScenario missing',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM [Test].[MonsterTestScenario] WITH(UPDLOCK,HOLDLOCK) WHERE [ScenarioCode]=N'ZOMBIE-T001')
 BEGIN
  INSERT INTO [Test].[MonsterTestScenario] ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],[FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],[MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
  VALUES (N'ZOMBIE-T001',N'The Silent Guardians (four Zombies, B1 S18 species)',N'MentzerBECMI',N'ZOMBIE',1,N'Specified',0,N'Mentzer Basic 1983 DM Rulebook Zombie p.39; B1 monster stocklist #18 selects species only; new synthetic encounter 2026-11-22.',4,N'[{"actor_id":"Alho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual player statistics; do not manufacture them"},{"actor_id":"Evro","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual player statistics; do not manufacture them"},{"actor_id":"Sho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual player statistics; do not manufacture them"},{"actor_id":"Ralt","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual player statistics; do not manufacture them"}]',N'[{"actor_id":"ZOM-T001-1","species":"ZOMBIE","role":"ordinary_guard","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[3,4],"result":7},"hp_start":7,"armor_class":8,"attack_as":"2 HD monster attack row","attacks_per_round":1,"attack_kind":"claw","weapon":null,"claw_damage":"1d8","standard_weapon_damage":null,"variable_weapon_damage":null,"save_as":"Fighter 1","morale":12,"delayed_initiative":true,"notes":"Equipment generated for scenario only; image is not rules authority"},{"actor_id":"ZOM-T001-2","species":"ZOMBIE","role":"ordinary_guard","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[3,5],"result":8},"hp_start":8,"armor_class":8,"attack_as":"2 HD monster attack row","attacks_per_round":1,"attack_kind":"claw","weapon":null,"claw_damage":"1d8","standard_weapon_damage":null,"variable_weapon_damage":null,"save_as":"Fighter 1","morale":12,"delayed_initiative":true,"notes":"Equipment generated for scenario only; image is not rules authority"},{"actor_id":"ZOM-T001-3","species":"ZOMBIE","role":"ordinary_guard","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[6,4],"result":10},"hp_start":10,"armor_class":8,"attack_as":"2 HD monster attack row","attacks_per_round":1,"attack_kind":"weapon","weapon":"Sword (normal)","claw_damage":"1d8","standard_weapon_damage":"1d6","variable_weapon_damage":"1d8","save_as":"Fighter 1","morale":12,"delayed_initiative":true,"notes":"Equipment generated for scenario only; image is not rules authority"},{"actor_id":"ZOM-T001-4","species":"ZOMBIE","role":"ordinary_guard","hit_dice":"2","hp_roll":{"expression":"2d8","faces":[5,4],"result":9},"hp_start":9,"armor_class":8,"attack_as":"2 HD monster attack row","attacks_per_round":1,"attack_kind":"weapon","weapon":"Sword (normal)","claw_damage":"1d8","standard_weapon_damage":"1d6","variable_weapon_damage":"1d8","save_as":"Fighter 1","morale":12,"delayed_initiative":true,"notes":"Equipment generated for scenario only; image is not rules authority"}]',N'{"published_range":"2-8 ordinary dungeon","synthetic_method":"uniform 1d8 reroll 1; distributions not specified by source","dice_faces":[4],"result":4}',N'{"party":{"expression":"1d6","faces":[5],"surprised_on":[1,2],"is_surprised":false},"zombies":{"expression":"1d6","faces":[4],"surprised_on":[1,2],"is_surprised":false},"one_roll_per_side":true,"notes":"Synthetic fixed surprise fixture, not a B1 scene roll"}',N'{"setting":"torchlit stone crypt with a coffer","dungeon_lair":false,"guarding_order":"Prevent intruders from approaching or taking the coffer","monster_count":4,"claw_zombies":2,"sword_zombies":2,"coffer_present":true,"coffer_contents":"not specified; not Zombie treasure","visual_reference":"approved illustration, not authoritative room geometry","no_disease_or_infection":true,"no_forced_attack_without_scene":true}',N'{"monster_hp":[7,8,10,9],"total_hp":34,"monster_code":"ZOMBIE","attack_patterns":["claw 1d8","claw 1d8","equipped sword by weapon","equipped sword by weapon"],"movement_turn_feet":90,"movement_round_feet":30,"actor_dimensions_ft":{"D1":5,"D2":5,"Z":6},"zombie_initiative_tier":"delayed","side_initiative_d6":true,"standard_initiative_first":true,"delayed_order":"winning side first; ties simultaneous","surprise_separate":true}',N'assets/monsters/AIDM_ZOMBIE_S18_Dungeon_Stock_Illustration.webp',N'One encounter, four independently generated 2HD zombies with 34 starting HP. Source-only monster count selection from B1; original B1 fixed data omitted. 14 COMBAT +6 ENCOUNTER specified tests and 1 DEFERRED_LIFECYCLE Turn Undead test. No tests executed. 6-ft human-scale height approved.');
  PRINT N'Inserted ZOMBIE-T001';
 END ELSE PRINT N'Existing ZOMBIE-T001 preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[MonsterCount],[ScenarioStatus],[ReadyForExecution],[IllustrationPath] FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode]=N'ZOMBIE-T001';
GO
