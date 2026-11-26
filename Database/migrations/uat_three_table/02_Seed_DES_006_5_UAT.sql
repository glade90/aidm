/* AIDM-DES-006.5 BON functional UAT specifications for unified three-table registry.
   ScenarioCode STORY:AIDM-DES-006.5 represents the story's test context.
   NO executions/Pass claimed.
   Safe to rerun; existing case revisions are not overwritten. */
USE [DnD_Test];
GO
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRAN;
IF OBJECT_ID(N'Test.UATTestScenario',N'U') IS NULL
   THROW 56840, 'Unified UAT registry not deployed; run 01_Migrate first.',1;
IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestScenario]
               WHERE ScenarioCode=N'STORY:AIDM-DES-006.5')
    INSERT [Test].[UATTestScenario]
       ([ScenarioCode],[ScenarioName],[ScenarioKind],[SpecificationStatus],
        [ReadyForExecution],[FixtureRevision],[OriginReference],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'DES-006.5 Combat to State condition bridge',
            N'STORY',N'Specified',0,1,N'BON functional UAT plan (Airtable AIDM-DES-006.5)',
            N'Fixture scenarios are explicitly synthetic/mixed/live; this row is not UAT PASS.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-01' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-01',1,N'AIDM-DES-006.5',1,N'Verified POISONED applied to PC',N'Apply',N'Trusted synthetic effect confirms a poison status on one player character.',N'The Combat-to-State bridge receives matching typed proposal and source event.',N'Exactly one POISONED condition instance is created on the correct PC with verified receipt; no HP change is invented.',N'SYNTHETIC',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-02' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-02',1,N'AIDM-DES-006.5',2,N'Verified ASLEEP applied to Orc',N'Apply',N'A distinct trusted synthetic effect validates ASLEEP for a specified Orc.',N'The bridge applies the verified status.',N'Only the targeted Orc receives one ASLEEP instance; other actors remain unchanged and no unsupported sleep mechanics are invented.',N'SYNTHETIC',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-03' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-03',1,N'AIDM-DES-006.5',3,N'Unverified condition proposal rejected',N'Safety',N'Combat Agent requests POISONED or ASLEEP without matching trusted rule evidence, or with mismatching target/code.',N'The proposal is submitted for validation.',N'The bridge reports a safe unsupported/mismatch outcome and does not change any actor condition or HP.',N'SYNTHETIC',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-04' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-04',1,N'AIDM-DES-006.5',4,N'Two independently expiring conditions',N'State',N'One actor has two separately authorised condition instances expiring at game seconds 10 and 20.',N'Both instances are read and queried before time advances.',N'Distinct identities, provenance, and expiry deadlines are preserved without overwriting or collapsing the instances.',N'SYNTHETIC',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-05' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-05',1,N'AIDM-DES-006.5',5,N'First GameClock deadline expires once',N'Expiry',N'The same actor holds two validated conditions due at 10 and 20 seconds.',N'A genuine current-clock verified completion receipt advances elapsed time across 10 seconds.',N'Only the first due condition expires exactly once; the second remains active.',N'SYNTHETIC',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-06' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-06',1,N'AIDM-DES-006.5',6,N'Second deadline across module handoff',N'Expiry',N'The same campaign clock is shared across Combat, Encounter and Expedition and a second condition is due at 20 seconds.',N'The verified shared-clock receipt after handoff crosses the second deadline.',N'Second condition expires once without creating another clock or double-processing the first deadline; blocked if handoff unavailable.',N'MIXED',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-07' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-07',1,N'AIDM-DES-006.5',7,N'Indefinite status persists until authorised removal',N'State',N'A trusted condition instance has no source-validated expiry time.',N'The clock advances and later a properly authorised REMOVE is submitted.',N'There is no invented automatic expiry; removal occurs exactly once after verified authorisation.',N'SYNTHETIC',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-08' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-08',1,N'AIDM-DES-006.5',8,N'Replay, stale version and forged clock rejected',N'Safety',N'Matching action/event is replayed, or wrong version/clock/source event is offered.',N'The same proposal or clock receipt is submitted again or forged.',N'Same verified command returns original receipt; conflicting or untrusted event fails closed with no duplicate status, expiry or leak.',N'MIXED',N'Specified',0,N'BON proposed UAT plan. No execution result claimed.');

IF NOT EXISTS (SELECT 1 FROM [Test].[UATTestCase] WHERE ScenarioCode=N'STORY:AIDM-DES-006.5' AND TestCaseCode=N'AIDM-DES-006.5-UAT-09' AND TestRevision=1)
    INSERT INTO [Test].[UATTestCase]
    ([ScenarioCode],[TestCaseCode],[TestRevision],[LinkedStoryRef],[SequenceNo],[TestName],[TestArea],[GivenText],[WhenText],[ExpectedText],[FixtureMode],[SpecificationStatus],[ReadyForExecution],[Notes])
    VALUES (N'STORY:AIDM-DES-006.5',N'AIDM-DES-006.5-UAT-09',1,N'AIDM-DES-006.5',9,N'Live Combat Agent through verified state to DM',N'EndToEnd',N'A real Combat Session emits a source-verified effect and specialist Combat Agent submits a condition proposal.',N'The verified event passes deterministic validator, shared ConditionStateService and DM-facing narration.',N'The player-safe DM output reflects only committed condition effects, no hidden state or second rewrite; BLOCKED until live source-rule producer and session hookup exist.',N'LIVE',N'Blocked',0,N'BON proposed UAT plan. No execution result claimed.');
COMMIT;
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
THROW;
END CATCH;
GO
SELECT ScenarioCode,TestCaseCode,TestRevision,LinkedStoryRef,SpecificationStatus,ReadyForExecution
FROM [Test].[UATTestCase] WHERE LinkedStoryRef=N'AIDM-DES-006.5'
ORDER BY SequenceNo;
GO