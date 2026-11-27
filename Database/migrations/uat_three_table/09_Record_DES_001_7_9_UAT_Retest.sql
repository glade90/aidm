/* BON independent PEQUOD retest receipts, 27 Nov 2026.
Append only to DnD_Test; preserve original failure and 04/05 historical passes. */
USE [DnD_Test];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @S nvarchar(128)=N'STORY:AIDM-DES-001.7.9';
DECLARE @Story nvarchar(80)=N'AIDM-DES-001.7.9';
DECLARE @SHA char(40)='ffe5b67e12141edb22a2135d3df9100e7a4a09a7';
DECLARE @Run nvarchar(120)=N'DES-001.7.9-20261127-BON-PEQUOD-RETEST';
DECLARE @T TABLE(Suffix nvarchar(2),Mode nvarchar(20),Observed nvarchar(max),Evidence nvarchar(500));
INSERT @T VALUES
(N'01',N'LIVE',N'Actual dedicated Windows reader; catalogue/probe SHA256 match and read-only permission attestation passed. Four 2026-11-21 SourceChecked inactive species ORC, GIANT_CENTIPEDE, CARRION_CRAWLER, GIANT_CRAB_SPIDER; 32 exact mapped fields each (128 comparisons), separate general/attack/encounter prose digests and dimensions verified.',N'https://github.com/glade90/aidm/blob/36e36c4a2f3f398264c0a15171384ed28c303eed/Database/migrations/uat_three_table/bon_des_001_7_9_live_retest.py'),
(N'02',N'MIXED',N'Four drafts refused in normal mode; exact missing, duplicate and unsafe lookup gates verified. No source approval or readiness changes.',N'https://github.com/glade90/aidm/blob/36e36c4a2f3f398264c0a15171384ed28c303eed/Database/migrations/uat_three_table/bon_des_001_7_9_live_retest.py'),
(N'03',N'LIVE',N'ORC-T001-A Specified, ReadyForExecution=0; five normalized Specified COMBAT children ORC-T01, T02, T03, T04, T06 ordered 1-5; normal resolution and handoff refused; independent field comparisons passed.',N'https://github.com/glade90/aidm/blob/36e36c4a2f3f398264c0a15171384ed28c303eed/Database/migrations/uat_three_table/bon_des_001_7_9_live_retest.py'),
(N'06',N'SYNTHETIC',N'Clean exact source. Original synthetic Meta START/ACTION/RESET, safe asset projection and all five B1 gates passed (stock 12,15,16,20,25 remain BLOCKED). Unsafe SQL refused before fake cursor execution; valid reviewed query driver failure sanitized and cleanup checked. DES-001.7.9.1 independently retested PASS. No actual database writes.',N'https://github.com/glade90/aidm/blob/b39207c85cefe37f277cfb5fd4e4aabb9796ca02/Database/migrations/uat_three_table/bon_des_001_7_9_guard_retest.py');
BEGIN TRY
 BEGIN TRANSACTION;
 IF (SELECT COUNT(*) FROM Test.UATTestCase WHERE ScenarioCode=@S AND TestRevision=1 AND TestCaseCode IN(SELECT @Story+N'-UAT-'+Suffix FROM @T))<>4 THROW 56951,'Run 07 seed first.',1;
 IF EXISTS(SELECT 1 FROM @T t JOIN Test.UATTestExecution e ON e.ScenarioCode=@S AND e.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND e.RunGroupCode=@Run WHERE e.TestRevision<>1 OR ISNULL(e.SourceSha,'')<>@SHA OR e.ResultStatus<>N'Pass' OR e.ObservedText<>t.Observed) THROW 56952,'Conflicting retest receipt; review manually.',1;
 INSERT Test.UATTestExecution(ScenarioCode,TestCaseCode,TestRevision,RunGroupCode,TestedBy,EnvironmentName,SourceSha,ExecutionMode,ResultStatus,ObservedText,EvidenceRef,DefectRef,Notes)
 SELECT @S,@Story+N'-UAT-'+Suffix,1,@Run,N'BON',N'PEQUOD owner-operated independent BON retest',@SHA,Mode,N'Pass',Observed,Evidence,CASE WHEN Suffix=N'06' THEN N'AIDM-DES-001.7.9.1' END,CASE WHEN Suffix=N'06' THEN N'Owner BON_RECEIPT on clean exact source, fake driver only.' ELSE N'Owner BON_RECEIPT under actual restricted reader. Interactive attestation SHA256 F8E07ED4FD9A6A197A56C59DC6B0231D8C95150C844374F510DBFECD7BDB5A29. Scheduled task not proved.' END
 FROM @T t WHERE NOT EXISTS(SELECT 1 FROM Test.UATTestExecution e WITH(UPDLOCK,HOLDLOCK) WHERE e.ScenarioCode=@S AND e.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND e.RunGroupCode=@Run);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
;WITH Latest AS (
 SELECT ExecutionId,TestCaseCode,ResultStatus,SourceSha,DefectRef,ROW_NUMBER() OVER(PARTITION BY TestCaseCode,TestRevision ORDER BY ExecutionId DESC) AS rn
 FROM Test.UATTestExecution WHERE ScenarioCode=@S AND TestRevision=1
)
SELECT ExecutionId,TestCaseCode,ResultStatus,SourceSha,DefectRef FROM Latest WHERE rn=1 ORDER BY TestCaseCode;
GO
