/*
 BON UAT-02 retest, 26 Nov 2026, qualified functional PASS.
 Append only; preserve original UAT-02 Blocked and UAT-01 Fail/Pass.
 Run only after checking live service /status exact clean source SHA.
*/
USE [DnD_Test];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Scenario nvarchar(128)=N'STORY:AIDM-DES-004.2';
DECLARE @Case nvarchar(80)=N'AIDM-DES-004.2-UAT-02';
DECLARE @Sha char(40)='0db68965d70f5e37fe299bf40e50b6c48975a2de';
DECLARE @Group nvarchar(120)=N'DES-004.2-20261126-LIVE-RETEST-02';
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS (SELECT 1 FROM Test.UATTestExecution WHERE ExecutionId=2 AND ScenarioCode=@Scenario AND TestCaseCode=@Case AND TestRevision=1 AND ResultStatus=N'Blocked' AND SourceSha='3894e6e837d9d9d4c104e76ce613ac02b9abbbc4')
  THROW 56924,'Original UAT-02 Blocked record not found or inconsistent.',1;
 IF NOT EXISTS (SELECT 1 FROM Test.UATTestExecution WHERE ExecutionId=1 AND ScenarioCode=@Scenario AND TestCaseCode=N'AIDM-DES-004.2-UAT-01' AND ResultStatus=N'Fail')
  THROW 56925,'Original UAT-01 failure not found.',1;
 IF NOT EXISTS (SELECT 1 FROM Test.UATTestExecution WHERE ScenarioCode=@Scenario AND TestCaseCode=N'AIDM-DES-004.2-UAT-01' AND TestRevision=1 AND RunGroupCode=N'DES-004.2.1-20261126-LIVE-RETEST-01' AND SourceSha=@Sha AND ResultStatus=N'Pass')
  THROW 56926,'Qualified UAT-01 retest receipt missing.',1;
 IF EXISTS (SELECT 1 FROM Test.UATTestExecution WITH(UPDLOCK,HOLDLOCK) WHERE RunGroupCode=@Group AND (ScenarioCode<>@Scenario OR TestCaseCode<>@Case OR TestRevision<>1 OR ISNULL(SourceSha,'')<>@Sha OR ResultStatus<>N'Pass'))
  THROW 56927,'Conflicting retest run group; review manually.',1;
 IF NOT EXISTS (SELECT 1 FROM Test.UATTestExecution WITH(UPDLOCK,HOLDLOCK) WHERE RunGroupCode=@Group AND ScenarioCode=@Scenario AND TestCaseCode=@Case AND TestRevision=1)
 INSERT INTO Test.UATTestExecution
 (ScenarioCode,TestCaseCode,TestRevision,RunGroupCode,TestedBy,EnvironmentName,SourceSha,ExecutionMode,ResultStatus,ObservedText,EvidenceRef,Notes)
 VALUES
 (@Scenario,@Case,1,@Group,N'BON',N'PEQUOD Development v0.2.0',@Sha,N'LIVE',N'Pass',
 N'QUALIFIED PASS — observable functional safety and recovery, not independent provider-call proof.
 Fresh 3v3 reset, Live LLM enabled. Baseline Round 1 MELEE, party initiative 6 vs orcs 5, all party HP 8/8,8/8,9/9; Alho pending. Journal: 1 PRE_INITIATIVE round begins; 2 initiative party wins; 3 morale disabled; 4 stationary movement; 5 missile disabled; 6 magic disabled; 7 MELEE ready; 8 Alho awaits decision. No attacks yet.
 Player: Alho attacks the seventh orc.
 DM: I couldn''t identify a single legal target. Choose from Orc 1, Orc 2, Orc 3 by name or number, or HOLD. Alho remains pending. Screenshot at 23:26 shows party HP 8/8,8/8,9/9; separately supplied complete post-rejection journal events 1-8 match baseline. No additional recorded dice, HP change, phase/round advancement or attack.
 Player: Alho thrusts her sword at the second orc.
 DM: Alho hits Orc 2 for 5 damage. Orc 2 falls. Evro hits Orc 1 for 9 damage. Orc 1 falls. Sho-Rembo: choose a melee attack target (Orc 3) by name or number, or say HOLD. NEEDS PLAYER INPUT.
 Recovery journal: original 1-8 retained; 9 Alho hits Orc2 d20 15+0=15, damage die 5+0=5, Orc2 falls; 10 Evro hits Orc1 d20 19+3=22, damage die 6+3=9, Orc1 falls; 11 Sho-Rembo awaits decision. Party HP 8/8,8/8,9/9; exactly one Alho and one Evro action, no duplicate mechanical event. Only Orc3 offered as legal target.
 VIEW_LOG: owner supplied screenshot at 23:30 in response to final log check. Visible journal tail events 5-11 identical, event 11 last, Sho pending, Round 1 MELEE; no extra visible events. Screenshot does not show HP header or whole chat, so cannot independently recheck post-log HP header or complete narrative count. No hidden state leakage observed in supplied player projection. No additional attack submitted.',
 N'https://github.com/glade90/aidm/actions/runs/45904976495',
 N'Original execution 2 Blocked retained; prior UAT-01 Fail and qualified retest Pass retained. BON independently reviewed exact clean regression SHA, 620 JUnit PASS, 94.70% coverage, 19 Node PASS, 38 focused PASS. Same live-enabled runtime as prior retest, runtime identity to be verified immediately before executing this script. No direct provider request IDs, no internal model-call count or full state snapshot; daily OpenAI usage screenshot corroborates account activity only, not specific requests. Automated tests support read-only log/no extra call; DES-035.4 tracks real provider receipts. This qualified result addresses the original missing pre/post invalid-action evidence; parent acceptance remains ALEK decision. No claim of full independent provider evidence. Actual time separately confirmed by owner if applicable.');
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
SELECT ExecutionId,TestCaseCode,ResultStatus,SourceSha,DefectRef
FROM Test.UATTestExecution WHERE ScenarioCode=@Scenario
ORDER BY ExecutionId;
GO
