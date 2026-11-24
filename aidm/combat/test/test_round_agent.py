"""AIDM-DES-004.2 specialist agent fixed-model contract and trust boundary tests.

Run: python -m pytest aidm/combat/test/test_round_agent.py -q
"""
from __future__ import annotations

import json
import pytest
from braider import ModelTarget, ContextItem
from aidm.combat.live_policy import OpenAIResponsesPolicy
from aidm.combat.round_agent import CombatRoundAgent, ResponsesBraiderRuntime


class QueueRuntime:
    def __init__(self, *responses):
        self.responses=list(responses)
        self.calls=[]

    def invoke(self, *, model_target, instructions, input_text, approved_context):
        self.calls.append((input_text, dict(approved_context), instructions))
        response=self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


def fake_agent(*responses):
    provider=QueueRuntime(*responses)
    agent=CombatRoundAgent(runtime=provider,model_target=ModelTarget("fake","model"))
    return agent,provider


def test_braider_specialist_preserves_original_player_intent_and_allowlist():
    a,p=fake_agent('{"kind":"ATTACK_MELEE","target_id":"orc-02"}')
    raw="  Sho, strike Orc 2!  "
    assert a.propose_scoped(player_text=raw,actor_id="sho-rembo",
                            allowed_targets=("orc-01","orc-02"),
                            trusted_context={"round":2,"visible_foes":["orc-02"]},
                            trace_id="corr-22")==("ATTACK_MELEE","orc-02")
    payload=json.loads(p.calls[0][0]); assert payload["original_player_text"]==raw
    approved=json.loads(p.calls[0][1][ContextItem.TASK_CONTEXT])
    assert approved["player_visible_state"]["round"]==2
    assert a.mode=="LIVE_LLM" and a.narrate_on_round_complete


@pytest.mark.parametrize("raw",[
    '{"kind":"ATTACK_MELEE","target_id":"orc-99"}',
    '{"kind":"ATTACK_MELEE","target_id":null}',
    '{"kind":"CAST","target_id":"orc-01"}',
    '{"kind":"HOLD","target_id":"orc-01"}',
    '{"kind":"HOLD","target_id":null,"damage":999}',
    'not json',
])
def test_untrusted_invalid_model_proposals_are_never_executable(raw):
    a,_=fake_agent(raw)
    assert a.propose(player_text="attack",actor_id="alho",allowed_targets=("orc-01",))==("NEEDS_CLARIFICATION",None)


def test_explicit_hold_and_unsupported_are_not_fabricated_attacks():
    a,_=fake_agent('{"kind":"HOLD","target_id":null}',
                   '{"kind":"UNSUPPORTED_RULE","target_id":null}')
    assert a.propose(player_text="hold",actor_id="alho",allowed_targets=("orc-01",))==("HOLD",None)
    assert a.propose(player_text="cast unknown",actor_id="alho",allowed_targets=("orc-01",))==("UNSUPPORTED_RULE",None)


def test_failure_is_safe_and_not_retried():
    a,p=fake_agent(RuntimeError("PRIVATE_API_KEY_123"))
    with pytest.raises(RuntimeError,match="Specialist model unavailable"):
        a.propose(player_text="attack",actor_id="alho",allowed_targets=("orc-01",))
    assert len(p.calls)==1


def test_only_verified_public_events_go_to_narration():
    a,p=fake_agent("The fallen opponent slumps to the stones.")
    assert a.narrate(verified_events=()) is None
    s=a.narrate(verified_events=("Orc 1 falls", "Alho holds"))
    assert "slumps" in s
    payload=json.loads(p.calls[0][0]);assert payload=={"task":"NARRATE","verified_public_events":["Orc 1 falls","Alho holds"]}
    assert len(p.calls)==1


def test_live_responses_reuses_existing_injected_transport_no_second_provider():
    calls=[]
    def transport(payload,key,timeout):
        calls.append((json.loads(payload),key,timeout))
        return {"output":[{"type":"message","content":[{"type":"output_text","text":'{"kind":"ATTACK_MELEE","target_id":"orc-01"}'}]}]}
    policy=OpenAIResponsesPolicy(api_key="synthetic-not-real-key",model="fixture-mini",transport=transport)
    agent=CombatRoundAgent.from_live_policy(policy)
    assert isinstance(agent._runtime,ResponsesBraiderRuntime)
    assert agent.propose(player_text="attack orc one",actor_id="alho",allowed_targets=("orc-01",))==("ATTACK_MELEE","orc-01")
    assert len(calls)==1 and calls[0][1]=="synthetic-not-real-key"
    req=calls[0][0];assert req["model"]=="fixture-mini" and req["store"] is False
    assert "synthetic-not-real-key" not in json.dumps(req)