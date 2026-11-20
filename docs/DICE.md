# Raw collectible dice — AIDM-DES-005.2

**Architecture:** Owner's raw-only correction, BON proposed `AIDM-CMB-DICE-001` §10 (v0.4). **Developer:** COSTA. **Review status:** pending BON/Owner acceptance and a new integrated regression for PR #12. This replaces the earlier approved v0.3 implementation; it is a breaking contract change, not a repair of an incorrectly implemented specification.

## Responsibilities

- **Die** (`Die`) identifies one chosen die. The frozen fields are `die_id`, `sides`, and `colour`. It has no transient face, actor, purpose, strength, weapon, modifier, roll math or combat state. Real collection membership, global uniqueness, optional other attributes and historic metadata are future DiceCollection responsibilities.
- **DiceRoller** rolls the supplied `Die` or a simple ordered handful of them, through an injected `RollSource`. It returns independent `RawDieResult` objects with the actual raw face, selected ID, sides, one-based index, `roll_id`, optional `correlation_id`/`roll_group_id`, `FIXED` versus `SYSTEM_RANDOM` source, and optional zero-based queue position. **There is no modifier argument, derived total, dice sum, weapon or attack context.**
- **Combat Rules Engine (DES-001.2)** chooses/validates which dice are needed, adds the authorised contributions to raw faces and owns hit/damage/HP maths. No Rules Engine is implemented by this story.

```python
from aidm.combat import Die, DiceRoller, FixedRollSource

blue_d20 = Die(die_id="blue-d20", sides=20, colour="blue")
roller = DiceRoller(FixedRollSource([12]))
raw = roller.roll(blue_d20, roll_id="attack-001", correlation_id="turn-001")

assert raw.die_id == "blue-d20"
assert raw.sides == 20 and raw.face == 12
assert raw.source == "FIXED" and raw.queue_position == 0

# Demonstration of a separate consumer calculation, NOT a dice operation:
modified_attack = raw.face + 3
assert modified_attack == 15 and raw.face == 12
```

A source may be `SystemRandomSource()` (uses unbiased `secrets.randbelow(sides) + 1` locally) or `FixedRollSource([12, ...])` for tests. Construction/import never invokes entropy or a provider. `roll_id` and `roll_group_id` are generated if omitted; caller-provided values are preserved and validated. Callers remain responsible for authoritative event IDs and idempotency; this tool never commits events or state. `Die` must be selected explicitly; it cannot invent or verify a user's preferred physical die. Repeated use of the same instance in one handful is valid. Two different appearances under one `die_id` are rejected within the same handful, but collection-wide identity/ownership validation is future work.

## Simple mixed-sided raw handful (not a combat batch)

```python
blue_d8 = Die("blue-d8", 8, "blue")
red_d6 = Die("red-d6", 6, "red")
gold_d4 = Die("gold-d4", 4, "gold")
roller = DiceRoller(FixedRollSource([6, 4, 2]))
raws = roller.roll_many([blue_d8, red_d6, gold_d4], roll_group_id="handful-001")
assert [(raw.die_id, raw.face) for raw in raws] == [
    ("blue-d8", 6), ("red-d6", 4), ("gold-d4", 2),
]
# No sum or modifier exists in any raw result.
```

The simple `roll_many` validates a nonempty ordered selection (max 100 dice), preserves identity/order and returns one raw face per selected die. For a **FIXED** source, `roll_sequence(sides_sequence)` checks every next queued face against its corresponding die *before consuming anything*; exhausted or out-of-range queues leave the cursor unchanged, with no fallback to random. `roll_many(count,sides)` remains on both sources for homogeneous fixtures, but the roller obtains `sides` exclusively from selected `Die` objects. Live entropy cannot be retroactively undone if an external source fails; no game-state/event effects originate in this utility.

DES-005.3 continues to own `RollBatchRequest`/`RollBatchResult`, multiple character/weapon/action/target association, grouping semantics and full service orchestration. Do not interpret a raw handful as automatic combined damage, proof of simultaneous Mentzer initiative, or a complete multi-actor combat batch.

## Breaking migration from the original v0.3 PR

| Previous API | Raw-only API |
| --- | --- |
| `RollRequest(count, sides, modifier, ...)` | Explicit `Die(die_id, sides, colour)` selection |
| `RollRequest.from_expression("2d6+3", ...)` | Resolve selected dice separately; the Rules Engine interprets expressions/bonuses |
| `DiceRoller.roll(RollRequest)` | `DiceRoller.roll(Die, roll_id=...)` |
| `RollResult.dice`, `.raw_sum`, `.modifier`, `.total` | `RawDieResult.face`; `roll_many` returns `tuple[RawDieResult, ...]` with no total |
| `DieResult` with optional (potentially unassigned) `die_id` | Each selected `Die` is required to have an actual stable `die_id` |
| `parse_dice_expression()` in dice utility | Removed from this raw-only module; no numeric expression evaluation |

The existing CombatAgent and Meta HTTP mock services do **not** consume the former dice API. Their tests should remain unchanged, but old DES-005.2 expression/modifier tests must be replaced. Do not offer compatibility shims which silently keep modifiers inside the dice layer.

## Verification, limits and provenance

Source-colocated `aidm/combat/test/test_dice.py` replaces obsolete modifier oracles with BON §10 `RAW-01`–`RAW-06`, `RULE-01` **contract-only** demonstration, and regression tests for both single and heterogeneous fixed queues, exhaustion, illegal faces, defensive typed validation, concurrent fixed cursor, immutable/provenance/JSON replay, and source isolation. The downstream test shows that separate arithmetic produces 15 from raw 12 and +3 without changing the dice result. No combat service is implemented in this test.

```powershell
python -m pytest aidm/combat/test/test_dice.py -q --cov=aidm.combat.dice --cov-report=term-missing
python -m aidm.test_runner
```

Keep PR #12 **Draft** until the owner reviews the revised interface, full source-matched regression passes on PEQUOD and BON confirms the contract. Record full source SHA, clean working-tree status, JUnit tests/subtests, coverage, standard run ID and owner-confirmed Actual Time. The existing 0.5-hour estimate is at risk: COSTA notified ALEK of an estimated 1.5 additional hours for this breaking refactor. No BON Functional UAT is required for the Technical Story, but architectural acceptance is still required.