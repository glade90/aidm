/* Owner executed BON independent harness on PEQUOD, 27 Nov 2026.
Append-only actual results, after the 07 seed. No source DB changes. */
USE [DnD_Test];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @S nvarchar(128)=N'STORY:AIDM-DES-001.7.9';
DECLARE @Story nvarchar(80)=N'AIDM-DES-001.7.9';
DECLARE @SHA char(40)='08928fc4edd040495e1f50c79ebac02b5da01b96';
DECLARE @Run nvarchar(120)=N'DES-001.7.9-20261127-BON-PEQUOD-01';
DECLARE @T TABLE(Suffix nvarchar(2),Mode nvarchar(20),Result nvarchar(20),Observed nvarchar(max));
INSERT @T VALUES
(N'01',N'LIVE',N'Blocked',N'Local pyodbc/config unavailable; no live lookup performed.'),
(N'02',N'MIXED',N'Blocked',N'Local pyodbc/config unavailable; combined live approval/version test not executed.'),
(N'03',N'LIVE',N'Blocked',N'Local pyodbc/config unavailable; no live scenario lookup performed.'),
(N'04',N'SYNTHETIC',N'Pass',N'BON-A and BON-B pinned MentzerBECMI ORC 2026-11-21; distinct initial HP (7,5,2) and (2,7,5). Actual Meta START, ACTION NEEDS_PLAYER_INPUT, RESET restored matching HP for both, TEST_ONLY; zero provider calls after deliberate disconnect.'),
(N'05',N'SYNTHETIC',N'Pass',N'All seven independently specified negative variants refused: special, leader, missing-core, wrong-version, missing-HP, unapproved-scene, unsupported-mechanics.'),
(N'06',N'SYNTHETIC',N'Fail',N'Original synthetic Meta START/ACTION/RESET passed. All five B1 IDs b1.stock.12, .15, .16, .20, .25 BLOCKED. Safe asset and redacted fake-driver checks completed; write-capable SQL reader guard defect DES-001.7.9.1 reproduced using fake cursor only. No real database writes.');
BEGIN TRY
 BEGIN TRANSACTION;
 IF (SELECT COUNT(*) FROM Test.UATTestCase WHERE ScenarioCode=@S AND TestRevision=1 AND TestCaseCode IN(SELECT @Story+N'-UAT-'+Suffix FROM @T))<>6
 THROW 56941,'Run 07 seed first; six existing UAT definitions required.',1;
 IF EXISTS(SELECT 1 FROM @T t JOIN Test.UATTestExecution e ON e.ScenarioCode=@S AND e.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND e.RunGroupCode=@Run WHERE e.TestRevision<>1 OR ISNULL(e.SourceSha,'')<>@SHA OR e.ResultStatus<>t.Result OR e.ObservedText<>t.Observed)
 THROW 56942,'Conflicting execution record; review manually.',1;
 INSERT Test.UATTestExecution(ScenarioCode,TestCaseCode,TestRevision,RunGroupCode,TestedBy,EnvironmentName,SourceSha,ExecutionMode,ResultStatus,ObservedText,EvidenceRef,DefectRef,Notes)
 SELECT @S,@Story+N'-UAT-'+Suffix,1,@Run,N'BON',N'PEQUOD owner-operated independent BON harness',@SHA,Mode,Result,Observed,N'https://github.com/glade90/aidm/blob/187625a3dcfe050f4d676046af8533b80d5bb26f/Database/migrations/uat_three_table/bon_des_001_7_9_uat.py',CASE WHEN Suffix=N'06' THEN N'AIDM-DES-001.7.9.1' END,N'Owner terminal BON_RECEIPT supplied exact clean SHA. Developer CI separate. 01-03 setup blocked; 04-05 independent synthetic PASS; 06 integration passed but reader boundary failed. No DnD source mutations or approvals.'
 FROM @T t WHERE NOT EXISTS(SELECT 1 FROM Test.UATTestExecution e WITH(UPDLOCK,HOLDLOCK) WHERE e.ScenarioCode=@S AND e.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND e.RunGroupCode=@Run);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
SELECT ExecutionId,TestCaseCode,RunGroupCode,ResultStatus,SourceSha,DefectRef FROM Test.UATTestExecution WHERE ScenarioCode=@S ORDER BY ExecutionId;
GO
