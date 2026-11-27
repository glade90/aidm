/* BON 27 Nov 2026: six manual UAT definitions + initial independent review outcomes.
Writes ONLY DnD_Test.Test UAT registry. No DnD changes or migrations. */
USE [DnD_Test];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @S nvarchar(128)=N'STORY:AIDM-DES-001.7.9';
DECLARE @Story nvarchar(80)=N'AIDM-DES-001.7.9';
DECLARE @SHA char(40)='08928fc4edd040495e1f50c79ebac02b5da01b96';
DECLARE @Run nvarchar(120)=N'DES-001.7.9-20261127-BON-REVIEW-01';
DECLARE @T TABLE (Suffix nvarchar(2),Name nvarchar(180),Mode nvarchar(20),Area nvarchar(60),GivenText nvarchar(max),WhenText nvarchar(max),ExpectedText nvarchar(max),Observed nvarchar(max));
INSERT @T VALUES
(N'01',N'Catalogue field fidelity',N'LIVE',N'B01 B04',N'Four live SourceChecked 2026-11-21 DnD species; SELECT-only principal.',N'Compare raw SQL rows to typed snapshots, including distinct description/attack/encounter prose and dimensions, source/image references.',N'All required fields equal canonical live rows; nulls preserved; no flag change.',N'BLOCKED: exact implementation reviewed; independent PEQUOD SQL comparison pending.'),
(N'02',N'Approval, version and lookup gates',N'MIXED',N'B02 B03',N'Four unapproved rows; isolated fake provider for negative inputs.',N'Try ordinary and exact-version lookups, missing/duplicate/unknown/unsafe keys.',N'Unapproved draft inaccessible normally; explicit test-only retrieval only; no silent version substitution or unbounded keys.',N'BLOCKED: source gates inspected; independent real and synthetic runtime checks pending.'),
(N'03',N'Normalized scenario and case readiness',N'LIVE',N'B05 addenda',N'DnD.Test ORC-T001-A and normalized children.',N'Compare five ordered case rows and attempt normal resolve and handoff.',N'Specified and ReadyForExecution=0; five normalized children, no execution or approval; unready handoff rejected.',N'BLOCKED: schema and implementation reviewed; independent PEQUOD observations pending.'),
(N'04',N'Pinned roster offline Combat',N'SYNTHETIC',N'B05 B06 B08',N'Two independently authored synthetic approved fixture rosters, same species date, different HP, explicit scene and mechanics receipt.',N'Resolve snapshots; disconnect fake provider; run actual Meta START, ACTION and RESET for each.',N'Distinct instance HP; shared source pin; no SQL after resolution; correct state progression/reset.',N'BLOCKED: source seam reviewed; full runtime unavailable in connector-only environment; independent owner harness pending.'),
(N'05',N'Incomplete and unsupported mechanics',N'SYNTHETIC',N'B05 B06 B08',N'Trusted synthetic handoff with deliberately invalid variants.',N'Attempt special attacks, leader role, missing stats, wrong version, missing HP, false capability or unapproved scene.',N'Each refused before combat creation; no silent weakening or substitution.',N'BLOCKED: fail-closed checks inspected; independent runtime negative harness pending.'),
(N'06',N'Integration, information safety and read-only boundary',N'MIXED',N'B01 B03 B07 B08',N'Exact source, fake driver, original 3v3 and five disabled B1 IDs.',N'Exercise reader guard, redacted errors, asset projection, original Meta contract and blocked B1 IDs.',N'No arbitrary write-capable SQL reaches driver; no secrets/hidden data; original 3v3 and disabled B1 contract preserved.',N'FAIL: exact SqlServerReader excerpt independently executed with fake cursor only. SELECT-prefixed batch containing DELETE and SELECT INTO reached fake driver. No real DB writes. Direct non-SELECT blocked; timeout, bound params, cleanup, error redaction and public asset projection passed isolated excerpt tests. Remaining full app checks pending. Defect DES-001.7.9.1.');
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'Test.UATTestScenario',N'U') IS NULL OR OBJECT_ID(N'Test.UATTestCase',N'U') IS NULL OR OBJECT_ID(N'Test.UATTestExecution',N'U') IS NULL THROW 56931,'Existing UAT registry required; do not migrate during UAT.',1;
 IF EXISTS (SELECT 1 FROM Test.UATTestCase WHERE LinkedStoryRef=@Story AND (ScenarioCode<>@S OR TestRevision<>1 OR TestCaseCode NOT IN(SELECT @Story+N'-UAT-'+Suffix FROM @T))) THROW 56932,'Existing UAT cases require reconciliation; no duplicate seeds.',1;
 IF EXISTS (SELECT 1 FROM Test.UATTestScenario WHERE ScenarioCode=@S AND ScenarioKind<>N'STORY') THROW 56933,'Conflicting scenario.',1;
 IF NOT EXISTS (SELECT 1 FROM Test.UATTestScenario WHERE ScenarioCode=@S)
 INSERT Test.UATTestScenario(ScenarioCode,ScenarioName,ScenarioKind,FixtureRevision,SpecificationStatus,ReadyForExecution,OriginReference,Notes)
 VALUES(@S,N'DES-001.7.9 independent catalogue and roster UAT',N'STORY',1,N'Specified',0,N'Airtable B01-B08; docs/MONSTER_CATALOGUE_PROVIDER.md',N'Six manual checks; read-only source fixtures remain unapproved.');
 IF EXISTS (SELECT 1 FROM @T t JOIN Test.UATTestCase c ON c.ScenarioCode=@S AND c.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND c.TestRevision=1 WHERE c.TestName<>t.Name OR c.ExpectedText<>t.ExpectedText OR c.GivenText<>t.GivenText OR ISNULL(c.WhenText,N'')<>t.WhenText) THROW 56934,'Existing UAT revision conflicts; review manually.',1;
 INSERT Test.UATTestCase(ScenarioCode,TestCaseCode,TestRevision,LinkedStoryRef,SequenceNo,TestName,TestArea,GivenText,WhenText,ExpectedText,FixtureMode,SpecificationStatus,ReadyForExecution)
 SELECT @S,@Story+N'-UAT-'+t.Suffix,1,@Story,CONVERT(int,t.Suffix),t.Name,t.Area,t.GivenText,t.WhenText,t.ExpectedText,t.Mode,N'Specified',0 FROM @T t WHERE NOT EXISTS(SELECT 1 FROM Test.UATTestCase c WHERE c.ScenarioCode=@S AND c.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND c.TestRevision=1);
 INSERT Test.UATTestExecution(ScenarioCode,TestCaseCode,TestRevision,RunGroupCode,TestedBy,EnvironmentName,SourceSha,ExecutionMode,ResultStatus,ObservedText,EvidenceRef,DefectRef,Notes)
 SELECT @S,@Story+N'-UAT-'+t.Suffix,1,@Run,N'BON',N'Independent connector/source review and isolated fake-driver Python',@SHA,CASE WHEN t.Suffix=N'06' THEN N'SYNTHETIC' ELSE t.Mode END,CASE WHEN t.Suffix=N'06' THEN N'Fail' ELSE N'Blocked' END,t.Observed,N'https://github.com/glade90/aidm/blob/08928fc4edd040495e1f50c79ebac02b5da01b96/aidm/catalogue.py',CASE WHEN t.Suffix=N'06' THEN N'AIDM-DES-001.7.9.1' END,N'Developer CI verified separately: 717 JUnit, 93.48%, 22 Node, 38 CI focused. No independent live SQL or full application execution yet. Excerpt fingerprints fbc6b73b and c017f7fe; no real SQL driver used.'
 FROM @T t WHERE NOT EXISTS(SELECT 1 FROM Test.UATTestExecution e WITH(UPDLOCK,HOLDLOCK) WHERE e.ScenarioCode=@S AND e.TestCaseCode=@Story+N'-UAT-'+t.Suffix AND e.RunGroupCode=@Run);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
SELECT ExecutionId,TestCaseCode,ResultStatus,SourceSha,DefectRef FROM Test.UATTestExecution WHERE ScenarioCode=@S ORDER BY ExecutionId;
GO
