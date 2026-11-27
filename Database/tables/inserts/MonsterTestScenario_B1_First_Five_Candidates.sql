/* AIDM-DES-001.7.12.1 — FIRST FIVE B1 SOURCE CANDIDATES.
   Generated from Database/fixtures/B1_First_Five_Source_Candidates.json.
   BON SOURCE/EDITION/MECHANICS APPROVAL PENDING; DO NOT PROMOTE TO READY.
   TEST ONLY — no schema migration, no fake passed UAT and no autostocking.
   Usage: DBA review BEFORE manually executing in private DnD database.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Test.MonsterTestScenario', N'U') IS NULL
    THROW 57820, 'Test.MonsterTestScenario not deployed; abort', 1;
IF OBJECT_ID(N'Test.MonsterTestCase', N'U') IS NULL
    THROW 57821, 'Test.MonsterTestCase not deployed; abort', 1;
SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;
    -- S12: distinct B1 source option; 4 MAX test actors, not automatic stocking.
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode] = N'B1-S12')
    BEGIN
        INSERT INTO [Test].[MonsterTestScenario]
        ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],
         [FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],
         [MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],
         [SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
        VALUES (N'B1-S12', N'B1 S12 optional stock — Gnolls', N'MentzerBECMI', N'GNOLL', 1, N'Specified', 0, N'TSR 9023 B1 brown-cover printed p.25 / option S12', 4, N'[{"actor_id":"alho","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"evro","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"sho-rembo","hp_start":9,"source":"owner-canonical-3v3-fixture-v1"}]', N'[{"actor_id":"b1-s12-gnoll-01","armor_class":5,"equipment":null,"hp_start":13,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":1,"species":"GNOLL","species_record_date":null},{"actor_id":"b1-s12-gnoll-02","armor_class":5,"equipment":null,"hp_start":7,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":2,"species":"GNOLL","species_record_date":null},{"actor_id":"b1-s12-gnoll-03","armor_class":5,"equipment":null,"hp_start":6,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":3,"species":"GNOLL","species_record_date":null},{"actor_id":"b1-s12-gnoll-04","armor_class":5,"equipment":null,"hp_start":3,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":4,"species":"GNOLL","species_record_date":null}]', N'{"b1_count_max":4,"b1_count_min":1,"selection_policy":"PROVISIONAL_MAXIMUM_TEST_COUNT_NOT_MANDATORY_MODULE_STOCKING","test_selection":4}', NULL, N'{"actual_room_assignment":null,"b1_source_id":"S12","bon_source_approved":false,"equipment":"UNRESOLVED","geometry":"UNRESOLVED","initial_hostility":"UNRESOLVED","module_page":25,"species_record_date":null,"stocking_optional":true,"surprise":"UNRESOLVED","verified_mechanics":false}', NULL, NULL, N'PROVISIONAL B1 source-authentic inventory. All source, approval, rules, equipment, scene and engine gates must pass before ReadyForExecution=1.');
    END
    ELSE IF EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario]
                   WHERE [ScenarioCode] = N'B1-S12' AND
                    ([PrimaryMonsterCode] <> N'GNOLL' OR [ReadyForExecution] <> 0 OR
                     [ScenarioStatus] <> N'Specified' OR [MonsterCount] <> 4))
        THROW 57822, 'Conflicting existing draft B1 source row; manual review required', 1;
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S12' AND [TestCaseCode] = N'S12-SRC')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S12', N'S12-SRC', 1, N'B1 original source entry, count and roster provenance', N'ENCOUNTER', N'Specified', 1, N'Verify owner-owned brown-cover printed p.25 option and edition variants before selecting count/room.', N'Exact source entry ID, HP sequence, optional count range and source edition signed by BON.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S12' AND [TestCaseCode] = N'S12-HANDOFF')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S12', N'S12-HANDOFF', 2, N'Resolved approved species and roster handoff', N'COMBAT_HANDOFF', N'Blocked', 1, N'Use explicitly Active/Approved version-pinned Rules.Monster, full resolved equipment and party.', N'Missing RecordDate, rules, scene or unapproved source leaves state unchanged and fails closed.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S12' AND [TestCaseCode] = N'S12-ROUND')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S12', N'S12-ROUND', 3, N'Deterministic combat round, conditions, morale and reset', N'COMBAT', N'Blocked', 1, N'After independently verified Combat special/morale/target rules, inject fixed dice and start battle.', N'One or more real Python engine rounds, isolated reset, no ignored mechanics or forged UAT.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    -- S15: distinct B1 source option; 5 MAX test actors, not automatic stocking.
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode] = N'B1-S15')
    BEGIN
        INSERT INTO [Test].[MonsterTestScenario]
        ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],
         [FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],
         [MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],
         [SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
        VALUES (N'B1-S15', N'B1 S15 optional stock — Hobgoblins', N'MentzerBECMI', N'HOBGOBLIN', 1, N'Specified', 0, N'TSR 9023 B1 brown-cover printed p.25 / option S15', 5, N'[{"actor_id":"alho","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"evro","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"sho-rembo","hp_start":9,"source":"owner-canonical-3v3-fixture-v1"}]', N'[{"actor_id":"b1-s15-hobgoblin-01","armor_class":6,"equipment":null,"hp_start":9,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":1,"species":"HOBGOBLIN","species_record_date":null},{"actor_id":"b1-s15-hobgoblin-02","armor_class":6,"equipment":null,"hp_start":8,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":2,"species":"HOBGOBLIN","species_record_date":null},{"actor_id":"b1-s15-hobgoblin-03","armor_class":6,"equipment":null,"hp_start":6,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":3,"species":"HOBGOBLIN","species_record_date":null},{"actor_id":"b1-s15-hobgoblin-04","armor_class":6,"equipment":null,"hp_start":4,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":4,"species":"HOBGOBLIN","species_record_date":null},{"actor_id":"b1-s15-hobgoblin-05","armor_class":6,"equipment":null,"hp_start":3,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":5,"species":"HOBGOBLIN","species_record_date":null}]', N'{"b1_count_max":5,"b1_count_min":2,"selection_policy":"PROVISIONAL_MAXIMUM_TEST_COUNT_NOT_MANDATORY_MODULE_STOCKING","test_selection":5}', NULL, N'{"actual_room_assignment":null,"b1_source_id":"S15","bon_source_approved":false,"equipment":"UNRESOLVED","geometry":"UNRESOLVED","initial_hostility":"UNRESOLVED","module_page":25,"species_record_date":null,"stocking_optional":true,"surprise":"UNRESOLVED","verified_mechanics":false}', NULL, NULL, N'PROVISIONAL B1 source-authentic inventory. All source, approval, rules, equipment, scene and engine gates must pass before ReadyForExecution=1.');
    END
    ELSE IF EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario]
                   WHERE [ScenarioCode] = N'B1-S15' AND
                    ([PrimaryMonsterCode] <> N'HOBGOBLIN' OR [ReadyForExecution] <> 0 OR
                     [ScenarioStatus] <> N'Specified' OR [MonsterCount] <> 5))
        THROW 57822, 'Conflicting existing draft B1 source row; manual review required', 1;
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S15' AND [TestCaseCode] = N'S15-SRC')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S15', N'S15-SRC', 1, N'B1 original source entry, count and roster provenance', N'ENCOUNTER', N'Specified', 1, N'Verify owner-owned brown-cover printed p.25 option and edition variants before selecting count/room.', N'Exact source entry ID, HP sequence, optional count range and source edition signed by BON.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S15' AND [TestCaseCode] = N'S15-HANDOFF')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S15', N'S15-HANDOFF', 2, N'Resolved approved species and roster handoff', N'COMBAT_HANDOFF', N'Blocked', 1, N'Use explicitly Active/Approved version-pinned Rules.Monster, full resolved equipment and party.', N'Missing RecordDate, rules, scene or unapproved source leaves state unchanged and fails closed.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S15' AND [TestCaseCode] = N'S15-ROUND')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S15', N'S15-ROUND', 3, N'Deterministic combat round, conditions, morale and reset', N'COMBAT', N'Blocked', 1, N'After independently verified Combat special/morale/target rules, inject fixed dice and start battle.', N'One or more real Python engine rounds, isolated reset, no ignored mechanics or forged UAT.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    -- S16: distinct B1 source option; 8 MAX test actors, not automatic stocking.
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode] = N'B1-S16')
    BEGIN
        INSERT INTO [Test].[MonsterTestScenario]
        ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],
         [FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],
         [MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],
         [SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
        VALUES (N'B1-S16', N'B1 S16 optional stock — Goblins', N'MentzerBECMI', N'GOBLIN', 1, N'Specified', 0, N'TSR 9023 B1 brown-cover printed p.25 / option S16', 8, N'[{"actor_id":"alho","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"evro","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"sho-rembo","hp_start":9,"source":"owner-canonical-3v3-fixture-v1"}]', N'[{"actor_id":"b1-s16-goblin-01","armor_class":6,"equipment":null,"hp_start":7,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":1,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-02","armor_class":6,"equipment":null,"hp_start":5,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":2,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-03","armor_class":6,"equipment":null,"hp_start":4,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":3,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-04","armor_class":6,"equipment":null,"hp_start":3,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":4,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-05","armor_class":6,"equipment":null,"hp_start":3,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":5,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-06","armor_class":6,"equipment":null,"hp_start":3,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":6,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-07","armor_class":6,"equipment":null,"hp_start":2,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":7,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s16-goblin-08","armor_class":6,"equipment":null,"hp_start":1,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":8,"species":"GOBLIN","species_record_date":null}]', N'{"b1_count_max":8,"b1_count_min":1,"selection_policy":"PROVISIONAL_MAXIMUM_TEST_COUNT_NOT_MANDATORY_MODULE_STOCKING","test_selection":8}', NULL, N'{"actual_room_assignment":null,"b1_source_id":"S16","bon_source_approved":false,"equipment":"UNRESOLVED","geometry":"UNRESOLVED","initial_hostility":"UNRESOLVED","module_page":25,"species_record_date":null,"stocking_optional":true,"surprise":"UNRESOLVED","verified_mechanics":false}', NULL, NULL, N'PROVISIONAL B1 source-authentic inventory. All source, approval, rules, equipment, scene and engine gates must pass before ReadyForExecution=1.');
    END
    ELSE IF EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario]
                   WHERE [ScenarioCode] = N'B1-S16' AND
                    ([PrimaryMonsterCode] <> N'GOBLIN' OR [ReadyForExecution] <> 0 OR
                     [ScenarioStatus] <> N'Specified' OR [MonsterCount] <> 8))
        THROW 57822, 'Conflicting existing draft B1 source row; manual review required', 1;
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S16' AND [TestCaseCode] = N'S16-SRC')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S16', N'S16-SRC', 1, N'B1 original source entry, count and roster provenance', N'ENCOUNTER', N'Specified', 1, N'Verify owner-owned brown-cover printed p.25 option and edition variants before selecting count/room.', N'Exact source entry ID, HP sequence, optional count range and source edition signed by BON.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S16' AND [TestCaseCode] = N'S16-HANDOFF')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S16', N'S16-HANDOFF', 2, N'Resolved approved species and roster handoff', N'COMBAT_HANDOFF', N'Blocked', 1, N'Use explicitly Active/Approved version-pinned Rules.Monster, full resolved equipment and party.', N'Missing RecordDate, rules, scene or unapproved source leaves state unchanged and fails closed.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S16' AND [TestCaseCode] = N'S16-ROUND')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S16', N'S16-ROUND', 3, N'Deterministic combat round, conditions, morale and reset', N'COMBAT', N'Blocked', 1, N'After independently verified Combat special/morale/target rules, inject fixed dice and start battle.', N'One or more real Python engine rounds, isolated reset, no ignored mechanics or forged UAT.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    -- S20: distinct B1 source option; 4 MAX test actors, not automatic stocking.
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode] = N'B1-S20')
    BEGIN
        INSERT INTO [Test].[MonsterTestScenario]
        ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],
         [FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],
         [MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],
         [SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
        VALUES (N'B1-S20', N'B1 S20 optional stock — Bandits', N'MentzerBECMI', N'BANDIT', 1, N'Specified', 0, N'TSR 9023 B1 brown-cover printed p.25 / option S20', 4, N'[{"actor_id":"alho","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"evro","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"sho-rembo","hp_start":9,"source":"owner-canonical-3v3-fixture-v1"}]', N'[{"actor_id":"b1-s20-bandit-01","armor_class":6,"equipment":null,"hp_start":7,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":1,"species":"BANDIT","species_record_date":null},{"actor_id":"b1-s20-bandit-02","armor_class":6,"equipment":null,"hp_start":5,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":2,"species":"BANDIT","species_record_date":null},{"actor_id":"b1-s20-bandit-03","armor_class":6,"equipment":null,"hp_start":4,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":3,"species":"BANDIT","species_record_date":null},{"actor_id":"b1-s20-bandit-04","armor_class":6,"equipment":null,"hp_start":2,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":4,"species":"BANDIT","species_record_date":null}]', N'{"b1_count_max":4,"b1_count_min":1,"selection_policy":"PROVISIONAL_MAXIMUM_TEST_COUNT_NOT_MANDATORY_MODULE_STOCKING","test_selection":4}', NULL, N'{"actual_room_assignment":null,"b1_source_id":"S20","bon_source_approved":false,"equipment":"UNRESOLVED","geometry":"UNRESOLVED","initial_hostility":"UNRESOLVED","module_page":25,"species_record_date":null,"stocking_optional":true,"surprise":"UNRESOLVED","verified_mechanics":false}', NULL, NULL, N'PROVISIONAL B1 source-authentic inventory. All source, approval, rules, equipment, scene and engine gates must pass before ReadyForExecution=1.');
    END
    ELSE IF EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario]
                   WHERE [ScenarioCode] = N'B1-S20' AND
                    ([PrimaryMonsterCode] <> N'BANDIT' OR [ReadyForExecution] <> 0 OR
                     [ScenarioStatus] <> N'Specified' OR [MonsterCount] <> 4))
        THROW 57822, 'Conflicting existing draft B1 source row; manual review required', 1;
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S20' AND [TestCaseCode] = N'S20-SRC')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S20', N'S20-SRC', 1, N'B1 original source entry, count and roster provenance', N'ENCOUNTER', N'Specified', 1, N'Verify owner-owned brown-cover printed p.25 option and edition variants before selecting count/room.', N'Exact source entry ID, HP sequence, optional count range and source edition signed by BON.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S20' AND [TestCaseCode] = N'S20-HANDOFF')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S20', N'S20-HANDOFF', 2, N'Resolved approved species and roster handoff', N'COMBAT_HANDOFF', N'Blocked', 1, N'Use explicitly Active/Approved version-pinned Rules.Monster, full resolved equipment and party.', N'Missing RecordDate, rules, scene or unapproved source leaves state unchanged and fails closed.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S20' AND [TestCaseCode] = N'S20-ROUND')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S20', N'S20-ROUND', 3, N'Deterministic combat round, conditions, morale and reset', N'COMBAT', N'Blocked', 1, N'After independently verified Combat special/morale/target rules, inject fixed dice and start battle.', N'One or more real Python engine rounds, isolated reset, no ignored mechanics or forged UAT.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    -- S25: distinct B1 source option; 6 MAX test actors, not automatic stocking.
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode] = N'B1-S25')
    BEGIN
        INSERT INTO [Test].[MonsterTestScenario]
        ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],
         [FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],
         [MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],
         [SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])
        VALUES (N'B1-S25', N'B1 S25 optional stock — Goblins — alternate B1 source entry', N'MentzerBECMI', N'GOBLIN', 1, N'Specified', 0, N'TSR 9023 B1 brown-cover printed p.25 / option S25', 6, N'[{"actor_id":"alho","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"evro","hp_start":8,"source":"owner-canonical-3v3-fixture-v1"},{"actor_id":"sho-rembo","hp_start":9,"source":"owner-canonical-3v3-fixture-v1"}]', N'[{"actor_id":"b1-s25-goblin-01","armor_class":6,"equipment":null,"hp_start":6,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":1,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s25-goblin-02","armor_class":6,"equipment":null,"hp_start":5,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":2,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s25-goblin-03","armor_class":6,"equipment":null,"hp_start":5,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":3,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s25-goblin-04","armor_class":6,"equipment":null,"hp_start":4,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":4,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s25-goblin-05","armor_class":6,"equipment":null,"hp_start":3,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":5,"species":"GOBLIN","species_record_date":null},{"actor_id":"b1-s25-goblin-06","armor_class":6,"equipment":null,"hp_start":2,"role":"SOURCE_UNDESIGNATED","source_hp_ordinal":6,"species":"GOBLIN","species_record_date":null}]', N'{"b1_count_max":6,"b1_count_min":1,"selection_policy":"PROVISIONAL_MAXIMUM_TEST_COUNT_NOT_MANDATORY_MODULE_STOCKING","test_selection":6}', NULL, N'{"actual_room_assignment":null,"b1_source_id":"S25","bon_source_approved":false,"equipment":"UNRESOLVED","geometry":"UNRESOLVED","initial_hostility":"UNRESOLVED","module_page":25,"species_record_date":null,"stocking_optional":true,"surprise":"UNRESOLVED","verified_mechanics":false}', NULL, NULL, N'PROVISIONAL B1 source-authentic inventory. All source, approval, rules, equipment, scene and engine gates must pass before ReadyForExecution=1.');
    END
    ELSE IF EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario]
                   WHERE [ScenarioCode] = N'B1-S25' AND
                    ([PrimaryMonsterCode] <> N'GOBLIN' OR [ReadyForExecution] <> 0 OR
                     [ScenarioStatus] <> N'Specified' OR [MonsterCount] <> 6))
        THROW 57822, 'Conflicting existing draft B1 source row; manual review required', 1;
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S25' AND [TestCaseCode] = N'S25-SRC')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S25', N'S25-SRC', 1, N'B1 original source entry, count and roster provenance', N'ENCOUNTER', N'Specified', 1, N'Verify owner-owned brown-cover printed p.25 option and edition variants before selecting count/room.', N'Exact source entry ID, HP sequence, optional count range and source edition signed by BON.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S25' AND [TestCaseCode] = N'S25-HANDOFF')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S25', N'S25-HANDOFF', 2, N'Resolved approved species and roster handoff', N'COMBAT_HANDOFF', N'Blocked', 1, N'Use explicitly Active/Approved version-pinned Rules.Monster, full resolved equipment and party.', N'Missing RecordDate, rules, scene or unapproved source leaves state unchanged and fails closed.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = N'B1-S25' AND [TestCaseCode] = N'S25-ROUND')
        INSERT INTO [Test].[MonsterTestCase]
        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],
         [TestStatus],[TestRevision],[GivenText],[ExpectedText],
         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])
        VALUES (N'B1-S25', N'S25-ROUND', 3, N'Deterministic combat round, conditions, morale and reset', N'COMBAT', N'Blocked', 1, N'After independently verified Combat special/morale/target rules, inject fixed dice and start battle.', N'One or more real Python engine rounds, isolated reset, no ignored mechanics or forged UAT.', NULL, NULL, N'AIDM-DES-001.7.12.1', NULL, N'SOURCE/READINESS SPECIFICATION ONLY; not an executed test');
    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO
