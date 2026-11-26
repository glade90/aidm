/*
 Golden Braid AIDM | BON AIDM-DES-004.2 | manual Functional UAT v1.0
 Two manual LIVE cases only; source Airtable DES-004.2 requirements,
 OneNote DES-004 ADR-004-01..07, main docs/COMBAT_AGENT_004_2.md.
 First slice: existing per-human-decision CombatAgent + verified narration.
 Whole-party planning, graph retargeting, exceptional PAUSE, conditions and
 Bookkeeper are separately scoped, not tested here.
 Idempotent seed. No execution records or PASS assertions.
*/
USE [DnD_Test];
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'Test.UATTestScenario',N'U') IS NULL
    OR OBJECT_ID(N'Test.UATTestCase',N'U') IS NULL
    OR OBJECT_ID(N'Test.UATTestExecution',N'U') IS NULL
     THROW 56901, 'Unified DnD_Test.Test tables missing.', 1;

 DECLARE @scenario NVARCHAR(128)=N'STORY:AIDM-DES-004.2';
 IF EXISTS (SELECT 1 FROM Test.UATTestScenario
            WHERE ScenarioCode=@scenario AND ScenarioKind<>N'STORY')
     THROW 56902, 'Conflicting scenario type; review manually.', 1;
 IF NOT EXISTS (SELECT 1 FROM Test.UATTestScenario WHERE ScenarioCode=@scenario)
 INSERT INTO Test.UATTestScenario
  (ScenarioCode,ScenarioName,ScenarioKind,FixtureRevision,
   SpecificationStatus,ReadyForExecution,OriginReference,Notes)
 VALUES
  (@scenario,N'DES-004.2 live CombatAgent manual acceptance',N'STORY',1,
   N'Specified',0,N'Airtable AIDM-DES-004.2; OneNote DES-004; docs/COMBAT_AGENT_004_2.md',
   N'Existing canonical 3v3. Real model required. No B1 loader or full party-round planner.');

 DECLARE @spec TABLE (
  TestCaseCode NVARCHAR(80) PRIMARY KEY, SequenceNo INT,
  TestName NVARCHAR(180), TestArea NVARCHAR(60),
  GivenText NVARCHAR(MAX), WhenText NVARCHAR(MAX), ExpectedText NVARCHAR(MAX));
 INSERT INTO @spec
 (TestCaseCode,SequenceNo,TestName,TestArea,GivenText,WhenText,ExpectedText)
 VALUES
 (N'AIDM-DES-004.2-UAT-01', 1, N'Complete LIVE 3v3 combat and verified narration', N'LiveCombat', N'PEQUOD live LLM configured in development, approved existing 3v3 Alho/Evro/Sho versus Orcs fixture, clean tested Git SHA and known initial HP and event log. Existing per-human-decision browser interface is acceptable for this first Build.', N'Play at least two rounds and continue through a complete terminal encounter using natural-language attacks and targets, e.g. ''I thrust my sword at the second orc''. Inspect provider evidence, public event journal, completed-round specialist narration and terminal state.', N'Actual provider-backed specialist CombatAgent interprets combat-specific intentions through the single DM gateway. Deterministic Engine controls initiative, rolls, legality, damage, HP and result. Public log, state and each completed-round narrative agree; no invented hits, casualties or hidden monster facts, no routine second DM narrative rewrite. Save one full transcript and event receipt set. No new party-round planner, spatial graph, spell or condition mechanics required.'),
(N'AIDM-DES-004.2-UAT-02', 2, N'Invalid intent fails closed; valid recovery and VIEW_LOG read-only', N'LiveSafety', N'Fresh live-model 3v3 session on same tested SHA, note initial HP, round and journal.', N'Submit one plainly impossible target/action (e.g. attack a nonexistent orc), inspect state, submit a valid attack, then request VIEW_LOG and compare journal, HP and round.', N'Unsupported/invalid proposal is rejected or elicits meaningful clarification without a roll, change in HP or advancing the round. Subsequent valid attack follows normal Engine rules and is not duplicated. VIEW_LOG neither changes state nor triggers another narration/model round, and public projection does not leak hidden enemy state. Capture rejected response and before/after evidence.');

 -- Never silently change an existing TestRevision=1 oracle.
 IF EXISTS (
  SELECT 1 FROM @spec v
  JOIN Test.UATTestCase c
    ON c.ScenarioCode=@scenario AND c.TestCaseCode=v.TestCaseCode AND c.TestRevision=1
  WHERE ISNULL(c.LinkedStoryRef,N'')<>N'AIDM-DES-004.2'
     OR c.TestName<>v.TestName OR c.GivenText<>v.GivenText
     OR ISNULL(c.WhenText,N'')<>v.WhenText OR c.ExpectedText<>v.ExpectedText
 )
     THROW 56903, 'Existing case definition conflicts: create a new TestRevision.', 1;

 INSERT INTO Test.UATTestCase
 (ScenarioCode,TestCaseCode,TestRevision,LinkedStoryRef,SequenceNo,
  TestName,TestArea,GivenText,WhenText,ExpectedText,
  FixtureMode,SpecificationStatus,ReadyForExecution,Notes)
 SELECT @scenario,v.TestCaseCode,1,N'AIDM-DES-004.2',v.SequenceNo,
        v.TestName,v.TestArea,v.GivenText,v.WhenText,v.ExpectedText,
        N'LIVE',N'Specified',0,
        N'BON manual test; source SHA and real outcome belong in UATTestExecution.'
 FROM @spec v
 WHERE NOT EXISTS (
  SELECT 1 FROM Test.UATTestCase c
   WHERE c.ScenarioCode=@scenario AND c.TestCaseCode=v.TestCaseCode AND c.TestRevision=1
 );
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
SELECT TestCaseCode,TestName,FixtureMode,SpecificationStatus,
       ReadyForExecution,TestRevision
FROM Test.UATTestCase
WHERE LinkedStoryRef=N'AIDM-DES-004.2'
ORDER BY SequenceNo,TestRevision;
GO
