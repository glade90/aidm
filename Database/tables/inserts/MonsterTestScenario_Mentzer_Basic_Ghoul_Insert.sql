/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestScenario_Mentzer_Basic_Ghoul_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Ghoul_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : One structured encounter scenario for THREE Ghouls vs the
                  established party, including fixed HP and surprise dice.
Target          : PEQUOD SQL Server 2016+, [DnD].[Test].[MonsterTestScenario]
Version         : 0.1.0 (Specified/ReadyForExecution=0)
Created         : 2026-11-21
Dependencies    : [Test] schema, Test.MonsterTestScenario table, Ghoul species
                  reference from Rules.Monster.
Source          : 1983 Mentzer Basic DM Rulebook, Ghoul, printed p.30.
Test boundary   : B1 S04 selects Ghoul as a species ONLY; no B1 HP or group
                  data. 1d6=3 and individual 2d8 rolls are synthetic fixtures.
                  Surprise rolls are explicit test choices, not source rules.
                  PC stats and ancestry must resolve from real character data;
                  never assume any party member is an Elf. Use synthetic
                  actor substitute for Elf/oversize negative tests.
                  Source code commit does not execute any SQL on PEQUOD.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario',N'U') IS NULL
    THROW 56655,'Test.MonsterTestScenario missing. Create Test schema/table.',1;
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
    (N'GHOUL-T001',
     N'Three Ghouls — three attacks, paralysis, Elf immunity',
     N'MentzerBECMI',
     N'GHOUL',
     1,
     N'Specified',
     0,
     N'1983 Mentzer Basic Dungeon Masters Rulebook, Ghoul p.30 and Undead/general Paralysis rules; Golden Braid AIDM-DES-001.7/S04 source review on 2026-11-21.',
     3,
     N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load real character stats and ancestry; never assume any named PC is an Elf."},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load real character stats and ancestry; never assume any named PC is an Elf."},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load real character stats and ancestry; never assume any named PC is an Elf."},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"ancestry":null,"notes":"Load real character stats and ancestry; never assume any named PC is an Elf."}]',
     N'[{"actor_id":"GHOUL-1","hp_start":11,"hp_faces":[5,6],"species":"GHOUL","role":"ordinary_ghoul","armor_class":6,"hit_dice":"2*","attack_pattern":["claw","claw","bite"],"damage_pattern":["1d3","1d3","1d3"],"save_as":"Fighter 2","morale":9,"damage_plus_special":"each eligible successful hit: Save vs Paralysis, unless Elf/size > Ogre"},{"actor_id":"GHOUL-2","hp_start":10,"hp_faces":[3,7],"species":"GHOUL","role":"ordinary_ghoul","armor_class":6,"hit_dice":"2*","attack_pattern":["claw","claw","bite"],"damage_pattern":["1d3","1d3","1d3"],"save_as":"Fighter 2","morale":9,"damage_plus_special":"each eligible successful hit: Save vs Paralysis, unless Elf/size > Ogre"},{"actor_id":"GHOUL-3","hp_start":8,"hp_faces":[4,4],"species":"GHOUL","role":"ordinary_ghoul","armor_class":6,"hit_dice":"2*","attack_pattern":["claw","claw","bite"],"damage_pattern":["1d3","1d3","1d3"],"save_as":"Fighter 2","morale":9,"damage_plus_special":"each eligible successful hit: Save vs Paralysis, unless Elf/size > Ogre"}]',
     N'{"expression":"1d6","faces":[3],"result":3,"provenance":"Synthetic normal Mentzer Ghoul number appearing 1-6; NOT sourced from B1 stocked encounter"}',
     N'{"phase":"ENCOUNTER","party":{"d6":4,"surprised_on":[1,2],"is_surprised":false},"monsters":{"d6":5,"surprised_on":[1,2],"is_surprised":false},"result":"Neither side surprised; Ghoul silent undead nature does not automatically grant exceptional surprise","initiative":"Normal initiative from beginning of combat (no surprise round)"}',
     N'{"location":"cold, dimly lit underground crypt with cracked stone tombs","ghouls_undead":true,"ghouls_make_no_noise":true,"ghouls_hostile_to_living":true,"ghoul_special_surprise_threshold":false,"ghouls_visible_at_start":true,"geometry":"mocked; do not invent distances/reach","party_attributes":"always resolve existing canonical party; no invented Elf status","synthetic_eligibility_branches":{"elf":"separate test substitute, not named party actor","creature_larger_than_ogre":"separate test substitute","eligible_nonghoul_living_target":"explicit fixture fact"},"conditions_resolved_by_generic_rules":true,"noncombat_choices":["attempt to avoid","parley attempt","stand off","retreat or flee"],"mechanics":"source-backed only; one saving throw per eligible successful ghoul hit"}',
     N'{"phase":"ENCOUNTER_TO_COMBAT","monster_count":3,"ghouls_hp":[11,10,8],"surprise":"neither","monster_species_snapshot":"Rules.Monster.GHOUL, pinned by RulesetCode + RecordDate","rules_effects":["1d3 damage per successful claw or bite","Paralysis save if eligible non-Elf of ogre size or smaller","Undead traits"],"no_sql_reads_from_combat":true}',
     N'assets/images/monsters/AIDM_GHOUL-T001_Three_Ghouls_Illustration.webp',
     N'Exactly THREE ghouls, 2d8 HP faces 5+6=11, 3+7=10, 4+4=8. Encounter count 1d6=3. Party Alho/Evro/Sho/Ralt reused without inventing their stats or species; Elf immunity and oversized-victim branches use clearly labelled test-only substitute actors. Ghouls make no noise but ordinary surprise threshold still applies. Enemy target redirection after paralysis is source guidance, not extra action. Specified only, not runnable/UAT passed.');

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
    PRINT CONCAT(N'Inserted ',@Inserted,N' Ghoul scenario (Specified only).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT [ScenarioCode],[ScenarioName],[MonsterCount],[ScenarioStatus],
       [ReadyForExecution],[CountRollJson],[SurpriseJson],[IllustrationPath]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode]=N'GHOUL-T001';
GO
