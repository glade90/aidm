/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestScenario_Mentzer_Basic_Kobold_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Kobold_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : Insert TWO distinct owner-reviewed, fixed Kobold encounters,
                  one row per encounter: ordinary ambush and chieftain lair.
Database        : PEQUOD / DnD.[Test].[MonsterTestScenario]
Version         : 0.1.0 (Specified; NOT test executed or approved)
Created         : 2026-11-21
Depends         : Database/database/Test.sql; Database/tables/MonsterTestScenario.sql
                  and Kobold Rules.Monster species insert.
Source          : 1983 Mentzer Basic DM Rulebook Kobold p.32.
Notes           : B1 S03/S19 selects species only. All group count, HP and
                  initiative/surprise faces are synthetic FIXTURES, not module
                  encounter stats. KOB-T001 count 4d4=8, 1/2 HD each (1d4),
                  surprise party d6=1, Kobolds d6=4, normal threshold 1-2.
                  KOB-T002 ten total Kobolds including chieftain+bodyguards,
                  unrolled surprise, non-B1 source, no matching picture.
                  Original party Alho/Evro/Sho/Ralt stats are resolved from
                  canonical data at runtime; no invented attributes.
                  Rerunnable; won't overwrite existing scenarios.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
    THROW 56635,'Test.MonsterTestScenario missing. Create [Test] schema/table first.',1;
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
    (N'KOB-T001',
     N'Eight Kobolds — ambush, weapons and minimum damage',
     N'MentzerBECMI',
     N'KOBOLD',
     1,
     N'Specified',
     0,
     N'Mentzer Basic DM Rulebook Kobold p.32, Golden Braid AIDM-DES-001.7 S03/S19 source review 21 Nov 2026',
     8,
     N'[{"actor_id":"Alho","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."},{"actor_id":"Evro","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."},{"actor_id":"Sho","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."},{"actor_id":"Ralt","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."}]',
     N'[{"actor_id":"KOB-A1","species":"KOBOLD","role":"ordinary","hp_start":2,"hp_faces":[2],"armor_class":7,"hit_dice":"1/2","weapon":"short bow","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A2","species":"KOBOLD","role":"ordinary","hp_start":4,"hp_faces":[4],"armor_class":7,"hit_dice":"1/2","weapon":"short bow","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A3","species":"KOBOLD","role":"ordinary","hp_start":3,"hp_faces":[3],"armor_class":7,"hit_dice":"1/2","weapon":"short bow","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A4","species":"KOBOLD","role":"ordinary","hp_start":1,"hp_faces":[1],"armor_class":7,"hit_dice":"1/2","weapon":"short sword","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A5","species":"KOBOLD","role":"ordinary","hp_start":4,"hp_faces":[4],"armor_class":7,"hit_dice":"1/2","weapon":"short sword","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A6","species":"KOBOLD","role":"ordinary","hp_start":2,"hp_faces":[2],"armor_class":7,"hit_dice":"1/2","weapon":"short sword","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A7","species":"KOBOLD","role":"ordinary","hp_start":3,"hp_faces":[3],"armor_class":7,"hit_dice":"1/2","weapon":"short sword","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6},{"actor_id":"KOB-A8","species":"KOBOLD","role":"ordinary","hp_start":2,"hp_faces":[2],"armor_class":7,"hit_dice":"1/2","weapon":"short sword","weapon_damage":"1d6","attack_table":"up-to-1-HD","morale":6}]',
     N'{"expression":"4d4","faces":[2,3,1,2],"result":8,"source":"Mentzer normal number appearing 4-16; synthetic fixed fixture, NOT B1"}',
     N'{"phase":"ENCOUNTER","special_surprise_threshold":false,"party":{"d6":1,"surprised_on":[1,2],"is_surprised":true},"monsters":{"d6":4,"surprised_on":[1,2],"is_surprised":false},"result":"Kobolds surprise party using normal threshold; no special Kobold 1-4 rule","surprise_round":"Kobolds may act; party may not; no ordinary initiative until normal rounds"}',
     N'{"location":"rocky underground passage with rubble and short firing lanes","visibility":"dark dungeon","kobold_infravision_ft":90,"ambush_preference":true,"cover":"available for both sides; exact geometry/range modifiers not part of this initial test","weapon_selection":"fixture weapons deliberately selected for tests, NOT taken from B1","roster_frozen":true,"player_choices":["fight","avoid","parley","stand_off","retreat"],"damage_minimum_one_after_successful_hit":true}',
     N'{"phase":"ENCOUNTER_TO_COMBAT","surprise":"party surprised","scenario_provides":"full actor roster and validated versioned Kobold reference; Combat performs no PEQUOD reads","no_automatic_b1_mechanics":true}',
     N'assets/images/monsters/AIDM_KOB-T001_Eight_Kobolds_Illustration.webp',
     N'Eight ordinary Kobolds, 8 individual HP fixed from 1d4, normal surprise party=1 Kobolds=4. The illustration depicts eight Kobolds and is attached only to this exact scenario. Ordinary party actor stats are deliberately fetched from existing canonical records. All statuses Specified / not yet runnable.'),
    (N'KOB-T002',
     N'Kobold lair — chieftain, three bodyguards and morale',
     N'MentzerBECMI',
     N'KOBOLD',
     1,
     N'Specified',
     0,
     N'Mentzer Basic DM Rulebook Kobold p.32, Golden Braid AIDM-DES-001.7 leadership review 21 Nov 2026',
     10,
     N'[{"actor_id":"Alho","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."},{"actor_id":"Evro","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."},{"actor_id":"Sho","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."},{"actor_id":"Ralt","source":"canonical existing party actor","hp_start":null,"armor_class":null,"notes":"Resolve existing party statistics at encounter bootstrap; not invented in this fixture."}]',
     N'[{"actor_id":"KOB-CH","species":"KOBOLD","role":"chieftain","hp_start":9,"armor_class":7,"attack_table":"2-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_present":8},{"actor_id":"KOB-BG1","species":"KOBOLD","role":"chieftain_bodyguard","hp_start":6,"armor_class":7,"attack_table":"1+1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8},{"actor_id":"KOB-BG2","species":"KOBOLD","role":"chieftain_bodyguard","hp_start":6,"armor_class":7,"attack_table":"1+1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8},{"actor_id":"KOB-BG3","species":"KOBOLD","role":"chieftain_bodyguard","hp_start":6,"armor_class":7,"attack_table":"1+1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8},{"actor_id":"KOB-L1","species":"KOBOLD","role":"ordinary","hp_start":2,"hp_faces":[2],"armor_class":7,"attack_table":"up-to-1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8,"otherwise_morale":6},{"actor_id":"KOB-L2","species":"KOBOLD","role":"ordinary","hp_start":1,"hp_faces":[1],"armor_class":7,"attack_table":"up-to-1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8,"otherwise_morale":6},{"actor_id":"KOB-L3","species":"KOBOLD","role":"ordinary","hp_start":4,"hp_faces":[4],"armor_class":7,"attack_table":"up-to-1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8,"otherwise_morale":6},{"actor_id":"KOB-L4","species":"KOBOLD","role":"ordinary","hp_start":3,"hp_faces":[3],"armor_class":7,"attack_table":"up-to-1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8,"otherwise_morale":6},{"actor_id":"KOB-L5","species":"KOBOLD","role":"ordinary","hp_start":2,"hp_faces":[2],"armor_class":7,"attack_table":"up-to-1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8,"otherwise_morale":6},{"actor_id":"KOB-L6","species":"KOBOLD","role":"ordinary","hp_start":1,"hp_faces":[1],"armor_class":7,"attack_table":"up-to-1-HD","weapon":"short sword","weapon_damage":"1d6","morale_while_chieftain_alive":8,"otherwise_morale":6}]',
     NULL,
     NULL,
     N'{"environment":"underground Kobold lair chamber","total_count":10,"count_justification":"scenario-selected total ten lies inside 6-60 lair range; NOT an official die roll","bodyguard_roll":{"expression":"1d6","faces":[3],"result":3},"composition":{"chieftains":1,"bodyguards":3,"ordinary":6},"chieftain_id":"KOB-CH","chieftain_alive":true,"chieftain_with_group":true,"leadership_morale_alive":8,"leadership_morale_absent":6,"unrolled_surprise":"no pre-encounter surprise roll assigned in this fixture","negotiation_and_standoff_possible":true,"gnome_hostility":"conditional on actual character species; no assigned party species fabricated","weapons":"fixture-assigned short swords; not B1 data"}',
     N'{"combat_roster":"actor IDs roles HP weapon + attack-table override and chieftain presence","after_chieftain_death":"ML 8->6; next normal morale trigger, no extra automatic roll","no_direct_sql_from_combat":true}',
     NULL,
     N'Ten total Kobolds: 1 chieftain (9 HP, attacks as 2 HD); 3 bodyguards (each 6 HP, attacks as 1+1 HD); six ordinary Kobolds (fixed 1d4 HP [2,1,4,3,2,1]). Source does not prescribe exact default lair total composition beyond ranges: count and membership are an explicit synthetic test choice, not an official result. No artwork from the eight-Kobold ambush has been misassigned here.');

    DECLARE @Inserted TABLE ([ScenarioCode] NVARCHAR(80) NOT NULL);
    INSERT INTO [Test].[MonsterTestScenario]
    ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
    OUTPUT inserted.[ScenarioCode] INTO @Inserted([ScenarioCode])
    SELECT s.[ScenarioCode], s.[ScenarioName], s.[RulesetCode], s.[PrimaryMonsterCode], s.[FixtureRevision], s.[ScenarioStatus], s.[ReadyForExecution], s.[OriginReference], s.[MonsterCount], s.[PartyRosterJson], s.[MonsterRosterJson], s.[CountRollJson], s.[SurpriseJson], s.[SceneFactsJson], s.[ExpectedHandoffJson], s.[IllustrationPath], s.[Notes]
    FROM @Seed AS s
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [Test].[MonsterTestScenario] AS t WITH (UPDLOCK,HOLDLOCK)
        WHERE t.[ScenarioCode]=s.[ScenarioCode]
    );
    DECLARE @N INT=(SELECT COUNT(*) FROM @Inserted);
    COMMIT;
    PRINT CONCAT(N'Inserted ',@N,N' Kobold scenarios (Specified only).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],
       [ReadyForExecution],[SurpriseJson],[IllustrationPath]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode] IN (N'KOB-T001',N'KOB-T002')
ORDER BY [ScenarioCode];
GO
