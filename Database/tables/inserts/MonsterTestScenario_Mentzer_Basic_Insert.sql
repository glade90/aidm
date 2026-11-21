/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestScenario_Mentzer_Basic_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : Six DISTINCT source-checked encounter regression fixtures
                  from original OneNote, one SQL row per encounter.
Database        : DnD / Test.MonsterTestScenario (SQL Server 2016+)
Version         : 0.3.0 (SPECIFIED, NOT EXECUTED)
Created         : 2026-11-21
Dependencies    : Database/tables/MonsterTestScenario.sql;
                  Database/tables/Monster.sql v0.4;
                  source-checked four-species and Troglodyte inserts.
Original notes  : AIDM-DES-001.7 OneNote Combat Test Requirements & Scenarios
                  and Special Encounter Requirements by Monster.

POLICY
- B1 ONLY selected which monster species to review. No B1 HP/counts/stats.
- ONE ROW PER DISTINCT ENCOUNTER: ORC patrol vs ORC tribal chieftain are TWO.
- Structured SQL columns + SQL Server JSON-valid arrays for actor rosters,
  scene and precombat rolls; test/scene providers validate IDs and shapes.
- Cases are normalized from the start: they live in Test.MonsterTestCase
  with one row per test, inserted separately. No embedded case arrays.
- The owner has NOT executed any older test tables on PEQUOD: start clean
  using the new Test schema. NO normalization migration is necessary.
- Tests and source fixtures are specifications, not code runs/UAT passes.
  Each row begins ScenarioStatus=Specified, ReadyForExecution=0.
- Missing older synthetic Orc actor HP are NULL and MUST be filled by
  approved fixture before that encounter becomes executable.
- Monster illustration must match encounter composition and be approved;
  Orc art of FIVE Orcs is NOT matched to either smaller synthetic fixture,
  and Crab Spider image is explicitly DRAFT and deliberately not linked.
- No database or campaign state writes executed by committing this file.
- Rerunnable INSERT skips pre-existing ScenarioCode; user-owned edits and
  established histories are never silently overwritten.
===============================================================================
*/
USE [DnD];
GO

IF OBJECT_ID(N'Test.MonsterTestScenario', N'U') IS NULL
    THROW 56590, 'MonsterTestScenario table missing: run MonsterTestScenario.sql first.', 1;
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
        (N'ORC-T001-A',
         N'Orc patrol — daylight, leader, morale',
         N'MentzerBECMI',
         N'ORC',
         1,
         N'Specified',
         0,
         N'AIDM-DES-001.7 — Monster Combat Test Requirements & Scenarios (21 Nov 2026), plus Special Encounter Requirements by Monster; Mentzer Basic Dungeon Masters Rulebook.',
         3,
         N'[{"actor_id":"PC-T","source":"synthetic isolated opponent","hp_start":20,"armor_class":5}]',
         N'[{"actor_id":"ORC-A","species":"ORC","role":"ordinary","hp_start":null,"armor_class":6,"weapon":"test shortsword, 1d6"},{"actor_id":"ORC-B","species":"ORC","role":"ordinary","hp_start":null,"armor_class":6,"weapon":"test shortsword, 1d6"},{"actor_id":"ORC-L","species":"ORC","role":"ordinary_group_leader","hp_start":8,"armor_class":6,"weapon":"test shortsword, 1d6"}]',
         NULL,
         NULL,
         N'{"daylight":true,"geometry":"mocked","morale":8,"scene_change":"daylight may become false between test resets","equipment":"specified by precombat fixture","nonparty_hp_missing":true}',
         NULL,
         NULL,
         N'Older ORC-T001-A did not specify HP of ORC-A/B: NULL intentionally; requires owner/fixture author to provide before executable run. Original five-Orc picture does NOT depict exact three-Orc roster and is not bound to this scenario. Scene and morale injection mocked.'),
        (N'ORC-T001-B',
         N'Orc tribal chieftain — separate role variant',
         N'MentzerBECMI',
         N'ORC',
         1,
         N'Specified',
         0,
         N'AIDM-DES-001.7 — Monster Combat Test Requirements & Scenarios (21 Nov 2026), plus Special Encounter Requirements by Monster; Mentzer Basic Dungeon Masters Rulebook.',
         2,
         N'[{"actor_id":"PC-T","source":"synthetic isolated opponent","hp_start":20,"armor_class":5}]',
         N'[{"actor_id":"ORC-C","species":"ORC","role":"tribal_chieftain","hp_start":15,"armor_class":6,"attack_table":"4 HD monster","weapon":"test shortsword, 1d6"},{"actor_id":"ORC-D","species":"ORC","role":"ordinary","hp_start":null,"armor_class":6,"weapon":"test shortsword, 1d6"}]',
         NULL,
         NULL,
         N'{"daylight":true,"geometry":"mocked","chieftain_role":"explicit, no ordinary leader automatically created","normal_orc_missing_hp":true}',
         NULL,
         NULL,
         N'Separate encounter from ORC-T001-A; chieftain HP15 source rule, ordinary ORC-D HP missing from historical test specification. Art five Orcs does not match this two-Orc fixture.'),
        (N'CENT-T001',
         N'Six Giant Centipedes — zero-damage poison bites',
         N'MentzerBECMI',
         N'GIANT_CENTIPEDE',
         1,
         N'Specified',
         0,
         N'AIDM-DES-001.7 — Monster Combat Test Requirements & Scenarios (21 Nov 2026), plus Special Encounter Requirements by Monster; Mentzer Basic Dungeon Masters Rulebook.',
         6,
         N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"}]',
         N'[{"actor_id":"CEN-1","species":"GIANT_CENTIPEDE","hp_start":4,"armor_class":9,"hit_dice":"1/2","attacks":"1 bite","morale":7},{"actor_id":"CEN-2","species":"GIANT_CENTIPEDE","hp_start":3,"armor_class":9,"hit_dice":"1/2","attacks":"1 bite","morale":7},{"actor_id":"CEN-3","species":"GIANT_CENTIPEDE","hp_start":4,"armor_class":9,"hit_dice":"1/2","attacks":"1 bite","morale":7},{"actor_id":"CEN-4","species":"GIANT_CENTIPEDE","hp_start":3,"armor_class":9,"hit_dice":"1/2","attacks":"1 bite","morale":7},{"actor_id":"CEN-5","species":"GIANT_CENTIPEDE","hp_start":1,"armor_class":9,"hit_dice":"1/2","attacks":"1 bite","morale":7},{"actor_id":"CEN-6","species":"GIANT_CENTIPEDE","hp_start":4,"armor_class":9,"hit_dice":"1/2","attacks":"1 bite","morale":7}]',
         N'{"expression":"2d4","faces":[3,3],"result":6}',
         NULL,
         N'{"environment":"damp dungeon","surprise":"not rolled in original fixture","geometry":"mocked","rule":"bites trigger Poison saves only on hit","no_b1_data":true}',
         NULL,
         N'assets/images/monsters/AIDM_CENT-T001_Six_Giant_Centipedes_Illustration.png',
         N'Existing four-player party Alho Evro Sho Ralt uses real canonical state; player HP/AC deliberately not duplicated. Exact attack and save rolls for branches will be injected when executed.'),
        (N'CRAW-T001',
         N'Four Carrion Crawlers — paralysis stress and flee',
         N'MentzerBECMI',
         N'CARRION_CRAWLER',
         1,
         N'Specified',
         0,
         N'AIDM-DES-001.7 — Monster Combat Test Requirements & Scenarios (21 Nov 2026), plus Special Encounter Requirements by Monster; Mentzer Basic Dungeon Masters Rulebook.',
         4,
         N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"}]',
         N'[{"actor_id":"CRAW-1","species":"CARRION_CRAWLER","hp_start":17,"armor_class":7,"hit_dice":"3+1*","attacks":"8 tentacles","morale":9},{"actor_id":"CRAW-2","species":"CARRION_CRAWLER","hp_start":12,"armor_class":7,"hit_dice":"3+1*","attacks":"8 tentacles","morale":9},{"actor_id":"CRAW-3","species":"CARRION_CRAWLER","hp_start":20,"armor_class":7,"hit_dice":"3+1*","attacks":"8 tentacles","morale":9},{"actor_id":"CRAW-4","species":"CARRION_CRAWLER","hp_start":6,"armor_class":7,"hit_dice":"3+1*","attacks":"8 tentacles","morale":9}]',
         N'{"expression":"1d4","faces":[4],"result":4}',
         NULL,
         N'{"environment":"deep damp filthy dungeon","geometry":"mocked","danger":"potential 4*8=32 independent attacks if all legal and act","surprise":"not rolled in original fixture","no_forced_battle":true}',
         N'{"action":"FLEE","state":"PENDING_EXIT_HANDOFF","no_auto_escape":true,"source_story":"AIDM-DES-002.1"}',
         N'assets/images/monsters/AIDM_CRAW-T001_Four_Carrion_Crawlers_Illustration.png',
         N'Intentionally lethal stress scenario, not balanced. Starting HP rolls already fixed by historical source. No forced rescue, and flight is allowed. No new fabricated surprise outcomes.'),
        (N'CRAB-T001',
         N'Four Giant Crab Spiders — surprise and delayed poison',
         N'MentzerBECMI',
         N'GIANT_CRAB_SPIDER',
         1,
         N'Specified',
         0,
         N'AIDM-DES-001.7 — Monster Combat Test Requirements & Scenarios (21 Nov 2026), plus Special Encounter Requirements by Monster; Mentzer Basic Dungeon Masters Rulebook.',
         4,
         N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"}]',
         N'[{"actor_id":"CRAB-1","hp_start":11,"hp_faces":[3,8],"species":"GIANT_CRAB_SPIDER","armor_class":7,"hit_dice":"2*","attacks":"1 bite","morale":7},{"actor_id":"CRAB-2","hp_start":11,"hp_faces":[4,7],"species":"GIANT_CRAB_SPIDER","armor_class":7,"hit_dice":"2*","attacks":"1 bite","morale":7},{"actor_id":"CRAB-3","hp_start":9,"hp_faces":[8,1],"species":"GIANT_CRAB_SPIDER","armor_class":7,"hit_dice":"2*","attacks":"1 bite","morale":7},{"actor_id":"CRAB-4","hp_start":7,"hp_faces":[2,5],"species":"GIANT_CRAB_SPIDER","armor_class":7,"hit_dice":"2*","attacks":"1 bite","morale":7}]',
         N'{"expression":"1d4","faces":[4],"result":4}',
         N'{"phase":"ENCOUNTER","party":{"d6":5,"surprised_on":[1,2,3,4],"is_surprised":false},"monsters":{"d6":2,"surprised_on":[1,2],"is_surprised":true},"surprise_round":"party acts, spiders do not; no ordinary initiative"}',
         N'{"environment":"dungeon masonry allowing spider camouflage","ceiling_walls":true,"no_webs":true,"fire_behaviour":"spiders may flee fire, never automatic numerical penalty","geometry":"mocked"}',
         NULL,
         NULL,
         N'Spider illustration assets/images/monsters/AIDM_CRAB-T001_Four_Giant_Crab_Spiders_DRAFT.png remains unapproved due to party figures and webs; do not expose as approved asset. Fixed opposite surprise outcome from Troglodyte test.'),
        (N'TROG-T001',
         N'Five Troglodytes — rock-wall surprise and RETCHING',
         N'MentzerBECMI',
         N'TROGLODYTE',
         1,
         N'Specified',
         0,
         N'AIDM-DES-001.7 — Monster Combat Test Requirements & Scenarios (21 Nov 2026), plus Special Encounter Requirements by Monster; Mentzer Basic Dungeon Masters Rulebook.',
         5,
         N'[{"actor_id":"Alho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Evro","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Sho","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"},{"actor_id":"Ralt","source":"existing canonical character record","hp_start":null,"armor_class":null,"notes":"Resolve current canonical record at Encounter initialisation; do not duplicate or invent attributes"}]',
         N'[{"actor_id":"TROG-1","hp_start":15,"hp_faces":[7,8],"species":"TROGLODYTE","armor_class":5,"hit_dice":"2*","attacks":["claw","claw","bite"],"damage":["1d4","1d4","1d4"],"morale":9},{"actor_id":"TROG-2","hp_start":12,"hp_faces":[7,5],"species":"TROGLODYTE","armor_class":5,"hit_dice":"2*","attacks":["claw","claw","bite"],"damage":["1d4","1d4","1d4"],"morale":9},{"actor_id":"TROG-3","hp_start":9,"hp_faces":[3,6],"species":"TROGLODYTE","armor_class":5,"hit_dice":"2*","attacks":["claw","claw","bite"],"damage":["1d4","1d4","1d4"],"morale":9},{"actor_id":"TROG-4","hp_start":13,"hp_faces":[5,8],"species":"TROGLODYTE","armor_class":5,"hit_dice":"2*","attacks":["claw","claw","bite"],"damage":["1d4","1d4","1d4"],"morale":9},{"actor_id":"TROG-5","hp_start":11,"hp_faces":[6,5],"species":"TROGLODYTE","armor_class":5,"hit_dice":"2*","attacks":["claw","claw","bite"],"damage":["1d4","1d4","1d4"],"morale":9}]',
         N'{"expression":"1d8","faces":[5],"result":5}',
         N'{"phase":"ENCOUNTER","party":{"d6":4,"surprised_on":[1,2,3,4],"is_surprised":true},"monsters":{"d6":3,"surprised_on":[1,2],"is_surprised":false},"surprise_round":"troglodytes may act, party cannot; no ordinary initiative"}',
         N'{"environment":"stone dungeon rough rock walls, camouflage feasible","stench_exposure":"per-actor scene facts injected per test; no sourced radius, resave cadence or expiry","geometry":"mocked","player_may_attempt_parley":true}',
         NULL,
         NULL,
         N'New fixed encounter: five Troglodytes vs established four adventurers. Surprise belongs to Encounter only, NOT combat. Troglodyte image not yet created; scene models actual exposure facts, not universal automatic stench. Exact combat/save d20 dice remain injectable. Owner-approved RETCHING state spelling: RETCHING.');

    DECLARE @Inserted TABLE ([ScenarioCode] NVARCHAR(80) NOT NULL);

    INSERT INTO [Test].[MonsterTestScenario]
    ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
    OUTPUT inserted.[ScenarioCode] INTO @Inserted([ScenarioCode])
    SELECT
        s.[ScenarioCode],
        s.[ScenarioName],
        s.[RulesetCode],
        s.[PrimaryMonsterCode],
        s.[FixtureRevision],
        s.[ScenarioStatus],
        s.[ReadyForExecution],
        s.[OriginReference],
        s.[MonsterCount],
        s.[PartyRosterJson],
        s.[MonsterRosterJson],
        s.[CountRollJson],
        s.[SurpriseJson],
        s.[SceneFactsJson],
        s.[ExpectedHandoffJson],
        s.[IllustrationPath],
        s.[Notes]
    FROM @Seed AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [Test].[MonsterTestScenario] AS existing WITH (UPDLOCK, HOLDLOCK)
        WHERE existing.[ScenarioCode] = s.[ScenarioCode]
    );

    DECLARE @InsertedCount INT = (SELECT COUNT(*) FROM @Inserted);
    COMMIT;
    PRINT CONCAT(N'Inserted ', @InsertedCount,
                 N' new specified MonsterTestScenario encounters.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SELECT [ScenarioCode], [ScenarioName], [PrimaryMonsterCode],
       [MonsterCount], [ScenarioStatus], [ReadyForExecution],
       CASE WHEN [SurpriseJson] IS NULL THEN N'NOT_ROLLED'
            ELSE N'FIXED' END AS [SurpriseStatus],
       [IllustrationPath]
FROM [Test].[MonsterTestScenario]
WHERE [ScenarioCode] IN
    (N'ORC-T001-A', N'ORC-T001-B', N'CENT-T001',
     N'CRAW-T001', N'CRAB-T001', N'TROG-T001')
ORDER BY [ScenarioCode];
GO
