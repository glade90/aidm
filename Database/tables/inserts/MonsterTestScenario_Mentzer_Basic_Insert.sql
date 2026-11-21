/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestScenario_Mentzer_Basic_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestScenario_Mentzer_Basic_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : Six DISTINCT source-checked encounter regression fixtures
                  from original OneNote, one SQL row per encounter.
Database        : DnD / Rules.MonsterTestScenario (SQL Server 2016+)
Version         : 0.1.0 (SPECIFIED, NOT EXECUTED)
Created         : 2026-11-21
Dependencies    : Database/tables/MonsterTestScenario.sql;
                  Database/tables/Monster.sql v0.4;
                  source-checked four-species and Troglodyte inserts.
Original notes  : AIDM-DES-001.7 OneNote Combat Test Requirements & Scenarios
                  and Special Encounter Requirements by Monster.

POLICY
- B1 ONLY selected which monster species to review. No B1 HP/counts/stats.
- ONE ROW PER DISTINCT ENCOUNTER: ORC patrol vs ORC tribal chieftain are TWO.
- Structured SQL columns + SQL Server JSON-valid arrays; test/scene
  providers must validate role/MonsterCode/HP referential and JSON shapes.
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

IF OBJECT_ID(N'Rules.MonsterTestScenario', N'U') IS NULL
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
        [TestCasesJson] NVARCHAR(MAX) NOT NULL,
        [ExpectedHandoffJson] NVARCHAR(MAX) NULL,
        [IllustrationPath] NVARCHAR(500) NULL,
        [Notes] NVARCHAR(MAX) NULL
    );

    INSERT INTO @Seed
    ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [TestCasesJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
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
         N'[{"test_id":"ORC-T01","phase":"COMBAT","given":"Daylight=true; ORC-A d20=12","expected":"Agent applies -1 to Hit only; adjusted attack=11, no damage penalty.","dice":{"attack_d20":12}},{"test_id":"ORC-T02","phase":"COMBAT","given":"Reset daylight=false; ORC-A d20=12","expected":"No daylight modifier; attack total=12; stale modifier removed.","dice":{"attack_d20":12}},{"test_id":"ORC-T03","phase":"COMBAT","given":"Reset daylight=true; ORC-L attacks; d20=18, weapon d6=4","expected":"Hit total=17; if hit, damage=5 (4+1 leader); ordinary Orc damage=4.","dice":{"attack_d20":18,"damage_d6":4}},{"test_id":"ORC-T04","phase":"COMBAT","given":"Confirmed death ORC-L; next normally triggered morale roll=4+3=7","expected":"Surviving group morale changes 8->6; 7 fails against 6; no unscheduled check.","dice":{"morale_2d6":[4,3]}},{"test_id":"ORC-T06","phase":"COMBAT","given":"Night encounter, Orc wary of stronger enemy","expected":"Do not invent additional automatic fear penalty, extra saves or special Hit modifier."}]',
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
         N'[{"test_id":"ORC-T05","phase":"COMBAT","given":"ORC-C daylight attack d20=18; damage d6=4 on hit","expected":"Use 4-HD monster attack row; -1 to Hit=>17; on hit damage=6 (4+2), NOT 7 (+3).","dice":{"attack_d20":18,"damage_d6":4}},{"test_id":"ORC-T05N","phase":"COMBAT","given":"ORC-D attacks with same weapon","expected":"Uses ordinary Orc hit table and no chieftain +2 damage."},{"test_id":"ORC-T06","phase":"COMBAT","given":"Strong opponent described narratively","expected":"No automatic numeric fear penalty, saving throw or extra morale roll."}]',
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
         N'[{"test_id":"CENT-C01","phase":"COMBAT","given":"Centipede bite misses","expected":"No HP loss, saving throw or NAUSEATED."},{"test_id":"CENT-C02","phase":"COMBAT","given":"Bite hits; victim Poison save succeeds","expected":"Zero bite damage, no NAUSEATED."},{"test_id":"CENT-C03","phase":"COMBAT","given":"Bite hits; actual victim Poison save fails","expected":"Zero damage; correct victim marked NAUSEATED with source attribution."},{"test_id":"CENT-C04","phase":"COMBAT","given":"Victim has distinct Save-As profile","expected":"Resolve actual victim saving throw, not attacking centipede''s Normal Man save."},{"test_id":"CENT-C05","phase":"COMBAT","given":"Repeated or simultaneous attacks against different actors","expected":"Do not double-apply state; do not invent death, HP poison damage or repeated saves."},{"test_id":"CENT-L01","phase":"DEFERRED_LIFECYCLE","given":"Named NAUSEATED exists","expected":"Ten-day timer, half movement, inability other physical actions and cross-encounter persistence belong to AIDM-DES-001.7.5; NOT initial combat regression."}]',
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
         N'[{"test_id":"CRAW-C01","phase":"COMBAT","given":"All 4 active crawlers can legally attack","expected":"Up to 32 distinct tentacle Hit rolls per round, each attack separately logged; no arbitrary guaranteed wipe."},{"test_id":"CRAW-C02","phase":"COMBAT","given":"A tentacle misses","expected":"Zero damage, no paralysis saving throw."},{"test_id":"CRAW-C03","phase":"COMBAT","given":"A tentacle hits; save versus Paralysis passes","expected":"Zero HP damage; one save for struck victim; no condition."},{"test_id":"CRAW-C04","phase":"COMBAT","given":"A tentacle hits; save versus Paralysis fails","expected":"Zero HP damage; actual target marked PARALYZED with attribution."},{"test_id":"CRAW-C05","phase":"COMBAT","given":"Other active threats exist, then cease","expected":"Monster agent can choose un-paralysed threats; feeding described only when unthreatened, no invented bite damage."},{"test_id":"CRAW-C06","phase":"COMBAT_HANDOFF","given":"Party says ''We run away!'' before forced attack","expected":"Validate FLEE intent and journal PENDING exit handoff; no automatic escape/chase.","story":"AIDM-DES-002.1"},{"test_id":"CRAW-L01","phase":"DEFERRED_LIFECYCLE","given":"Victim PARALYZED","expected":"2d4-turn timer, cure/auto-hit/expiry are AIDM-DES-001.7.6, not this initial fixture."}]',
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
         N'[{"test_id":"CRAB-E01","phase":"ENCOUNTER","given":"Party surprise d6=5; spider d6=2; camouflage applicable","expected":"Party NOT surprised; spiders ARE surprised; only party acts surprise round; normal initiative later."},{"test_id":"CRAB-C01","phase":"COMBAT","given":"Spider bite misses","expected":"No damage, no Poison save or POISONED."},{"test_id":"CRAB-C02","phase":"COMBAT","given":"Spider bite hits; victim Poison save +2 succeeds","expected":"1d8 initial bite HP damage persists; no POISONED."},{"test_id":"CRAB-C03","phase":"COMBAT","given":"Spider bite hits; victim Poison save +2 fails","expected":"1d8 initial bite HP damage; correct victim marked POISONED (source spider), no immediate extra damage or death."},{"test_id":"CRAB-C04","phase":"COMBAT","given":"Multiple spider/victim combinations","expected":"Source attribution and per-actor status isolated; +2 only on Poison save, not Hit or damage."},{"test_id":"CRAB-C05","phase":"COMBAT","given":"Torch shown and spider behaviour interpreted","expected":"No automatic fire/fear Hit or morale penalty; no web attack."},{"test_id":"CRAB-L01","phase":"DEFERRED_LIFECYCLE","given":"POISONED victim persists","expected":"Death in 1d4 dungeon turns if not cured belongs AIDM-DES-001.7.7, not initial combat regression."}]',
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
         N'[{"test_id":"TROG-E01","phase":"ENCOUNTER","given":"Rock-wall camouflage, party d6=4 and Troglodyte side d6=3","expected":"Party surprised under 1-4 threshold, troglodytes NOT surprised under 1-2; no normal initiative in surprise round."},{"test_id":"TROG-C02","phase":"COMBAT","given":"One eligible troglodyte executes full natural attack pattern","expected":"Exactly three independent Hit rolls, two claws plus bite, each hit causes separate 1d4 damage; no bite venom invented."},{"test_id":"TROG-C03","phase":"COMBAT","given":"Scene injects human/demi-human stench exposure, victim passes Poison save","expected":"No RETCHING or -2 modifier."},{"test_id":"TROG-C04","phase":"COMBAT","given":"Scene injects stench exposure, victim fails Poison save and attacks Troglodyte in melee","expected":"Correct victim gets RETCHING; -2 to Hit on hand-to-hand attack vs Troglodyte, no AC/damage modifier."},{"test_id":"TROG-C05","phase":"COMBAT","given":"RETCHING victim uses missile/spell or attacks non-Troglodyte","expected":"No stench -2; not on Poison save itself."},{"test_id":"TROG-C06","phase":"COMBAT","given":"RETCHING victim exists alongside Centipede NAUSEATED","expected":"Do not assign ten-day illness, halve movement, prohibit actions or impose poison HP damage from RETCHING."},{"test_id":"TROG-C07","phase":"COMBAT","given":"More than one PC, different stench exposure/save outcomes","expected":"Correct actor isolation, no guessed stench radius, repeated saves or expiry."}]',
         NULL,
         NULL,
         N'New fixed encounter: five Troglodytes vs established four adventurers. Surprise belongs to Encounter only, NOT combat. Troglodyte image not yet created; scene models actual exposure facts, not universal automatic stench. Exact combat/save d20 dice remain injectable. Owner-approved RETCHING state spelling: RETCHING.');

    DECLARE @Inserted TABLE ([ScenarioCode] NVARCHAR(80) NOT NULL);

    INSERT INTO [Rules].[MonsterTestScenario]
    ([ScenarioCode], [ScenarioName], [RulesetCode], [PrimaryMonsterCode], [FixtureRevision], [ScenarioStatus], [ReadyForExecution], [OriginReference], [MonsterCount], [PartyRosterJson], [MonsterRosterJson], [CountRollJson], [SurpriseJson], [SceneFactsJson], [TestCasesJson], [ExpectedHandoffJson], [IllustrationPath], [Notes])
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
        s.[TestCasesJson],
        s.[ExpectedHandoffJson],
        s.[IllustrationPath],
        s.[Notes]
    FROM @Seed AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[MonsterTestScenario] AS existing WITH (UPDLOCK, HOLDLOCK)
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
FROM [Rules].[MonsterTestScenario]
WHERE [ScenarioCode] IN
    (N'ORC-T001-A', N'ORC-T001-B', N'CENT-T001',
     N'CRAW-T001', N'CRAB-T001', N'TROG-T001')
ORDER BY [ScenarioCode];
GO
