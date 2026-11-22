/* Golden Braid / AIDM / S22 Gnomes — encounter test fixture
FILE: MonsterTestScenario_Mentzer_Basic_Gnome_Insert.sql
TARGET: PEQUOD / DnD (Test.MonsterTestScenario)
Two-Gnome synthetic fixture; distinct leader and chieftain/bodyguard variants are
specified in test cases, NOT added to this baseline or to canonical B1 room 52.
2026-11-22. INSERT ONLY. Specified/ReadyForExecution=0; not tested.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL THROW 57321,N'Test.MonsterTestScenario missing',1;
IF NOT EXISTS(SELECT 1 FROM [Rules].[Monster] WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GNOME')
 THROW 57322,N'GNOME missing: deploy species first',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM [Test].[MonsterTestScenario] WITH(UPDLOCK,HOLDLOCK) WHERE [ScenarioCode]=N'GNOME-T001')
 BEGIN
  INSERT INTO [Test].[MonsterTestScenario]
  ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],[FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],[MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],[SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
  VALUES (N'GNOME-T001',
   N'The Miners'' Watch (two ordinary Gnomes; B1 S22 species)',
   N'MentzerBECMI',
   N'GNOME',
   1,
   N'Specified',
   0,
   N'Mentzer Basic 1983 DM Rulebook Gnome p.30; synthetic fixture derived from S22 stock progression, 2026-11-22.',
   2,
   N'[{"actor_id":"Alho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual character statistics, never invent"},{"actor_id":"Evro","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual character statistics, never invent"},{"actor_id":"Sho","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual character statistics, never invent"},{"actor_id":"Ralt","source":"authoritative canonical character record","hp_start":null,"armor_class":null,"notes":"Load actual character statistics, never invent"}]',
   N'[{"actor_id":"GNM-T001-1","species":"GNOME","role":"ordinary_gnome","hit_dice":"1","hp_roll":{"expression":"1d8","faces":[7],"result":7},"hp_start":7,"armor_class":5,"attack_as":"1 HD monster","attacks_per_round":1,"attack_kind":"equipped weapon","weapon":"Crossbow (light)","weapon_code":"crossbow","standard_weapon_damage":"1d6","variable_weapon_damage":"1d6","crossbow_range_feet":{"short":60,"medium":120,"long":180},"two_handed":true,"save_as":"Dwarf 1","morale_base":8,"morale_when_living_leader_or_chieftain_visible":10,"leader_visible":false,"infravision_feet":90,"movement_turn_feet":60,"movement_round_feet":20},{"actor_id":"GNM-T001-2","species":"GNOME","role":"ordinary_gnome","hit_dice":"1","hp_roll":{"expression":"1d8","faces":[5],"result":5},"hp_start":5,"armor_class":5,"attack_as":"1 HD monster","attacks_per_round":1,"attack_kind":"equipped weapon","weapon":"War hammer","weapon_code":"war_hammer","standard_weapon_damage":"1d6","variable_weapon_damage":"1d6","two_handed":false,"save_as":"Dwarf 1","morale_base":8,"morale_when_living_leader_or_chieftain_visible":10,"leader_visible":false,"infravision_feet":90,"movement_turn_feet":60,"movement_round_feet":20}]',
   N'{"published_normal":"1-8","published_lair":"5-40","fixed_test_count":2,"fixture_hp_rolls":[7,5],"not_a_random_count_generation":true}',
   N'{"party":{"d6":5,"normal_surprised_on":[1,2],"surprised":false},"gnomes":{"d6":4,"normal_surprised_on":[1,2],"surprised":false},"one_d6_per_side":true}',
   N'{"setting":"Synthetic stone mine gallery at a dungeon passage; a narrow side cutting leads toward a worked mineral vein","observables":"Two bearded Gnomes carrying mining tools and weapons; do not reveal hidden motives or identify automatic hostility.","party_options":["observe","speak","pass","offer trade","withdraw","attack"],"equipped_weapons":["light crossbow","war hammer"],"gnome_count":2,"leader_present":false,"bodyguards_present":false,"chieftain_present":false,"forced_combat":false,"forced_surprise":false,"forced_reaction":false,"rivalry":{"gnomes_encounter_kobolds":"usually attack on sight","kobolds_encounter_gnomes":"will attack on sight","responsibility":"Encounter only"},"alternate_combat_test_roles":{"leader":{"count":"one per twenty ordinary Gnomes","hp":11,"attack_as_hd":2},"bodyguard":{"count_in_lair":"1-6","hp_range":[10,13],"attack_as_hd":3},"chieftain":{"hp":18,"attack_as_hd":4,"damage_bonus":1}},"b1_boundary":"S22 stock sequence and previously fixed room-52 HP are reference only; this is not a rewritten B1 room 52","precise_coordinates":null}',
   N'{"only_if_combat_starts":true,"actor_ids":["GNM-T001-1","GNM-T001-2"],"starting_hp":[7,5],"armor_class":5,"attack_as":"1 HD","save_as":"Dwarf 1","morale":8,"leader_visible":false,"movement_round_feet":20,"validated_surprise_only":true,"validated_position_only":true,"verified_modifiers_only":true,"combat_engine_must_not_interpret_rivalry":true,"weapon_loadouts":["crossbow","war_hammer"],"alternate_roles_tested_separately":true}',
   N'assets/monsters/AIDM_GNOME_S22_The_Miners_Watch.webp',
   N'Two ordinary Gnomes only, fixed HP 7/5, one crossbow and one war hammer. 18 COMBAT tests include alternate leader/bodyguard/chieftain actor role profiles; 10 ENCOUNTER tests cover diplomacy, Kobold hostility, leader/lair composition, surprise and handoff. Future Encounter Engine not built. No test executed; illustration does not authorize mechanics.');
  PRINT N'Inserted GNOME-T001 fixture';
 END ELSE PRINT N'Existing GNOME-T001 preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[MonsterCount],[ScenarioStatus],[ReadyForExecution],[IllustrationPath] FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode]=N'GNOME-T001';
GO
