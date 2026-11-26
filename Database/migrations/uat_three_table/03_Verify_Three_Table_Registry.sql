/* Read-only post-migration checks. Execute only AFTER applying 01 and 02. */
USE [DnD_Test];
GO
IF (SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
    WHERE s.name=N'Test')<>3
    THROW 56870, 'DnD_Test.Test must have exactly three tables.',1;
IF OBJECT_ID(N'Test.UATTestScenario',N'U') IS NULL OR
   OBJECT_ID(N'Test.UATTestCase',N'U') IS NULL OR
   OBJECT_ID(N'Test.UATTestExecution',N'U') IS NULL
    THROW 56871, 'Required UAT tables are missing.',1;
GO
SELECT t.name AS TestTable FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name=N'Test' ORDER BY t.name;
SELECT s.ScenarioKind,COUNT_BIG(*) AS ScenarioCount
 FROM Test.UATTestScenario s GROUP BY s.ScenarioKind ORDER BY s.ScenarioKind;
SELECT s.ScenarioKind,COUNT_BIG(*) AS CaseCount
 FROM Test.UATTestCase c
 JOIN Test.UATTestScenario s ON s.ScenarioCode=c.ScenarioCode
 GROUP BY s.ScenarioKind ORDER BY s.ScenarioKind;
SELECT COUNT_BIG(*) AS ExecutionHistoryCount FROM Test.UATTestExecution;
SELECT ScenarioCode,TestCaseCode,TestRevision,TestName,SpecificationStatus,ReadyForExecution
 FROM Test.UATTestCase WHERE LinkedStoryRef=N'AIDM-DES-006.5'
 ORDER BY SequenceNo;
SELECT t.name AS ArchivedTable FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name=N'Legacy' ORDER BY t.name;
-- Foreign-key integrity: expect zero orphaned cases or executions.
SELECT COUNT_BIG(*) AS OrphanCaseCount FROM Test.UATTestCase c
 LEFT JOIN Test.UATTestScenario s ON s.ScenarioCode=c.ScenarioCode
 WHERE s.ScenarioCode IS NULL;
SELECT COUNT_BIG(*) AS OrphanExecutionCount FROM Test.UATTestExecution e
 LEFT JOIN Test.UATTestCase c ON c.ScenarioCode=e.ScenarioCode
    AND c.TestCaseCode=e.TestCaseCode AND c.TestRevision=e.TestRevision
 WHERE c.TestCaseCode IS NULL;
GO