/*
===============================================================================
Golden Braid / AIDM — GNOLL-T001 source-backed regression tests
File: Database/tables/inserts/MonsterTestCase_Mentzer_Basic_Gnoll_Insert.sql
Target: PEQUOD DnD.[Test].[MonsterTestCase]
Tests: 10 definitions; 6 COMBAT (one deferred leadership), 4 ENCOUNTER
Fixture: GNOLL-T001, 4 monsters HP 5,14,9,10; surprise 3 versus 5.
Source: Original 1983 Mentzer Basic Dungeon Masters Rulebook, Gnoll p.30
Status Specified/Deferred only, no test run, CI result or BON UAT implied.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestCase',N'U') IS NULL
 THROW 56803,N'Test.MonsterTestCase missing; install table first.',1;
IF NOT EXISTS
 (SELECT 1 FROM [Test].[MonsterTestScenario]
  WHERE [ScenarioCode]=N'GNOLL-T001')
 THROW 56804,N'GNOLL-T001 missing; run Gnoll scenario script before these tests.',1;
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
 (N'GNOLL-T001',
  N'GNOLL-C01',
  1,
  N'Ordinary Gnoll uses 2 HD attack row',
  N'COMBAT',
  N'Specified',
  1,
  N'GNOLL-1 is one of four ordinary Gnolls in GNOLL-T001; weapon is validated and supplied by Encounter.',
  N'Exactly one weapon Hit roll uses the 2 Hit Dice monster attack row; do not apply 3 HD leader attack profile.',
  NULL,
  N'{"monster_role":"ordinary","attack_table":"2 HD"}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-C02',
  2,
  N'Weapon damage plus one on successful hit',
  N'COMBAT',
  N'Specified',
  1,
  N'GNOLL-2 successfully hits with an approved weapon whose base damage is 1d6; fixed base die face 4.',
  N'Apply total 5 weapon damage, consisting of original die 4 plus source damage bonus 1, never an extra damage die or a new weapon expression.',
  N'{"weapon_damage_d6":[4]}',
  N'{"weapon_base_expression":"1d6","damage_modifier":1}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-C03',
  3,
  N'Damage modifier is not a Hit modifier',
  N'COMBAT',
  N'Specified',
  1,
  N'An ordinary Gnoll rolls its Hit die against an eligible target and carries a nonmagical weapon.',
  N'Gnoll species provides no +1 to Hit, AC, initiative, saving throws or morale. +1 applies only to the successful weapon damage result.',
  N'{"attack_d20":[12]}',
  N'{"hit_modifier_from_gnoll_species":0,"damage_modifier":1}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-C04',
  4,
  N'Preserve four independent rolled HP values',
  N'COMBAT',
  N'Specified',
  1,
  N'GNOLL-T001 roster has GNOLL-1 through GNOLL-4 individually rolled 2d8 HP [5,14,9,10].',
  N'Combat accepts four separate immutable starting HP values, preserving IDs and source die faces; never reroll or pool HP.',
  NULL,
  N'{"actor_hp":{"GNOLL-1":5,"GNOLL-2":14,"GNOLL-3":9,"GNOLL-4":10},"total":38}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-C05',
  5,
  N'Four Gnolls contain no leadership actor',
  N'COMBAT',
  N'Specified',
  1,
  N'Normal 1d6 appearance roll is face 4; this is below the source threshold of 20 Gnolls per leader.',
  N'No leader, no fixed 16 HP and no 3-HD attack-table override in GNOLL-T001; all four are ordinary Gnolls.',
  N'{"count_d6":[4]}',
  N'{"leader_count":0}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-C06',
  6,
  N'Deferred twenty-Gnoll leadership variant',
  N'COMBAT',
  N'Deferred',
  1,
  N'Separate later test encounter has 20 Gnolls; the source says one leader per 20.',
  N'The additional defined fixture should contain one leader with EXACTLY 16 fixed HP who attacks as a 3 HD monster while retaining normal weapon damage +1; this does not execute in four-Gnoll GNOLL-T001.',
  NULL,
  N'{"future_fixture":"GNOLL-T002","group_size":20,"leader_count":1,"leader_hp":16,"leader_attack_tier":"3 HD"}',
  N'AIDM-DES-001.7',
  NULL,
  N'Defined pending separate GNOLL-T002 leadership encounter, without inventing leader in GNOLL-T001.'),
 (N'GNOLL-T001',
  N'GNOLL-E01',
  7,
  N'Normal independent surprise by side',
  N'ENCOUNTER',
  N'Specified',
  1,
  N'Party rolls surprise 1d6=3; Gnoll side rolls 1d6=5.',
  N'Neither side surprised on normal 1-2 threshold; one die per side and no Gnoll-specific surprise modifier.',
  N'{"party_d6":[3],"gnolls_d6":[5]}',
  NULL,
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-E02',
  8,
  N'Robbery and intimidation allow player choices',
  N'ENCOUNTER',
  N'Specified',
  1,
  N'Four armed, hostile Gnolls confront the player party, and a player proposes bargaining, withdrawal, intimidation or evasive action.',
  N'Encounter may interpret a threat or robbery demand, adjudicates the proposed player choice and retains uncertain outcome; it must not force immediate combat or guaranteed peaceful parley.',
  NULL,
  N'{"behaviour":["bully","steal","threaten","extort"],"source":"Mentzer qualitative text"}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-E03',
  9,
  N'Encounter validates actual Gnoll weapon loadout',
  N'ENCOUNTER',
  N'Specified',
  1,
  N'The species can use any weapon, but Mentzer names no compulsory Gnoll weapon.',
  N'Encounter supplies individual approved equipped weapon references before executable Combat; Combat reads the supplied damage expression rather than inventing a universal Gnoll 1d6 weapon.',
  NULL,
  N'{"default_weapon":null,"require_validated_equipment":true}',
  N'AIDM-DES-001.7',
  NULL,
  NULL),
 (N'GNOLL-T001',
  N'GNOLL-E04',
  10,
  N'No invented morale bonus or special surprise',
  N'ENCOUNTER',
  N'Specified',
  1,
  N'Gnoll Morale is 8, no leader present, and no specialist stealth trait appears in the Gnoll entry.',
  N'Use Morale 8; do not invent leader-based morale aura, chameleon surprise or a forced fight. Leader one-per-twenty applies only to qualifying counts.',
  NULL,
  N'{"morale":8,"leader_count":0,"special_surprise":false}',
  N'AIDM-DES-001.7',
  NULL,
  NULL);
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
 PRINT CONCAT(N'Inserted ',@Inserted,N' Gnoll test definitions; no execution.');
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],
       [TestPhase],[TestStatus]
FROM [Test].[MonsterTestCase]
WHERE [ScenarioCode]=N'GNOLL-T001'
ORDER BY [SequenceNo];
GO
