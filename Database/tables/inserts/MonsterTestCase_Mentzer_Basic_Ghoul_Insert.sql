/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : MonsterTestCase_Mentzer_Basic_Ghoul_Insert.sql
Repository Path : Database/tables/inserts/MonsterTestCase_Mentzer_Basic_Ghoul_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : 17 individually identified regression case definitions for
                  GHOUL-T001 (combat paralysis, Elf/size exemptions, undead
                  traits, target selection and Encounter behaviour).
Target          : PEQUOD DnD.[Test].[MonsterTestCase]
Version         : 0.1.0; specified/deferred, NOT executed or UAT passed
Created         : 2026-11-21
Dependencies    : Test.MonsterTestCase, Test.MonsterTestScenario GHOUL-T001.
Source          : 1983 Mentzer Basic DM Rulebook, Ghoul printed p.30,
                  general Undead and Paralysis rules.
Boundaries      : Combat multiattacks + initial state assignments NOW;
                  normal PARALYZED lifecycle/cure deferred generic .7.6;
                  Turn Undead generic rules integration marked Deferred;
                  Encounter surprise/hostility tests not ordinary Combat.
                  B1 selects Ghoul as species only, no module HP/count.
                  Re-running preserves existing case definitions.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestCase',N'U') IS NULL
    THROW 56660,'Test.MonsterTestCase missing. Create Test table first.',1;
IF NOT EXISTS
(
    SELECT 1 FROM [Test].[MonsterTestScenario]
    WHERE [ScenarioCode]=N'GHOUL-T001'
)
    THROW 56661,'GHOUL-T001 missing. Execute Ghoul scenario insert first.',1;
GO

SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;
    DECLARE @Seed TABLE
    (
        [ScenarioCode] NVARCHAR(80) NOT NULL,
        [TestCaseCode] NVARCHAR(80) NOT NULL,
        [SequenceNo] INT NOT NULL,
        [TestName] NVARCHAR(180) NOT NULL,
        [TestPhase] NVARCHAR(40) NOT NULL,
        [TestStatus] NVARCHAR(20) NOT NULL,
        [TestRevision] INT NOT NULL,
        [GivenText] NVARCHAR(MAX) NOT NULL,
        [ExpectedText] NVARCHAR(MAX) NOT NULL,
        [DiceFixtureJson] NVARCHAR(MAX) NULL,
        [AdditionalDataJson] NVARCHAR(MAX) NULL,
        [LinkedStoryRef] NVARCHAR(80) NULL,
        [AutomatedTestRef] NVARCHAR(500) NULL,
        [Notes] NVARCHAR(MAX) NULL,
        PRIMARY KEY ([ScenarioCode],[TestCaseCode]),
        UNIQUE ([ScenarioCode],[SequenceNo])
    );

    INSERT INTO @Seed
    ([ScenarioCode], [TestCaseCode], [SequenceNo], [TestName], [TestPhase], [TestStatus], [TestRevision], [GivenText], [ExpectedText], [DiceFixtureJson], [AdditionalDataJson], [LinkedStoryRef], [AutomatedTestRef], [Notes])
    VALUES
    (N'GHOUL-T001',
     N'GHOUL-C01',
     1,
     N'Two claws plus bite, separate attacks',
     N'COMBAT',
     N'Specified',
     1,
     N'GHOUL-1 is active in a legal round; all three natural attacks available against an eligible target.',
     N'Exactly 3 distinct attack attempts in order claw/claw/bite, with separate Hit results; on each hit roll exactly 1d3 damage plus separate eligible Paralysis save, never collapse into one roll.',
     N'{"attack_d20":[18,4,19],"damage_d3_for_hits":[2,1]}',
     N'{"source_hit_profile":"2 HD","attack_count":3}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C02',
     2,
     N'Miss is harmless to paralysis state',
     N'COMBAT',
     N'Specified',
     1,
     N'The first Ghoul claw misses its nominated victim.',
     N'No damage roll, no Save vs Paralysis and no PARALYZED assignment for that miss.',
     N'{"attack_d20":1}',
     NULL,
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C03',
     3,
     N'Hit damages even when paralysis save passes',
     N'COMBAT',
     N'Specified',
     1,
     N'Ghoul claw hits eligible non-Elf, ogre-size-or-smaller living test victim; the victim passes Save vs Paralysis.',
     N'1d3 HP claw damage applies and the save is journalled, but no PARALYZED condition is assigned.',
     N'{"attack_d20":18,"damage_d3":2,"paralysis_save_result":"PASS"}',
     N'{"synthetic_target":true,"ancestry":"human","relative_size":"human"}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C04',
     4,
     N'Hit damages and paralysis save fails',
     N'COMBAT',
     N'Specified',
     1,
     N'Ghoul bite hits eligible non-Elf, ogre-size-or-smaller victim; that victim fails Save vs Paralysis.',
     N'Apply 1d3 bite damage AND PARALYZED to the actual victim, with source ghoul and attack identifier; no instant death.',
     N'{"attack_d20":18,"damage_d3":3,"paralysis_save_result":"FAIL"}',
     N'{"synthetic_target":true,"ancestry":"human","relative_size":"human"}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C05',
     5,
     N'Elf exception: damage, never paralysis',
     N'COMBAT',
     N'Specified',
     1,
     N'Test branch explicitly substitutes a synthetic Elf target of eligible size; Ghoul claw hits.',
     N'Normal 1d3 HP damage applies. NO Ghoul-induced Paralysis save is requested and no PARALYZED condition added, because Elves are specifically exempt.',
     N'{"attack_d20":18,"damage_d3":1}',
     N'{"victim_ancestry":"Elf","synthetic_target":true}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C06',
     6,
     N'Oversized opponent exception',
     N'COMBAT',
     N'Specified',
     1,
     N'Synthetic living target is explicitly larger than an Ogre; Ghoul claw hits.',
     N'Inflict 1d3 ordinary damage; do not request Ghoul paralysis save or assign PARALYZED based on this hit.',
     N'{"attack_d20":18,"damage_d3":2}',
     N'{"synthetic_target":true,"victim_size_relative_to_ogre":"larger"}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C07',
     7,
     N'Separate saving throw for each eligible hit',
     N'COMBAT',
     N'Specified',
     1,
     N'Eligible synthetic human victim receives two distinct successful Ghoul attacks in the same round; first save passes, second fails.',
     N'Two independent 1d3 damage rolls and TWO victim Paralysis saves; only second failed save assigns PARALYZED, with no duplicate or lost roll.',
     N'{"attack_d20":[18,19],"damage_d3":[1,3],"paralysis_save_results":["PASS","FAIL"]}',
     NULL,
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C08',
     8,
     N'Retarget after paralysis',
     N'COMBAT',
     N'Specified',
     1,
     N'GHOUL-1 paralyses one eligible foe and still has a legally available subsequent natural attack; at least one other active opponent can be reached.',
     N'Combat Agent shifts its target to an unparalysed living opponent when legal, using only remaining normal attacks; do not manufacture a fourth attack or a new targeting phase.',
     NULL,
     N'{"initial_target_status":"PARALYZED","remaining_attacks":1,"other_target_eligible":true}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C09',
     9,
     N'Sleep spell ineffective on Ghoul',
     N'COMBAT',
     N'Specified',
     1,
     N'A valid Sleep spell effect is resolved against GHOUL-2 (undead).',
     N'Generic spell/trait validation rejects Sleep susceptibility; GHOUL-2 is not put to sleep solely by that spell. No Ghoul-specific engine branch.',
     NULL,
     N'{"effect":"Sleep","target_trait":"Undead"}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C10',
     10,
     N'Charm spell ineffective on Ghoul',
     N'COMBAT',
     N'Specified',
     1,
     N'Charm Person or other ordinary mind-affecting Charm effect is applied to GHOUL-2.',
     N'Undead Ghoul remains unaffected by Charm; source trait handled by generic spell/effect resolver, not a new universal immunity to every spell.',
     NULL,
     N'{"effect":"Charm","target_trait":"Undead"}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C11',
     11,
     N'Undead poison immunity',
     N'COMBAT',
     N'Specified',
     1,
     N'Ordinary poison exposure applied to GHOUL-3; the creature has the source-provided Undead trait.',
     N'Generic resistance/trait rules prevent poison affecting Ghoul; do not confuse this with immunity to damage from weapons or unrelated magic.',
     NULL,
     N'{"effect":"poison","target_trait":"Undead"}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C12',
     12,
     N'Victim-specific save and condition isolation',
     N'COMBAT',
     N'Specified',
     1,
     N'Ghoul attacks two separate non-Elf eligible victims; one save fails and the other passes.',
     N'Each victim uses its own Save vs Paralysis and is journalled separately; only failed-save victim becomes PARALYZED, the other retains HP loss but no condition.',
     N'{"paralysis_save_results_by_victim":{"VICTIM_A":"FAIL","VICTIM_B":"PASS"}}',
     NULL,
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C13',
     13,
     N'No automatic execution of helpless prey',
     N'COMBAT',
     N'Specified',
     1,
     N'Ghoul has no active opponent left because all are paralysed, but encounter has not yet resolved what happens to helpless prey.',
     N'Do NOT automatically kill, bite for extra unrolled damage, consume more attacks or teleport; return accurate state for DM/Encounter next-action adjudication.',
     NULL,
     NULL,
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-E01',
     14,
     N'Silent undead, normal surprise',
     N'ENCOUNTER',
     N'Specified',
     1,
     N'Dark crypt, Ghoul makes no noise; party d6=4, ghouls d6=5; no other special hiding/ambush rule.',
     N'Neither side surprised using the normal 1-2 threshold. Silence informs detection and narration but does not automatically grant 1-4 surprise or an extra attack.',
     N'{"party_d6":4,"ghoul_side_d6":5}',
     N'{"special_ghoul_surprise_threshold":false}',
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-E02',
     15,
     N'Hostility without overriding player intent',
     N'ENCOUNTER',
     N'Specified',
     1,
     N'Ghoul detects living party; one player attempts withdrawal, diversion or parley rather than immediately attacking.',
     N'Encounter Agent reflects strong predatory hostility, but processes player action as an attempted choice; no unconditional scripted automatic attack, fear rule, forced fight or guaranteed peaceful outcome.',
     NULL,
     NULL,
     N'AIDM-DES-001.7',
     NULL,
     NULL),
    (N'GHOUL-T001',
     N'GHOUL-C14',
     16,
     N'Cleric Turn Undead uses generic table',
     N'COMBAT',
     N'Deferred',
     1,
     N'Cleric attempts Turn Undead on a correctly revealed Ghoul group.',
     N'Use generic source-backed Cleric Turn Undead service and table if implemented. Do not hardcode automatic success, paralysis or destruction in this monster catalogue; deferred separate rules integration.',
     NULL,
     N'{"rule_family":"Turn Undead","requested_actor_class":"Cleric"}',
     N'AIDM-DES-001.7',
     NULL,
     N'Defined as a future generic service acceptance case; not current executable Combat scope.'),
    (N'GHOUL-T001',
     N'GHOUL-L01',
     17,
     N'Normal paralysis duration and cure',
     N'DEFERRED_LIFECYCLE',
     N'Deferred',
     1,
     N'Victim is PARALYZED after failed Ghoul special save.',
     N'Generic PARALYZED lifecycle (2-8 dungeon turns unless magically cured) controls cannot-act/move, auto-hit on helpless where applicable, persistence, cure and expiry. NOT a Ghoul-specific instant Combat effect.',
     N'{"duration_expression":"2d4 dungeon turns"}',
     N'{"generic_state":"PARALYZED","existing_story":"AIDM-DES-001.7.6"}',
     N'AIDM-DES-001.7.6',
     NULL,
     N'Defined as a future generic service acceptance case; not current executable Combat scope.');

    INSERT INTO [Test].[MonsterTestCase]
    ([ScenarioCode], [TestCaseCode], [SequenceNo], [TestName], [TestPhase], [TestStatus], [TestRevision], [GivenText], [ExpectedText], [DiceFixtureJson], [AdditionalDataJson], [LinkedStoryRef], [AutomatedTestRef], [Notes])
    SELECT s.[ScenarioCode], s.[TestCaseCode], s.[SequenceNo], s.[TestName], s.[TestPhase], s.[TestStatus], s.[TestRevision], s.[GivenText], s.[ExpectedText], s.[DiceFixtureJson], s.[AdditionalDataJson], s.[LinkedStoryRef], s.[AutomatedTestRef], s.[Notes]
    FROM @Seed AS s
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [Test].[MonsterTestCase] AS existing WITH (UPDLOCK,HOLDLOCK)
        WHERE existing.[ScenarioCode]=s.[ScenarioCode]
          AND existing.[TestCaseCode]=s.[TestCaseCode]
    );
    DECLARE @Inserted INT=@@ROWCOUNT;
    COMMIT;
    PRINT CONCAT(N'Inserted ',@Inserted,N' Ghoul test definitions, no execution.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT [ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],
       [TestPhase],[TestStatus]
FROM [Test].[MonsterTestCase]
WHERE [ScenarioCode]=N'GHOUL-T001'
ORDER BY [SequenceNo];
GO
