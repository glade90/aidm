# AIDM-DES-001.7.12.1 — First Five B1 Source Entries (DAVOS developer increment)

STATUS: PROVISIONAL / NOT PLAYABLE / PENDING BON SOURCE APPROVAL (25 November 2026). First build only. Do NOT describe these as five READY battles or executed tests.

## Source and edition

TSR 9023 B1 In Search of the Unknown, brown-cover/basic printing, original optional monster stock list printed p.25. Confirm the owner's exact edition and source text with BON before approval. Separate original printing/monochrome editions may differ. Internal review: OneNote PLAN-020 B1 Monster Catalogue and Combat-Coverage Audit (22 November 2026), which identifies the 25 optional stock options, six upper and lower wandering entries, and two exceptional rooms. External source cross-check: https://level0human.substack.com/p/keying-b1-in-search-of-the-unknown (a reproduction of the stock list, NOT a substitute for the owner's source). The first-five selections below are DAVOS PROPOSALS, not BON's accepted allocation.

| Original B1 entry | Species | Original count range | Source HP sequence | Unresolved readiness |
| --- | --- | --- | --- | --- |
| S12 | Gnolls | 1–4 | 13, 7, 6, 3 | weapon +1 rule / morale / encounter |
| S15 | Hobgoblins | 2–5 | 9, 8, 6, 4, 3 | morale / relevant encounter rules |
| S16 | Goblins | 1–8 | 7, 5, 4, 3, 3, 3, 2, 1 | morale / encounter |
| S20 | Bandits | 1–4 | 7, 5, 4, 2 | no invented weapon / NPC reaction / morale |
| S25 | Goblins, separate source variant | 1–6 | 6, 5, 5, 4, 3, 2 | distinct source roster from S16 / morale |

S16 and S25 are separate original B1 options, not cloned battles: their printed count ranges and HP arrays differ. The source listing does not determine actual room assignment. Only 16–20 of the 25 optional stocklist entries are used by an actual DM. The candidates use MAX printed count as a deliberate, UNAPPROVED isolated test selection, not mandatory B1 stocking.

## Source of truth and implemented files

Database/fixtures/B1_First_Five_Source_Candidates.json — five source candidates with exact print ID, source count/HP arrays, edition, proposed status and explicit mechanics questions. NOT Mentzer Rules.Monster species definitions.

Database/fixtures/B1_Source_Allocation_Proposal.json — 39 original IDs allocated *once* across child stories .1–.8: five first, six more children of five each, last child four. PROPOSAL pending BON/ALEK; no original entry accidentally reused.

aidm/b1_fixtures.py — offline deterministic validator/renderer; imports no database driver, engine, browser, or LLM. python -m aidm.b1_fixtures --check verifies the committed seed; --write regenerates a REVIEW-ONLY local SQL file without executing it.

Database/tables/inserts/MonsterTestScenario_B1_First_Five_Candidates.sql — generated transaction/insert-only candidate fixture data. Exactly five Test.MonsterTestScenario records plus fifteen normalized Test.MonsterTestCase records. ScenarioStatus=Specified, ReadyForExecution=0; cases are Specified source-review or Blocked handoff/round. No execution/UAT outcomes or auto-approval. Re-run is idempotent only for identical draft identity/approval status; conflicts require manual review. Does NOT alter existing Rules.Monster or synthetic test fixtures. SQL NOT executed or deployed.

aidm/test/test_b1_fixtures.py — offline first-five count/HP/schema/SQL/allocation/HTML fail-closed tests. They are developer tests, not independent source verification.

The test actor roster reuses owner-approved synthetic party HP Alho=8, Evro=8, Sho-Rembo=9, explicitly marked as party TEST data; none is claimed to be a B1 module PC. Scenario monster HP values come from original B1 candidate source facts. The test count uses the maximum printed optional count and is a tester choice; creature weapons, initial hostility, geometry, surprise, RecordDate pins, and actual room placement remain UNRESOLVED. Player-facing browser options remain disabled.

## Readiness barriers — all five currently UNSUPPORTED

(1) BON verifies specific original B1 edition, selection, count/HP, possible original variant, and signs source/allocation across 39 IDs.

(2) AIDM-DES-001.7.9 loader (still In Progress) proves real PEQUOD READ ONLY SQL smoke. Confirm v0.4 Rules.Monster and Test tables deployed, per-species Approved+Active version pinned to a non-null RecordDate. Current seed species SourceChecked/Active=0 cannot silently become approved. Draft v0.4 Monster.sql has outdated SizeX/Y/Z validation names versus D1/D2/Z, a DB-owner issue.

(3) Combat and Encounter rules for each selected variant are implemented and approved, including morale (DES-001.5.1), monster conditional rules (DES-001.7.4), verified equipment, scene/surprise and initial reaction/hostility. Unsupported special features must BLOCK, not silently be ignored. Current CombatSessionService accepts only synthetic owner 3v3 and therefore MUST NOT be modified to enable these draft candidates without valid source versions and mechanics.

(4) Future full integration: five actual Browser→Meta→DM→Combat→DM→Browser START, one or more real deterministic rounds, independent RESET, fixed dice, stale-event rejection, original 3v3 remains green, exact source SHA, full >=90% coverage, Node regression, BON independent Functional UAT for all five including two full combat demonstrations.

No story completion, SQL write/deployment, gameplay/READY, UAT, or merge has occurred.

## Owner developer test commands

    cd /c/Development/aidm-0042-check
    git pull --ff-only origin davos
    git rev-parse HEAD
    git status --porcelain
    python -m aidm.b1_fixtures --check
    python -m pytest aidm/test/test_b1_fixtures.py aidm/test/test_catalogue.py -q
    python -m aidm.test_runner
    node --test aidm/web/test/chat_client.test.mjs aidm/web/test/combat_client.test.mjs

The previously recorded 575 full JUnit +22 Node receipts belong to the previous 61eaaba source, not this B1 candidate head. The persistent DAVOS branch also contains open Draft PR #23 for the selector; main advanced independently and review scope/divergence must be reconciled before merge.
