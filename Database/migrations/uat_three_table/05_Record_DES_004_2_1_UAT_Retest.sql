/*
 BON independent Functional UAT, 26 Nov 2026.
 Qualified PASS of DES-004.2.1 narrow narration retest, owner authorised.
 Original parent UAT-01 failure and UAT-02 Blocked retained.
 This records observations supplied via PEQUOD terminal/browser by owner.
 No live provider request-ID or exact provider-side correlation available.
 Execute only on PEQUOD DnD_Test. No schema or specification changes.
*/
USE [DnD_Test];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Scenario nvarchar(128)=N'STORY:AIDM-DES-004.2';
DECLARE @Case nvarchar(80)=N'AIDM-DES-004.2-UAT-01';
DECLARE @Sha char(40)='0db68965d70f5e37fe299bf40e50b6c48975a2de';
DECLARE @Group nvarchar(120)=N'DES-004.2.1-20261126-LIVE-RETEST-01';
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM Test.UATTestExecution WHERE ExecutionId=1 AND ScenarioCode=@Scenario AND TestCaseCode=@Case AND TestRevision=1 AND ResultStatus=N'Fail' AND SourceSha='3894e6e837d9d9d4c104e76ce613ac02b9abbbc4' AND DefectRef=N'AIDM-DES-004.2.1')
  THROW 56921,'Original failure does not match expected evidence; review manually.',1;
 IF NOT EXISTS(SELECT 1 FROM Test.UATTestExecution WHERE ExecutionId=2 AND ScenarioCode=@Scenario AND TestCaseCode=N'AIDM-DES-004.2-UAT-02' AND ResultStatus=N'Blocked')
  THROW 56922,'Original UAT-02 Blocked record does not match; review manually.',1;
 IF EXISTS(SELECT 1 FROM Test.UATTestExecution WITH(UPDLOCK,HOLDLOCK)
  WHERE RunGroupCode=@Group AND (ScenarioCode<>@Scenario OR TestCaseCode<>@Case OR TestRevision<>1 OR ISNULL(SourceSha,'')<>@Sha OR ResultStatus<>N'Pass'))
  THROW 56923,'Conflicting retest run group; review manually.',1;
 IF NOT EXISTS(SELECT 1 FROM Test.UATTestExecution WITH(UPDLOCK,HOLDLOCK)
  WHERE RunGroupCode=@Group AND ScenarioCode=@Scenario AND TestCaseCode=@Case AND TestRevision=1)
 INSERT INTO Test.UATTestExecution
 (ScenarioCode,TestCaseCode,TestRevision,RunGroupCode,TestedBy,EnvironmentName,
  SourceSha,ExecutionMode,ResultStatus,ObservedText,EvidenceRef,DefectRef,Notes)
 VALUES
 (@Scenario,@Case,1,@Group,N'BON',N'PEQUOD Development v0.2.0',@Sha,N'LIVE',N'Pass',
 N'QUALIFIED PASS: narrow DES-004.2.1 narration defect retest, not blanket parent acceptance.
 Runtime /status READY, version 0.2.0, build dev-0db68965d70f, exact SHA, dirty=false. Startup used configured gpt-4.1-mini; UI Live LLM enabled. Owner operated browser; BON reconciled supplied evidence.
 Four rounds, 80 journal events, PARTY_VICTORY; final Alho 8/8, Evro 1/8, Sho-Rembo 9/9. Four clean prose narratives (three nonterminal, one terminal), no raw JSON, factual consistency with journal.

 TRANSCRIPT AND JOURNAL RECEIPT (player text verbatim; relevant journal events condensed):
 R1 player: Alho thrusts her sword at the second orc. | Sho swings her axe at the third orc.
 Journal 1 round begins; 2 initiative party 3 orcs 5; 3-7 phases; 8 Orc1 misses Evro d20 12; 9 Orc2 hits Evro d20 20 damage 5; 10 Orc3 hits Evro d20 19 damage 2; 11-15 phases; 16 Alho awaits; 17 Alho misses Orc2 d20 5; 18 Evro misses Orc1 d20 4+3=7; 19 Sho awaits; 20 Sho misses Orc3 d20 11; 21 round ends; 22 R2 begins; 23 initiative party 6 orcs 1; 24-28 phases; 29 Alho awaits.
 Narrative: The orcs seize the initiative in the first round, striking hard with two landing blows on Evro, while the party''s attacks fail to connect.
 VIEW_LOG before/after: 29 events, HP 8/1/9, round 2 MELEE, pending Alho, unchanged transcript, no additional visible narrative.
 R2 player: Alho attacks orc 1 | Sho attackz orc 2
 Journal 30 Alho misses Orc1 d20 11; 31 Evro misses Orc1 d20 1+3=4; 32 Sho awaits; 33 Sho misses Orc2 d20 2; 34-38 phases; 39 Orc1 misses Evro d20 13; 40 Orc2 misses Evro d20 4; 41 Orc3 misses Evro d20 1; 42 round ends; 43 R3 begins; 44 initiative 3:3 simultaneous; 45-49 phases; 50 Alho awaits; 51 Sho awaits.
 Narrative: Round 2 begins with the party winning initiative and acting first. Despite their efforts, Alho, Evro, and Sho-Rembo all miss their attacks against the orcs. The orcs retaliate but fail to hit Evro with any of their strikes.
 R3 player: 1 | 2
 Journal 52-56 phases; 57 Alho misses Orc1 d20 11; 58 Evro hits Orc1 d20 20+3=23 damage 6+3=9; 59 Sho hits Orc2 d20 15 damage 4; 60 Orc1 misses Evro d20 3; 61 Orc2 misses Evro d20 14; 62 Orc3 misses Evro d20 10; 63 simultaneous exchange resolves Orc1 and Orc2 fall; 64 round ends; 65 R4 begins; 66 initiative party 1 orcs 5; 67-71 phases; 72 Orc3 misses Evro d20 7; 73-77 phases; 78 Alho awaits.
 Narrative: Round 3 begins with both sides acting simultaneously. Alho misses Orc 1, while Evro lands a heavy blow dealing 9 damage. Sho-Rembo strikes Orc 2 for 4 damage. In retaliation, Orcs 1, 2, and 3 all miss Evro. The exchange concludes with Orcs 1 and 2 falling.
 R4 player: 3 obviously
 Journal 79 Alho hits Orc3 d20 18 damage 6, Orc3 falls; 80 Combat ends: PARTY_VICTORY.
 Narrative: Round 4 begins with the orcs taking the initiative, but Orc 3 misses its attack on Evro. Alho strikes back decisively, hitting Orc 3 for 6 damage and defeating it. The combat ends with the party emerging victorious.
 Terminal log check: final event 80, outcome and HP 8/1/9 unchanged. Further input 3 returned Combat has ended. View the log for the outcome. BLOCKED. No additional visible battle narrative. Not an identical request-ID replay test.
 Phase entries above were scenario-disabled morale/missile/magic, stationary movement and ready melee. Full browser transcript and journal supplied in BON conversation; this is a condensed evidence receipt.',
 N'https://github.com/glade90/aidm/actions/runs/45904976495',
 N'AIDM-DES-004.2.1',
 N'Original failure ExecutionId 1 preserved; parent UAT-02 ExecutionId 2 remains Blocked. Owner authorised qualified defect PASS. BON independently checked PR #28 diff, GitHub Actions exact SHA clean regression 620 JUnit PASS, 94.70% coverage, 19 Node PASS, 38 focused PASS. Offline scripted gateway tests support no duplicate VIEW_LOG call and safe malformed fallback; no direct manual identical-request-ID replay. Owner supplied OpenAI Usage dashboard screenshot at 22:57 local on 26 Nov: Maestro filter, all API keys/sources, 1-day aggregation, nonzero daily expenditure under $0.01. Model-specific stats unavailable; association of Maestro with AIDM not separately confirmed, no per-call correlation or provider response/request IDs. This corroborates real account usage that day only, not definitive evidence of these exact requests. Live-enabled runtime and gameplay plus provider usage accepted by owner for narrow defect retest, not full independent provider verification or parent acceptance. Follow-up DES-035.4 created. No additional mechanics scope. Actual time pending owner confirmation.');
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
SELECT ExecutionId,TestCaseCode,ResultStatus,SourceSha,DefectRef
FROM Test.UATTestExecution
WHERE ExecutionId IN(1,2) OR RunGroupCode=@Group
ORDER BY ExecutionId;
GO
