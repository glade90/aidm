"""AIDM combat specialist contracts and rules-neutral raw dice.

Usage: from aidm.combat import CombatAgent, Die, DiceRoller, MockEncounterState
Change Log: 2026-11-20 COSTA — AIDM-DES-004.1 initial combat stub.
            2026-11-20 COSTA — AIDM-DES-005.2 raw dice architecture correction.
            2026-11-20 COSTA — AIDM-DES-006.2 mock combat state fixtures.
"""

from .agent import CombatAgent, MOCK_COMBAT_OPERATION
from .dice import (
    Die, DiceRoller, FixedRollOutOfRange, FixedRollSource, FixedRollsExhausted,
    InvalidDiceRequest, InvalidRollSource, RawDieResult, RollSource,
    RollSourceKind, SourceFace, SystemRandomSource,
)

from .state import (
    AbilityValue, ActorHPChange, ActorPlacement, ApprovedFixtureEffect, AreaRef,
    BattlegroundDefinition, CombatSide, Combatant, Controller, DeclaredAction,
    EncounterDefinition, EncounterParty, EncounterSnapshot, FixtureDefinition,
    FixtureError, FixtureErrorCode, FixtureOutcome, MeleeEligibility,
    MockEncounterState, MonsterDefinitionSnapshot, MonsterGroup, OpposingForce,
    Origin, PositionRef, ProposalStatus, RecordedRollAssociation, ScenarioOverride,
    SpatialModel, Visibility, ZoneRelation,
)
from .fixtures import two_by_two, canonical_three_vs_three, variable_three_vs_four

__all__ = [
    "CombatAgent", "MOCK_COMBAT_OPERATION", "Die", "DiceRoller",
    "FixedRollOutOfRange", "FixedRollSource", "FixedRollsExhausted",
    "InvalidDiceRequest", "InvalidRollSource", "RawDieResult",
    "RollSource", "RollSourceKind", "SourceFace", "SystemRandomSource",
    "AbilityValue", "ActorHPChange", "ActorPlacement", "ApprovedFixtureEffect", "AreaRef",
    "BattlegroundDefinition", "CombatSide", "Combatant", "Controller", "DeclaredAction",
    "EncounterDefinition", "EncounterParty", "EncounterSnapshot", "FixtureDefinition",
    "FixtureError", "FixtureErrorCode", "FixtureOutcome", "MeleeEligibility",
    "MockEncounterState", "MonsterDefinitionSnapshot", "MonsterGroup", "OpposingForce",
    "Origin", "PositionRef", "ProposalStatus", "RecordedRollAssociation", "ScenarioOverride",
    "SpatialModel", "Visibility", "ZoneRelation", "two_by_two",
    "canonical_three_vs_three", "variable_three_vs_four",
]