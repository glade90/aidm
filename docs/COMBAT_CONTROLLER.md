# AIDM deterministic combat controller — AIDM-DES-001.2

**Document ID:** AIDM-CMB-ENGINE-001  
**Status:** **DRAFT PR — FUNCTIONAL BUILD / BON UAT HANDOFF (separate Design UAT is nonblocking)**  
**Owner:** COSTA  
**Date:** 20 November 2026  
**Governing design:** OneNote *AIDM — Mentzer Combat Sequence Design*, AIDM-CMB-SEQ-001 §§7–14. The separate Design Story may still be in **UAT Testing**. Its workflow is **not a blocker on COSTA development**. This Functional Build proceeds to BON independent UAT once developer tests and integration are ready; prototype unit tests do not constitute functional UAT, Bookkeeper persistence, or complete Mentzer Basic rule coverage.

## 1. First-slice scope and source references

A focused, scripted-and-human-drivable **3v3 stationary melee** controller that consumes the accepted `CombatSide`/`Combatant`/`EncounterDefinition` state schema from DES-006.2, injected raw physical `Die`/`DiceRoller` results from DES-005.2, and explicit trusted `SurpriseResult` previously resolved by the **Encounter Agent**. The controller never rolls surprise. It advances by source-labelled side initiative, ordered **morale → movement → missile → magic → melee** checkpoints, exact actor decision tokens and a test-local HP/event store. The owner-approved flail house rule `HR-WEAPON-FLAIL-001` (v1.0) supplies **1d6 base damage only**, when explicitly enabled.

Reference sources used to calibrate the *limited* first-level and 1-HD hit targets and other inputs:

- 1983 Mentzer Basic **Players Manual** printed pp.36 and 57–60 (the governing BON design cites these anchors); first-level character and up-to-1HD monster hit bands are *different*.
- BON's source-backed **AIDM-CMB-SEQ-001** and owner-approved **AIDM-CMB-STATE-001 v0.3**, plus the approved flail overlay in §13.
- Secondary independent check: [Basic/Expert 1981/1983 attack-table comparison](https://songoftheblade.wordpress.com/2017/09/10/a-results-oriented-format-for-old-school-dd-attack-tables/). The project does **not** reproduce the commercial attack tables here.

`rules_reference.py` has a **bounded replaceable prototype provider**, `PrototypeReferenceProvider` (`TD-AIDM-DATA-001`). It handles the supplied **Fighter 1 / Halfling 1 / Orc HD1** cases and defender AC **0..9** only; broader levels, monster bands, saves, extra attacks, spellcasting and unusual ACs fail explicitly as unsupported. The two low-level attack bands use separate validated source labels, never an Orc-specific combat-controller conditional. Higher-tier rules must not be silently extrapolated.

**Critical:** Evro imported STR16 remains unchanged. The encounter override STR18 yields +3 for eligible melee attack/damage; source-only STR16 would yield +2. Sho's **provisional** plate/+1 shield loadout produces descending AC1, Evro's **provisional** plate/ordinary shield AC2, **only** when `fixture_loadout_confirmed=True` is set by the test scenario controller. Alho's unspecified armour remains unknown; the engine refuses attacks *against Alho* until a trusted selected armour/AC value is supplied. It never treats the character sheet's base AC9 as verified equipped AC. House-rule flail 1d6 is separate from the 1983 printed table.

## 2. Public Python interfaces

- `RuleProfile`: versioned supported mechanic flags. Morale/missile/magic default disabled for first stationary fixture. Explicitly enabling an unsupported mechanic **blocks**, not passes.
- `ReferenceProvider`: swappable contract for a weapon damage die, class/level vs HD attack target, Strength contributions and source-labelled equipped AC.
- `SurpriseResult`: `NONE` or `SURPRISING_SIDE`, with `resolved_by=ENCOUNTER_AGENT`, encounter/rules IDs and source event ref. Missing or contradictory surprise rejects **before any combat rolls**.
- `DiceKit`: **explicit** selected side d6 and combatant attack d20/damage dice. `canonical_dice_kit()` makes openly labelled synthetic fixture dice, not real player's physical inventory.
- `CombatEngine(...).next_decision()` returns an idempotent pending `Decision` for each HUMAN or AGENT/SCRIPTED combatant with legal authored melee targets. The caller supplies a typed `CombatCommand` with unique `command_id`, `session_id`, `actor_id`, `expected_version` and exact `decision_token`; `submit()` validates identity, phase, target and rules **before** rolling or changing the controller's working HP.
- `snapshot()`, `journal()`, `player_view()` and `public_transcript()` return copies/allowlisted views. Internal journal preserves chronology, individual faces, physical die IDs, fixed source queue offsets, modifiers, rule versions, HP before/after, versions and terminal. The public view **does not** reveal opponent HP/AC, private traits, or undiscovered opponent names.
- `export_jsonl(repo_root, name="...")` writes internal machine-readable JSONL under ignored `reports/combat-logs/`. `name` has strict safe characters, existing files are never silently overwritten. Player-facing text is a separate redacted projection and should not be generated from unrestricted serialized internal event data.

Minimal fixture driving example (each actor chooses an explicitly supplied intention; no real LLM):

```python
from aidm.combat.fixtures import canonical_three_vs_three
from aidm.combat.engine import (CombatEngine, CombatCommand, SurpriseResult,
                                 SurpriseKind, canonical_dice_kit)
from aidm.combat.dice import DiceRoller, FixedRollSource
from aidm.combat.rules_reference import RuleProfile, FLAIL_RULE

encounter = canonical_three_vs_three().encounter
rules = RuleProfile(house_rule_overlays=(FLAIL_RULE,), fixture_loadout_confirmed=True)
combat = CombatEngine(
    encounter,
    surprise=SurpriseResult(SurpriseKind.NONE, encounter.encounter_id,
                            "ENCOUNTER_AGENT", "fixture-surprise-input-001", rules.profile_id),
    roller=DiceRoller(FixedRollSource([6, 3, 12, 5])),
    dice=canonical_dice_kit(encounter),
    profile=rules,
    session_id="synthetic-demo-session",
)
first = combat.next_decision()  # Alho: HUMAN, pending, *no attack roll yet*
combat.submit(CombatCommand("demo-hold-1", combat.session_id, first.actor_id,
                            first.version, first.token, "HOLD"))
second = combat.next_decision()  # Evro: AGENT / intent supplied externally
combat.submit(CombatCommand("demo-attack-2", combat.session_id, second.actor_id,
                            second.version, second.token, "ATTACK_MELEE", "orc-01"))
assert combat.snapshot()["hp"]["orc-01"] == 0  # 12 +3 hits, raw damage 5 +3
```

This is only a small source-injected example; normal full combat requires the agent gateway to supply each actor's intention and further fixed dice. No additional character data or rolled event is fabricated by the narration system.

## 3. Exact tested deterministic examples

- **No surprise:** first `next_decision()` consumes one selected d6 for **each side**, higher side acts first.
- **Party or opponent surprises:** exactly one opening side round, *no initiative dice in that opening*, then normal side initiative from following round.
- **Tie:** both sides' eligible intents/rolls are collected under a shared simultaneous round, then **all damage is applied together** after both sides complete. A combatant initially alive still attacks if the opposing side would kill it in the same exchange. Neither side wins initiative and no extra tie-break die is drawn. Journal includes `SIMULTANEOUS_EXCHANGE_STARTED`, `SIMULTANEOUS_ACTION_STAGED`, individual resolved actions and `SIMULTANEOUS_EXCHANGE_COMMITTED` with the single HP batch and source rule ID. No additional morale/missile/magic functionality is implied.
- **Canonical real melee:** fixed d20=12 with Evro STR18 +3 yields modified attack 15, which hits an orc AC6 in the limited level-one source table (needed 14); fixed d8=5 and +3 yields **8 damage**, capped to zero remaining HP. Both dice remain raw, with independent IDs/provenance.
- **Flail overlay:** on a legal fixed hit, Alho d6=4 deals 4; without named overlay the weapon is unsupported and consumes no attack/damage roll. The same historical character fixture stays unchanged.
- **Two-round win:** six combatants with distinct controller type, two side-initiative contests and fixed melee; exact final HP `[8,8,9,0,0,0]`, terminal party victory with no fake morale/magic/missile checks.
- **Due morale:** separate `FIRST_DEATH_EITHER_SIDE` / `HALF_UNAVAILABLE` trigger metadata. If enabled-but-unimplemented, further resolution **halts** without a 2d6 result. Disabled morale checkpoints and trigger suppression are labelled, not declared performed. Retainer Evro has no orc-group morale.
- **Bad action:** foreign session, wrong actor, stale token/version, illegal target, unsupported action or duplicate command produce safe errors with no HP or version mutation and no fabricated action resolution.

## 4. Known limitations and separately owned commitments

1. **Independent design workflow:** BON 001.1 Design testing proceeds independently and must not stall COSTA's implementation. This is a Draft PR pending clean PEQUOD whole-repository tests and Owner integration approval. As a **Functional Build**, 001.2 is handed to **BON UAT Testing** (joint end-to-end UAT with DAVOS 025.2 in Iteration 2.4); only BON's accepted functional evidence and Owner-confirmed actual time permit Complete/ALEK.
2. **Tied initiative is now implemented for the supported stationary melee subset** through deferred simultaneous damage and single final HP commitment (including mutual casualties). Enabled due morale still halts without a fabricated 2d6 result; more advanced simultaneous missile/spell/movement/specials require their own supported implementations (including 001.5 for morale).
3. **Missing fixed damage after a successful d20:** the accepted DES-005.2 source consumes a d20 before knowing whether damage is needed. If the conditional damage die is then exhausted, the controller leaves HP/version/journal unchanged, but **the fixed queue's d20 was consumed**. A future *transactional conditional dice source reservation* is needed for fully atomic retry of that edge. No false claim of strict cursor atomicity for this new cross-roll operation.
4. **No persistent truth:** working HP and journal are in memory until explicitly exporting a local JSONL; the authoritative Bookkeeper DES-017, persistent event store DES-007, structured rule repository DES-003 and future Adventure/Expedition DB do not exist here. A JSONL file is a local diagnostic artifact, **not** an authoritative event commit or recovery system.
5. **No Geometry Engine:** the current fixture relies solely on authored `MeleeEligibility` pairs. Movement, range, obscure targeting, reach, special/monster powers, changes to equipment, missile and spells remain unsupported. Deferring a due action is a block, not a simulated PASS.
6. **No full application flow:** future DAVOS 025.2 integrates multiple browser/DM prompts and approved trusted command handling, with BON Functional UAT in Iteration 2.4. This module is not exposed directly to untrusted HTTP clients or an LLM as write authority.
7. **No additional house rule:** the owner's `HR-WEAPON-FLAIL-001` changes **base damage only**. It does not authorise bonus hit, special reach, armour penetration, knockdown or initiative mechanics.

## 5. Verification and change record

Focused: `python -m pytest aidm/combat/test/test_engine.py -q --cov=aidm.combat.engine --cov=aidm.combat.rules_reference --cov-report=term-missing`.

Broader offline checks: `python -m pytest aidm/combat/test/test_engine.py aidm/combat/test/test_state.py aidm/combat/test/test_dice.py`.

Final complete PEQUOD evidence must be collected with **`python -m aidm.test_runner`** at the *exact* Draft PR head and clean working tree, preserving run ID, full SHA, all pytest/JUnit outcomes and enforced Python ≥90% coverage. No GitHub CI, browser test or BON Functional UAT is implied by local focused runs.

**Change history:** 2026-11-20 COSTA — Draft first-slice controller, bounded data seam, deterministic replay/safety tests. 2026-11-20 COSTA — Owner requested true simultaneous tied initiative and corrected Functional Story routing to BON UAT; design work independent, developer integration and UAT evidence still pending.