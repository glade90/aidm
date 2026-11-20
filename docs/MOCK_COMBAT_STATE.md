# AIDM-DES-006.2 — Mock Battleground and Combat State Fixtures

**Golden Braid / AIDM · Technical Build · Sprint 2 / Iteration 2.2 · COSTA**  
**Design:** BON's accepted `AIDM-CMB-STATE-001` v0.3, especially normative §§10–11.  
**Status:** Development candidate; not authoritative gameplay, combat rules, player campaign state, or persistent event logging.  
**Change record:** 2026-11-20 — initial source-labelled, versioned state and fixture implementation.

## Public model and composition

`aidm.combat.state` defines **one** frozen `Combatant` and `CombatSide` type for both human/retainer party and creature sides. `Origin.CHARACTER`/`CREATURE` and the independent `Controller.HUMAN`/`AGENT`/`SCRIPTED` field determine metadata—not permissions. A `Combatant.source_ref` is only an *external reference* to a character or monster definition; it is not a campaign record. Character and monster instance HP are separate.

- `EncounterParty(party_id, side: CombatSide)` and `OpposingForce(force_id, side: CombatSide, groups: tuple[MonsterGroup, ...])` make the party/monster-group composition explicit without separate player/monster combat engines. `EncounterDefinition.sides` gives the same shared type for either side.
- `BattlegroundDefinition(AreaRef, initial_placements, zone_relations, melee_relations)` is independent from actor identities. Every actor gets exactly one `ActorPlacement(actor_id, PositionRef(zone_id))`. Multiple actors may share a named zone; unknown grid, distance, visibility, movement legality or reach must **not** be inferred. Unsupported `FUTURE_GEOMETRY` raises typed `NOT_IMPLEMENTED`.
- `Combatant` retains source ability scores, scenario-only `ScenarioOverride`, source-labelled `EquipmentRef` (unverified/provisional/candidate), attack/movement/profile references and separately optional undisclosed traits. It does **not** compute effective AC, damage, Strength bonuses or combat rules.
- `FixtureDefinition(schema_version="0.1", rules_verified=False, provenance="SYNTHETIC_TEST")` contains a validated immutable `EncounterDefinition` and an *allowlist* of approved `ApprovedFixtureEffect` test transitions. `rules_profile_ref` and `house_rule_overlay_refs` are separate, unverified metadata.
- `MockEncounterState.start(fixture, session_id=..., trusted_token=...)` creates an isolated test-session state. `snapshot()` returns a frozen `EncounterSnapshot` with roster, group IDs, HP, positions, round cursor, version and approved effects. `EncounterSnapshot.from_dict` reconstructs JSON roundtrips for audit; this is **not** Bookkeeper restoration.

## Demonstration

```python
from aidm.combat.fixtures import two_by_two, canonical_three_vs_three
from aidm.combat.state import MockEncounterState

fixture = two_by_two()  # original synthetic test-only HP regression
harness_token = object()  # an in-process test capability, NOT authentication
state = MockEncounterState.start(fixture, session_id="test-101", trusted_token=harness_token)

before = state.snapshot()          # HP [7, 6, 3, 4], version 0, round 1
middle = state.apply_scripted_effect(fixture.approved_effects[0], token=harness_token)
# HP [7, 5, 1, 4], version 1, round 2
final = state.apply_scripted_effect(fixture.approved_effects[1], token=harness_token)
# HP [4, 5, 0, 0], version 2, scripted outcome PARTY_VICTORY

assert [a.hp_current for a in before.actors] == [7, 6, 3, 4]
assert [a.hp_current for a in final.actors] == [4, 5, 0, 0]
assert final.outcome.value == "PARTY_VICTORY"

owner_fixture = canonical_three_vs_three()  # Alho / Evro / Sho vs orc-01..03
assert len(owner_fixture.encounter.members) == 6
```

Only **allowlisted exact immutable fixture effects** plus the test-harness `trusted_token` can change mock HP. Preflight checks stale state version, duplicated effect ID, fixture allowlist, known actor ID, expected previous HP, within-bounds new HP and checkpoint; *all* checks run before commit. `record_proposal(DeclaredAction)` and `attach_raw_roll(RecordedRollAssociation)` retain intentionally unvalidated text and raw face provenance but **never** imply a hit, change HP or persist a game event. To record a raw roll with identity, use an already-resolved `aidm.combat.dice.RawDieResult` and copy its `roll_id`, `die_id`, `sides`, `face`, source and queue offset into the association; no reroll is permitted or needed.

`view_for_player()` is a **separate allowlist**: it includes friendly party HP and only explicitly revealed opponent IDs/descriptions/public zone/group, not monster HP, source AC, hidden traits, statuses, private sources or hidden enemy placements. Unrevealed opposition defaults to hidden and is omitted from the public side roster. `view_for_controller(token=...)` returns a deep-copied private snapshot for the trusted test harness. Caller-supplied text like `"DM"` has no write authority.

## Golden regression fixtures / source fidelity

`two_by_two(loss=False)` and `two_by_two(loss=True)` are entirely fictional, standalone state plumbing checks. Initial HP `[7,6,3,4]`, scripted first-round win `[7,5,1,4]`, terminal win `[4,5,0,0]`; separate two-round loss `[0,0,3,4]`. Source fixtures never mutate, and repeat sessions are independent. No Mentzer attack/damage/victory rules are inferred from the supplied HP checkpoints.

`variable_three_vs_four()` exercises the same class definitions with 3 party/4 creatures, 2 distinct monster groups and 3 explicit zones. All actor placements are checked by ID; duplicate/orphan/missing/foreign zone values are rejected. `canonical_three_vs_three()` instead uses the Owner's **scenario-only** Alho/Evro/Sho-Rembo versus three-orc input for the later human-driven combat integration:

| Character/instance | Start HP | Source ability/equipment metadata |
|---|---:|---|
| Alho | 8 | Human Fighter 1, original STR12, flail damage **UNRESOLVED**, armour/AC unknown |
| Evro | 8 | Human Fighter 1, source STR16 preserved; scenario-only STR18; longsword candidate; provisional plate and ordinary shield |
| Sho-Rembo | 9 | Halfling 1, original STR9; handaxe candidate; provisional plate and +1 shield |
| Orc 01, 02, 03 | 6, 4, 3 | Independent instances sharing owner Orc reference: source AC6/HD1/AT1/1d6-or-weapon/MV90'(30')/Save F1/group ML8; shortsword candidate |

The six actors use one common `Combatant` schema, own control endpoints and placements in an explicitly authored synthetic central melee zone; authored melee eligibility is test input, **not** a grid/range algorithm. Source/candidate values are **not** verified effective AC, damage, combat-to-hit, morale decisions or rule table results. No old character-sheet scores, items, HP or XP are changed, and no copyrighted B1 module content is embedded.

## Test/quality and scope

Run from repo root:

```powershell
python -m pytest aidm/combat/test/test_state.py -q --cov=aidm.combat.state --cov=aidm.combat.fixtures --cov-report=term-missing
python -m aidm.test_runner
```

F01–F12 verify isolated sessions, scripted two-round win/loss, version and idempotency, negative validations, redacted views, unknown distances/visibility, dice association and replayable snapshots. F13–F17 verify variable rosters, separate monster instances, group IDs, placements and unsupported future geometry. F18–F23 verify the canonical six actors, preserved source abilities/overrides, orc definition provenance, gear uncertainty and no modifiers applied. Extra tests cover immutable snapshots, visibility fail-closed, concurrent effect replay and invalid source assertions.

**Explicit non-deliverables:** rules/phase engine (DES-001.1/.2), persistent character/creature records (Bookkeeper DES-017), event journal (DES-007), actual geometry/LOS, movement legality, combat modifier arithmetic, DM/UI/HTTP, real RNG-to-damage conversion, verified Basic rules or campaign writes. These are separate authorized Stories, and `MockEncounterState` is expressly non-durable. Technical Build needs final exact-source PEQUOD full regression and Owner-confirmed Actual Time before Airtable Stage Complete/ALEK; independent BON Functional UAT is not required.