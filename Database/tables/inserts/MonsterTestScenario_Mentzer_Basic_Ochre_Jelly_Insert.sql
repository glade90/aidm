/* Golden Braid AIDM B1 S21 Ochre Jelly — test scenario
FILE: MonsterTestScenario_Mentzer_Basic_Ochre_Jelly_Insert.sql
TARGET: PEQUOD / DnD (SQL Server 2016+)
SOURCE: Mentzer Basic 1983 DM Rulebook, Ochre Jelly, printed p.35.
B1 S21 selects species only. The Seeping Passage is a separate synthetic fixture.
2026-11-22. Idempotent INSERT-ONLY; source-checked and specified != deployed or tested.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL THROW 57211,'Test.MonsterTestScenario missing',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM [Test].[MonsterTestScenario] WITH(UPDLOCK,HOLDLOCK) WHERE [ScenarioCode]=N'OCHRE_JELLY-T001')
 BEGIN
  INSERT INTO [Test].[MonsterTestScenario] ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],[FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],[MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
  VALUES (N'OCHRE_JELLY-T001',N'The Seeping Passage (one Ochre Jelly, B1 S21 species)',N'MentzerBECMI',N'OCHRE_JELLY',1,N'Specified',0,N'Mentzer Basic 1983 Dungeon Masters Rulebook, Ochre Jelly p.35; B1 stocklist #21 species selector, synthetic S21 fixture 2026-11-22.',1,N'[{"actor_id":"Alho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load real player stats; never fabricate"},{"actor_id":"Evro","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load real player stats; never fabricate"},{"actor_id":"Sho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load real player stats; never fabricate"},{"actor_id":"Ralt","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load real player stats; never fabricate"}]',N'[{"actor_id":"JEL-T001-1","species":"OCHRE_JELLY","hit_dice":"5*","hp_roll":{"expression":"5d8","faces":[5,4,6,3,5],"result":23},"hp_start":23,"armor_class":8,"attacks_per_round":1,"damage":"2d6","save_as":"Fighter 3","morale":12,"movement_turn_feet":30,"movement_round_feet":10,"split_generation":0,"notes":"One parent Jelly; test-specific child creation on valid attack only"}]',N'{"published_number_appearing":"1 (0)","fixture_count":1,"no_count_roll_required":true,"not_b1_stocked_hp":true}',NULL,N'{"setting":"damp stone gallery","masonry":"cracked stonework","observable_form":"yellow-brown mass near cracked masonry","light_conditions":"determined by actual party lighting; no automatic creature identification","player_options":["examine","probe","approach with a torch","pass around","withdraw"],"forced_action":false,"forced_combat":false,"forced_surprise":false,"scene_geometry_fixed":false,"source_seeping_capability":true,"rule_fire_cold_can_harm":true,"rule_weapon_lightning_split":true,"contact_effects_only_when_actual_contact":true,"non_combat_response_in_encounter_engine":true,"visual_reference":"approved colour illustration, not geometry or source rule authority"}',N'{"combat_only_if_encounter_escalates":true,"combatant_ids":["JEL-T001-1"],"starting_hp":[23],"armor_class":8,"hit_dice":"5*","attacks_per_round":1,"damage":"2d6","movement_turn_feet":30,"movement_round_feet":10,"validated_surprise_only":true,"initial_split_generation":0,"weapon_lightning_split_on_hit":true,"split_roll":"1d4+1","offspring_hit_dice":"2","offspring_hp_roll":"2d8 each","offspring_attack_damage":"half of normal 2d6","maximum_split_generation":1,"house_rule_overlay":true,"already_split_offspring_do_not_split":true,"no_bonus_actions_from_split":true,"no_encounter_logic_in_combat":true}',N'assets/monsters/AIDM_OCHRE_JELLY_S21_The_Seeping_Passage.webp',N'Exactly one synthetic 23-HP parent Jelly (5d8=5+4+6+3+5). Fixed successful sword-hit branch d4=2 means 3 children with independently rolled 2d8 HP 8, 10 and 6; they replace parent, do not get immediate bonus attacks, and cannot split again by the agreed one-generation house rule. This future Encounter scene does not force recognition, surprise, attack or combat. 12 Combat cases and 6 Encounter cases are specified but not run. Colour art upload outstanding.');
  PRINT N'Inserted OCHRE_JELLY-T001';
 END ELSE PRINT N'Existing OCHRE_JELLY-T001 preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[MonsterCount],[ScenarioStatus],[ReadyForExecution],[IllustrationPath] FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode]=N'OCHRE_JELLY-T001';
GO
