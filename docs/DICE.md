# Single-expression dice roller — AIDM-DES-005.2

**Design:** BON, `AIDM-CMB-DICE-001` v0.3 / DES-005.1. **Implementation:** COSTA, DES-005.2. This is a pure Python, rules-neutral source; it does not choose game-legal dice or apply effects.

## Public interface

`from aidm.combat.dice import DiceRoller, RollRequest, RollResult, DieResult, FixedRollSource, SystemRandomSource, RollSourceKind, parse_dice_expression, InvalidDiceRequest, FixedRollsExhausted, FixedRollOutOfRange, InvalidRollSource`

`RollRequest(count, sides, modifier, request_id, correlation_id, purpose=None, actor_id=None, die_ids=None)` is an immutable validated request for **one homogeneous expression**. Alternatively `RollRequest.from_expression("2d6+3", request_id="call-1", correlation_id="turn-1", die_ids=("blue-d6", "green-d6"))` parses only `dS`, `NdS`, `NdS+M`, `NdS-M`, case-insensitive `D`, surrounding whitespace only. The integer bounds are 1–100 dice, 2–1000 sides and absolute modifier ≤1,000,000; these are engineering safeguards, **not Mentzer rules**. No `eval` or arbitrary grammar.

```python
from aidm.combat.dice import DiceRoller, FixedRollSource, RollRequest

source = FixedRollSource([2, 5])
roller = DiceRoller(source)
request = RollRequest.from_expression(
    "2d6+3", request_id="call-1", correlation_id="turn-1",
    purpose="synthetic example", die_ids=("blue-d6", "green-d6"),
)
result = roller.roll(request)
assert (result.faces, result.raw_sum, result.total) == ((2, 5), 7, 10)
assert [(d.die_index, d.die_id, d.queue_position)
        for d in result.dice] == [(1, "blue-d6", 0), (2, "green-d6", 1)]
assert result.source.value == "FIXED"  # scripted, NOT a random roll
```

For live, independent, locally unbiased numbers instead inject `SystemRandomSource()` (uses `secrets.randbelow(sides)+1`). Fixed mode never falls back to live entropy. `FixedRollSource` preflights the **entire next single-roll request** before moving its read cursor. If exhausted or given an out-of-range/noninteger queued face, it throws `FixedRollsExhausted` or `FixedRollOutOfRange` without consuming any queued face. A caller-provided invalid roll request or wrong-length/blank die IDs is also rejected before drawing. `FixedRollSource.cursor` exposes a 0-based position for tests.

`RollResult` and each ordered `DieResult` are frozen, with exact faces, 1-based die indexes, zero-based fixed queue positions, source markers, caller identifiers, original optional purpose/actor, unmodified signed totals and selected die identity. Missing `die_ids` produces `die_id=None`, never a fabricated physical die; repeated IDs are valid for rolling one collectible die multiple times. A die's name, colour and ownership are **not verified** by this utility. Those are future collection concerns. `dataclasses.asdict(result)` followed by JSON serialisation preserves the outcome for replay without another RNG call.

## Owner-facing design boundaries

The roller **cannot** say a roll hits, misses, saves, deals damage, changes HP, changes initiative, commits an event or is permitted by the Mentzer+house-rule profile. It cannot validate physical die ownership or automatically choose a character's preferred die. It makes no calls to LLMs, CrewAI, HTTP, filesystems, databases or Bookkeeper. Its pure return value is not itself an event/replay ledger or an idempotent command. Rules/profile selection belongs to DES-003, combat sequencing to DES-001, state/events to DES-006/007 and later services.

**DES-005.3** separately owns mixed-sided party roll groups and whole-batch fixed-queue atomicity. Do not treat multiple independent calls to `roll()` as a transaction for that future feature. No additional pip dependency was added.

## Test demonstration and handoff

From repository root, after installing existing development requirements:

```powershell
python -m pytest aidm/combat/test/test_dice.py -q --cov=aidm.combat.dice --cov-report=term-missing
python -m aidm.test_runner
```

Tests explicitly cover D01–D16 of BON's design: fixed minimum/maximum, positive/negative modifiers, parser boundaries, queue provenance and atomic failures, rejected booleans, nullable vs distinct/repeated die IDs and JSON replay without re-rolling. Extra cases validate injected erroneous sources and live generator bounds with a deterministic monkeypatch. On the exact GitHub PR head, run the *whole* PEQUOD test suite and record full source SHA/JUnit/coverage/run ID in Airtable before closure. Technical Story → ALEK on owner-confirmed actual hours; no BON Functional UAT.