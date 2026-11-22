/*
Golden Braid / AIDM / B1 S15 — Hobgoblin
File: MonsterTestScenario_Mentzer_Basic_Hobgoblin_Insert.sql
Table: DnD.[Test].[MonsterTestScenario]
Source: Mentzer 1983 Basic Dungeon Masters Rulebook, Hobgoblin, printed p.31; B1 #15 selects species only.
Boundaries: Mentzer species/rolls, NOT B1 fixed counts/HP.
Fixtures: HOBGOBLIN-T001 and HOBGOBLIN-T002. 2 seed rows. One row per encounter, JSON fixture only; existing rows preserved.
SourceChecked, inactive species; test definitions are Specified, NOT executed.
Reruns preserve existing species/fixtures; no silent rewriting of records.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL THROW 56925,'Test.MonsterTestScenario missing',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @Seed TABLE (
    [ScenarioCode] NVARCHAR(80) NOT NULL,
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
 INSERT INTO @Seed ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],[FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],[MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes]) VALUES
 (
  N'HOBGOBLIN-T001',
  N'Four Hobgoblins on a daylight patrol',
  N'MentzerBECMI',
  N'HOBGOBLIN',
  1,
  N'Specified',
  0,
  N'Mentzer 1983 Basic Dungeon Masters Rulebook, Hobgoblin, printed p.31; B1 #15 selects species only. Independently chosen fixture count/HP/surprise, 2026-11-22.',
  4,
  N'[{"actor_id":"Alho","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"},{"actor_id":"Evro","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"},{"actor_id":"Sho","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"},{"actor_id":"Ralt","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"}]',
  N'[{"actor_id":"HOB-T001-1","species":"HOBGOBLIN","role":"ordinary","hp_start":2,"hp_roll_faces":[1],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Sword (normal)","variable_weapon_damage":"1d8","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T001-2","species":"HOBGOBLIN","role":"ordinary","hp_start":2,"hp_roll_faces":[1],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Spear","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T001-3","species":"HOBGOBLIN","role":"ordinary","hp_start":7,"hp_roll_faces":[6],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Mace","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T001-4","species":"HOBGOBLIN","role":"ordinary","hp_start":4,"hp_roll_faces":[3],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Hand axe","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10}]',
  N'{"source":"Mentzer 1-6 ordinary","expression":"1d6","faces":[4],"result":4}',
  N'{"party":{"1d6":1,"surprised_on":[1,2],"surprised":true},"hobgoblins":{"1d6":6,"surprised_on":[1,2],"surprised":false},"one_roll_per_side":true}',
  N'{"location":"daylight exterior path near ruins; ordinary patrol","daylight":true,"king_present":false,"king_alive":false,"ordinary_morale":8,"weapons_assigned_per_actor":true,"no_daylight_penalty":true}',
  N'{"ordinary_actor_count":4,"total_hp":15,"surprise_party":true,"surprise_monsters":false,"combat_weapon_attacks_per_actor":1,"morale":8}',
  N'assets/monsters/AIDM_HOBGOBLIN_S15_Stock_Illustration.webp',
  N'Mentzer B1 #15 is selection only; do not use B1 preassigned Hobgoblin HP, quantity or equipment. Uses four independently recorded d8+1 rolls (1,1,6,3) and standard 1d6-side surprise 1 and 6. Scenario specified, not test result.'
 ),
 (
  N'HOBGOBLIN-T002',
  N'Royal lair with king, two guards and fifteen followers',
  N'MentzerBECMI',
  N'HOBGOBLIN',
  1,
  N'Specified',
  0,
  N'Mentzer 1983 Basic Dungeon Masters Rulebook, Hobgoblin, printed p.31; B1 #15 selects species only. Synthetic lair roster, previously reported fixture rolls, 2026-11-22.',
  18,
  N'[{"actor_id":"Alho","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"},{"actor_id":"Evro","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"},{"actor_id":"Sho","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"},{"actor_id":"Ralt","source":"authoritative fixture/canonical party loader","hp_start":null,"armor_class":null,"note":"Do not invent or import B1 pre-stocked party statistics"}]',
  N'[{"actor_id":"HOB-KING","species":"HOBGOBLIN","role":"king","hp_start":22,"hp_roll_faces":null,"hp_roll_notation":"fixed 22 HP","armor_class":6,"attacks_per_round":1,"attack_as":"5 HD","weapon":"Sword (normal)","variable_weapon_damage":"1d8","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":2,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-GUARD-1","species":"HOBGOBLIN","role":"bodyguard","hp_start":11,"hp_roll_faces":[2,5,4],"hp_roll_notation":"3d6 fixture for stated 3-18 HP","armor_class":6,"attacks_per_round":1,"attack_as":"4 HD","weapon":"Battle axe","variable_weapon_damage":"1d8","standard_weapon_damage":"1d6","requires_two_hands":true,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-GUARD-2","species":"HOBGOBLIN","role":"bodyguard","hp_start":10,"hp_roll_faces":[5,2,3],"hp_roll_notation":"3d6 fixture for stated 3-18 HP","armor_class":6,"attacks_per_round":1,"attack_as":"4 HD","weapon":"Pole arm","variable_weapon_damage":"1d10","standard_weapon_damage":"1d6","requires_two_hands":true,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-01","species":"HOBGOBLIN","role":"ordinary","hp_start":6,"hp_roll_faces":[5],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Spear","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-02","species":"HOBGOBLIN","role":"ordinary","hp_start":3,"hp_roll_faces":[2],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Short sword","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-03","species":"HOBGOBLIN","role":"ordinary","hp_start":6,"hp_roll_faces":[5],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Mace","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-04","species":"HOBGOBLIN","role":"ordinary","hp_start":8,"hp_roll_faces":[7],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Club","variable_weapon_damage":"1d4","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-05","species":"HOBGOBLIN","role":"ordinary","hp_start":2,"hp_roll_faces":[1],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"War hammer","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-06","species":"HOBGOBLIN","role":"ordinary","hp_start":6,"hp_roll_faces":[5],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Sword (normal)","variable_weapon_damage":"1d8","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-07","species":"HOBGOBLIN","role":"ordinary","hp_start":3,"hp_roll_faces":[2],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Hand axe","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-08","species":"HOBGOBLIN","role":"ordinary","hp_start":7,"hp_roll_faces":[6],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Dagger","variable_weapon_damage":"1d4","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-09","species":"HOBGOBLIN","role":"ordinary","hp_start":4,"hp_roll_faces":[3],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Spear","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-10","species":"HOBGOBLIN","role":"ordinary","hp_start":8,"hp_roll_faces":[7],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Mace","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-11","species":"HOBGOBLIN","role":"ordinary","hp_start":8,"hp_roll_faces":[7],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Short sword","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-12","species":"HOBGOBLIN","role":"ordinary","hp_start":5,"hp_roll_faces":[4],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Club","variable_weapon_damage":"1d4","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-13","species":"HOBGOBLIN","role":"ordinary","hp_start":9,"hp_roll_faces":[8],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Sword (normal)","variable_weapon_damage":"1d8","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-14","species":"HOBGOBLIN","role":"ordinary","hp_start":5,"hp_roll_faces":[4],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Hand axe","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10},{"actor_id":"HOB-T002-15","species":"HOBGOBLIN","role":"ordinary","hp_start":3,"hp_roll_faces":[2],"hp_roll_notation":"1d8+1","armor_class":6,"attacks_per_round":1,"attack_as":"1+1 HD","weapon":"Spear","variable_weapon_damage":"1d6","standard_weapon_damage":"1d6","requires_two_hands":false,"damage_bonus":0,"morale_base":8,"morale_if_king_present":10}]',
  N'{"source":"Mentzer parenthetical 4-24 lair range","proposed_expression":"4d6","faces":[3,6,4,5],"result":18,"inclusion_policy":"fixture convention: includes 1 king, 2 guards, 15 ordinary","not_source_mandated":true,"guards_count_roll":{"expression":"1d4","faces":[2],"result":2}}',
  N'{"party":{"1d6":1,"surprised_on":[1,2],"surprised":true},"hobgoblins":{"1d6":1,"surprised_on":[1,2],"surprised":true},"one_roll_per_side":true}',
  N'{"location":"synthetic underground lair; NOT automatically a room in B1","daylight":false,"king_present":true,"king_alive":true,"king_fixed_hp":22,"bodyguard_count":2,"bodyguard_hp_dice":"3d6 as synthetic rolls within Mentzer 3-18 range","king_attack_as":"5 HD","guard_attack_as":"4 HD","morale_followers_with_present_living_king":10,"morale_followers_otherwise":8,"count_includes_king_and_bodyguards":"fixture assumption, source not explicit","king_damage_bonus":2}',
  N'{"actor_count":18,"ordinary_count":15,"bodyguard_count":2,"king_count":1,"total_hp":126,"surprise_both_sides":true,"morale_before_king_death":10,"morale_after_death":8,"no_immediate_morale_check_from_death":true}',
  N'assets/monsters/AIDM_HOBGOBLIN_S15_Stock_Illustration.webp',
  N'Previously reported fixed 4d6 [3,6,4,5]=18, bodyguards 1d4=2, fixed king HP22, guards HP 11 and 10, ordinary HP as saved; total 126. WARNING: including king and guards inside 4d6 lair count is a synthetic fixture convention; Mentzer does not resolve inclusion. AIDM test only, not ready or approved as universal rule.'
 );
 INSERT INTO [Test].[MonsterTestScenario] ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],[FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],[MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
 SELECT s.[ScenarioCode],s.[ScenarioName],s.[RulesetCode],s.[PrimaryMonsterCode],s.[FixtureRevision],s.[ScenarioStatus],s.[ReadyForExecution],s.[OriginReference],s.[MonsterCount],s.[PartyRosterJson],s.[MonsterRosterJson],s.[CountRollJson],s.[SurpriseJson],s.[SceneFactsJson],s.[ExpectedHandoffJson],s.[IllustrationPath],s.[Notes]
 FROM @Seed AS s
 WHERE NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] AS old WITH (UPDLOCK,HOLDLOCK) WHERE old.[ScenarioCode]=s.[ScenarioCode]);
 PRINT CONCAT(N'MonsterTestScenario inserted rows: ',@@ROWCOUNT);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[MonsterCount],[ScenarioStatus],[ReadyForExecution] FROM [Test].[MonsterTestScenario] WHERE [PrimaryMonsterCode]=N'HOBGOBLIN' ORDER BY [ScenarioCode];
GO