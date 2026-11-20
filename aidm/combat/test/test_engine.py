"""DES-001.2 isolated deterministic first-slice rules/controller acceptance.

BON AIDM-CMB-SEQ-001 is still UAT Testing; no formal design approval
or full procedural Mentzer compliance is claimed by these tests.
"""
from __future__ import annotations

from dataclasses import asdict, replace
import json
from pathlib import Path

import pytest

from aidm.combat.dice import DiceRoller, FixedRollSource, FixedRollsExhausted
from aidm.combat.engine import (
    CombatCommand, CombatEngine, CombatError, CombatStatus, DiceKit, Phase,
    SurpriseKind, SurpriseResult, canonical_dice_kit,
)
from aidm.combat.fixtures import canonical_three_vs_three
from aidm.combat.rules_reference import (
    FLAIL_RULE, PrototypeReferenceProvider, RuleProfile, UnsupportedRule,
)
from aidm.combat.state import CombatSide, EncounterParty, Controller, Origin


def scene():
    return canonical_three_vs_three().encounter


def make_engine(values=(), *, surprise_side=None, profile=None, session="test-session", definition=None):
    definition = scene() if definition is None else definition
    profile = profile or RuleProfile(house_rule_overlays=(FLAIL_RULE,),fixture_loadout_confirmed=True)
    surprise = SurpriseResult(SurpriseKind.NONE if surprise_side is None else SurpriseKind.SURPRISING_SIDE,
                              definition.encounter_id,"ENCOUNTER_AGENT","encounter-event-0001",
                              profile.profile_id,surprise_side)
    source = FixedRollSource(values)
    engine = CombatEngine(definition, surprise=surprise,roller=DiceRoller(source),
                          dice=canonical_dice_kit(definition),profile=profile,session_id=session)
    return engine, source


def act(engine, kind="HOLD", target=None, *, id=None):
    decision=engine.next_decision()
    assert decision is not None
    cid=id or f"action.{engine.round_index}.{decision.actor_id}"
    cmd=CombatCommand(cid,engine.session_id,decision.actor_id,decision.version,decision.token,kind,target)
    return decision,engine.submit(cmd)


def events(engine, kind=None):
    e=engine.journal()
    return e if kind is None else tuple(x for x in e if x.kind==kind)


def test_init_is_trusted_external_no_surprise_roll_and_no_implicit_writes():
    engine, source = make_engine([6,3])
    assert source.cursor == 0
    assert engine.snapshot()["version"] == 0
    assert engine.status() is CombatStatus.READY
    assert events(engine,"SURPRISE_INPUT_ACCEPTED")[0].details["resolved_by"] == "ENCOUNTER_AGENT"
    d=engine.next_decision()
    assert d.status is CombatStatus.NEEDS_PLAYER_INPUT and d.actor_id=="alho"
    assert source.cursor==2
    assert engine.version==0
    assert len(events(engine,"SIDE_INITIATIVE"))==1
    assert [x.details["rolls"][i]["die_id"] for x in events(engine,"SIDE_INITIATIVE") for i in (0,1)]==[
        "fixture-party-3v3-initiative-d6","fixture-orcs-side-initiative-d6"]


@pytest.mark.parametrize("kind,side",[(SurpriseKind.NONE,None),(SurpriseKind.SURPRISING_SIDE,"party-3v3"),
                                       (SurpriseKind.SURPRISING_SIDE,"orcs-side")])
def test_surprise_constructor_and_reject_bad_crossed_result(kind,side):
    definition=scene()
    p=RuleProfile()
    good=SurpriseResult(kind,definition.encounter_id,"ENCOUNTER_AGENT","ev-1",p.profile_id,side)
    assert good.surprising_side_id==side
    with pytest.raises(CombatError):
        SurpriseResult(kind,definition.encounter_id,"SCRIPTED_DM","ev-1",p.profile_id,side)
    with pytest.raises(CombatError):
        SurpriseResult(SurpriseKind.NONE,definition.encounter_id,"ENCOUNTER_AGENT","ev-1",p.profile_id,"party-3v3")


def test_missing_or_foreign_surprise_fails_before_any_dice():
    definition=scene()
    profile=RuleProfile()
    kit=canonical_dice_kit(definition)
    source=FixedRollSource([6,4])
    with pytest.raises(CombatError):
        CombatEngine(definition,surprise=None,roller=DiceRoller(source),dice=kit,profile=profile,session_id="s")
    wrong=SurpriseResult(SurpriseKind.SURPRISING_SIDE,definition.encounter_id,"ENCOUNTER_AGENT","ev-1",profile.profile_id,"unknown-side")
    with pytest.raises(CombatError):
        CombatEngine(definition,surprise=wrong,roller=DiceRoller(source),dice=kit,profile=profile,session_id="s")
    assert source.cursor==0


@pytest.mark.parametrize("surprising_side,first_actor,first_side",[
    ("party-3v3","alho","party-3v3"),("orcs-side","orc-01","orcs-side")])
def test_surprise_opening_side_only_then_normal_initiative(surprising_side,first_actor,first_side):
    engine, source=make_engine([6,2],surprise_side=surprising_side)
    first=engine.next_decision()
    assert first.actor_id==first_actor and source.cursor==0 and engine.round_index==1
    for _ in range(3):
        d,result=act(engine)
        assert d.side_id==first_side and result["kind"]=="HOLD"
    next_regular=engine.next_decision()
    assert next_regular is not None and engine.round_index==2
    assert source.cursor==2
    assert len(events(engine,"SURPRISE_OPENING_ROUND_STARTED"))==1
    assert len(events(engine,"SURPRISE_OPENING_ROUND_COMPLETED"))==1
    assert events(engine,"SIDE_INITIATIVE")[0].round_index==2
    assert engine.next_decision()==next_regular  # Repeated read does not reconsumes surprise.


def test_tied_initiative_deferred_simultaneous_damage_killed_orc_attacks_back():
    # Both attackers start the tie alive. Even when Alho's first queued attack
    # would kill orc-01, that orc still gets its full eligible melee attack.
    d=scene()
    alho=replace(d.party.members[0],hp_current=1,armor_class_source=9)
    party=replace(d.party,side=replace(d.party.side,members=(alho,*d.party.members[1:])))
    foe=d.opposing_forces[0]
    orc=replace(foe.side.members[0],hp_current=1)
    force=replace(foe,side=replace(foe.side,members=(orc,*foe.side.members[1:])))
    d=replace(d,party=party,opposing_forces=(force,))
    engine,src=make_engine([4,4, 18,4, 18,4, 6,2],definition=d)
    d1=engine.next_decision()
    assert d1.actor_id=="alho" and src.cursor==2
    assert engine.status() is CombatStatus.NEEDS_PLAYER_INPUT
    assert len(events(engine,"SIMULTANEOUS_EXCHANGE_STARTED"))==1
    assert events(engine,"SIMULTANEOUS_EXCHANGE_STARTED")[0].details["no_side_wins"]
    _,result=act(engine,"ATTACK_MELEE","orc-01")
    assert result["pending_simultaneous_resolution"] is True
    assert result["damage"]==4 and result["outcome"] is None
    assert engine.snapshot()["hp"]["orc-01"]==1  # NOT killed early
    assert not events(engine,"MELEE_RESOLVED")
    for _ in range(2):act(engine)
    assert engine.next_decision().actor_id=="orc-01"  # killed orc still acts
    _,counter=act(engine,"ATTACK_MELEE","alho")
    assert counter["hit"] and counter["pending_simultaneous_resolution"]
    assert engine.snapshot()["hp"]["alho"]==1  # not injured until commit
    for _ in range(2):act(engine)
    next_round=engine.next_decision()
    assert next_round is not None and next_round.round_index==2
    assert next_round.actor_id=="evro"  # both casualties skip NEXT round
    assert engine.snapshot()["hp"]["orc-01"]==0
    assert engine.snapshot()["hp"]["alho"]==0
    assert src.cursor==8  # 2 tied d6 + 2 d20/damage + fresh 2 normal d6
    assert len(events(engine,"SIMULTANEOUS_EXCHANGE_COMMITTED"))==1
    assert len(events(engine,"MELEE_RESOLVED"))==2
    assert all(e.details["simultaneous"] for e in events(engine,"MELEE_RESOLVED"))
    assert {e.actor_id for e in events(engine,"MELEE_RESOLVED")}=={"alho","orc-01"}
    assert len(events(engine,"SIDE_INITIATIVE"))==2
    assert not events(engine,"TIED_INITIATIVE_UNSUPPORTED")


def test_tied_initiative_all_hold_resolves_to_next_round_no_fake_winner():
    e,src=make_engine([3,3, 6,2])
    assert e.next_decision().actor_id=="alho"
    for _ in range(6):
        decision,result=act(e)
        assert result["kind"]=="HOLD"
        assert e.snapshot()["simultaneous_exchange_pending"]
    next_round=e.next_decision()
    assert next_round.round_index==2 and next_round.actor_id=="alho"
    assert src.cursor==4
    assert e.snapshot()["hp"]=={a.encounter_actor_id:a.hp_current for a in scene().members}
    assert len(events(e,"ACTION_HELD"))==6
    assert len(events(e,"SIMULTANEOUS_EXCHANGE_COMMITTED"))==1
    assert events(e,"SIMULTANEOUS_EXCHANGE_COMMITTED")[0].details["hp_deltas"]=={}
    assert len(events(e,"ROUND_COMPLETED"))==1
    assert not events(e,"ENCOUNTER_TERMINAL")


def test_tied_initiative_multiple_hits_aggregate_once_without_sequential_hp():
    # Two characters target the same initially live orc. At the end of the
    # simultaneous exchange one HP update applies the total (not a first hit
    # that prevents the other attack from occurring).
    d=scene()
    foe=d.opposing_forces[0]
    first=replace(foe.side.members[0],hp_current=5)
    d=replace(d,opposing_forces=(replace(foe,side=replace(foe.side,members=(first,*foe.side.members[1:]))),))
    e,src=make_engine([2,2,18,4,18,2,6,2],definition=d)
    _,first_hit=act(e,"ATTACK_MELEE","orc-01")
    _,second_hit=act(e,"ATTACK_MELEE","orc-01")
    assert first_hit["damage"]==4 and second_hit["damage"]==5
    assert e.snapshot()["hp"]["orc-01"]==5
    for _ in range(4):act(e)
    assert e.next_decision().round_index==2
    assert e.snapshot()["hp"]["orc-01"]==0
    results=events(e,"MELEE_RESOLVED")
    assert len(results)==2
    assert all(x.details["hp_before"]==5 and x.details["hp_after"]==0 for x in results)
    assert all(x.details["aggregate_damage"]==9 for x in results)
    assert events(e,"SIMULTANEOUS_EXCHANGE_COMMITTED")[0].details["hp_deltas"]=={"orc-01":-5}
    assert src.cursor==8


def test_tied_initiative_terminal_victory_occurs_only_after_opposing_actions():
    e,src=make_engine([3,3,18,6,18,4,18,4])
    for target in ("orc-01","orc-02","orc-03"):
        _,attack=act(e,"ATTACK_MELEE",target)
        assert attack["pending_simultaneous_resolution"]
    assert all(e.snapshot()["hp"][o]>0 for o in ("orc-01","orc-02","orc-03"))
    assert e.outcome is None
    # Each orc still gets a turn; holds are their deliberately chosen intents.
    for _ in range(3):act(e)
    assert e.outcome is None
    assert e.next_decision() is None
    assert e.outcome=="PARTY_VICTORY"
    assert len(events(e,"ENCOUNTER_TERMINAL"))==1
    assert len(events(e,"MELEE_RESOLVED"))==3
    assert len(events(e,"SIMULTANEOUS_EXCHANGE_COMMITTED"))==1
    assert src.cursor==8
    assert e.next_decision() is None
    assert len(events(e,"ENCOUNTER_TERMINAL"))==1


def test_phase_order_is_side_by_side_not_both_sides_before_action():
    engine,_=make_engine([6,2])
    d=engine.next_decision()
    assert d.actor_id=="alho"
    assert not any(e.side_id=="orcs-side" and e.kind=="PHASE_CHECKPOINT" for e in events(engine))
    for _ in range(3):act(engine)
    d=engine.next_decision()
    assert d.actor_id=="orc-01"
    phase=[(e.phase,e.side_id,e.kind) for e in events(engine)]
    first_melee=next(i for i,x in enumerate(phase) if x==(Phase.MELEE.value,"party-3v3","PHASE_CHECKPOINT"))
    second_morale=next(i for i,x in enumerate(phase) if x==(Phase.MORALE.value,"orcs-side","PHASE_CHECKPOINT"))
    assert first_melee < second_morale
    assert len(events(engine,"SIDE_INITIATIVE"))==1
    statuses=[e.details["status"] for e in events(engine,"PHASE_CHECKPOINT") if e.side_id=="party-3v3"]
    assert statuses==["SCENARIO_RULE_DISABLED","STATIONARY_SCENARIO","SCENARIO_RULE_DISABLED","SCENARIO_RULE_DISABLED","READY_MELEE"]


def test_fixed_raw12_plus_three_hits_orc_and_raw_damage5_plus_three_is_eight():
    engine,src=make_engine([6,3, 12,5])
    act(engine) # Alho HOLD; no weapon die consumed.
    d,result=act(engine,"ATTACK_MELEE","orc-01")
    assert d.actor_id=="evro"
    assert result=={"kind":"ATTACK_MELEE","hit":True,"damage":8,"target_id":"orc-01","version":2,"outcome":None}
    detail=events(engine,"MELEE_RESOLVED")[-1].details
    assert detail["hit_roll"]["face"]==12 and detail["hit_modifier"]["amount"]==3
    assert detail["modified_hit"]==15 and detail["needed_hit"]==14
    assert detail["damage_roll"]["face"]==5 and detail["damage_modifier"]["amount"]==3
    assert detail["hp_before"]==6 and detail["hp_after"]==0
    assert detail["hit_roll"]["source"]=="FIXED" and detail["hit_roll"]["queue_position"]==2
    assert src.cursor==4
    assert engine.snapshot()["hp"]["orc-01"]==0
    assert "hp_before" not in engine.player_view()["transcript"][0]


def test_original_evro_str16_vs_owner_scenario_str18_modifier_source():
    p=PrototypeReferenceProvider();v=scene().party.members[1]
    assert p.strength_modifier(v,"MELEE_TO_HIT").amount==3
    plain=replace(v,scenario_overrides=())
    assert p.strength_modifier(plain,"MELEE_TO_HIT").amount==2
    assert next(x for x in plain.ability_scores if x.name=="STR").source_value==16
    assert next(x for x in v.ability_scores if x.name=="STR").source_value==16
    for a,expect in ((scene().party.members[0],0),(scene().party.members[2],0)):
        assert p.strength_modifier(a,"MELEE_DAMAGE").amount==expect


def test_provisional_shield_components_once_and_alho_unknown():
    p=PrototypeReferenceProvider();scene_def=scene();profile=RuleProfile(fixture_loadout_confirmed=True)
    evro,sho=scene_def.party.members[1:]
    for obj,ac,amounts in ((evro,2,[3,-1]),(sho,1,[3,-1,-1])):
        actual,components=p.effective_ac(obj,profile)
        assert actual==ac and [x.amount for x in components]==amounts
        assert len({x.source_id for x in components})==len(components)
    with pytest.raises(UnsupportedRule):
        p.effective_ac(scene_def.party.members[0],profile)
    with pytest.raises(UnsupportedRule):
        p.effective_ac(evro,RuleProfile(fixture_loadout_confirmed=False))


def test_hit_table_distinguishes_source_class_level_vs_monster_hd():
    p=PrototypeReferenceProvider()
    for a in (scene().party.members[0],scene().party.members[1],scene().party.members[2]):
        assert p.attack_target(a,6)==(14,"BASIC83-CHARACTER-LEVEL1-ATTACK")
    orc=scene().opposing_forces[0].side.members[0]
    assert p.attack_target(orc,2)==(17,"BASIC83-MONSTER-HD1-ATTACK")
    with pytest.raises(UnsupportedRule):p.attack_target(replace(orc,monster_hd_ref="owner.HD5"),1)
    with pytest.raises(UnsupportedRule):p.attack_target(orc,-1)


def test_on_miss_damage_die_not_consumed_and_hp_unchanged():
    engine,src=make_engine([6,3, 1, 9])
    d,result=act(engine,"ATTACK_MELEE","orc-01")
    assert result["hit"] is False and result["damage"]==0
    assert engine.snapshot()["hp"]["orc-01"]==6
    assert src.cursor==3
    assert events(engine,"MELEE_RESOLVED")[0].details["damage_roll"] is None


@pytest.mark.parametrize("with_overlay",[False,True])
def test_flail_owner_house_rule_only_when_explicit_overlay(with_overlay):
    p=RuleProfile(house_rule_overlays=(FLAIL_RULE,) if with_overlay else (),fixture_loadout_confirmed=True)
    engine,src=make_engine([6,2, 16,4],profile=p)
    dec=engine.next_decision()
    assert dec.actor_id=="alho"
    if with_overlay:
        _,result=act(engine,"ATTACK_MELEE","orc-01")
        assert result["damage"]==4 and result["hit"]
        detail=events(engine,"MELEE_RESOLVED")[0].details
        assert detail["weapon_rule_ref"]==FLAIL_RULE
        assert detail["weapon_rule_version"]=="1.0"
        assert detail["damage_roll"]["face"]==4
        assert engine.snapshot()["hp"]["orc-01"]==2
        assert src.cursor==4
    else:
        with pytest.raises(CombatError,match="Flail requires approved"):
            act(engine,"ATTACK_MELEE","orc-01")
        assert src.cursor==2 and engine.version==0 and not events(engine,"MELEE_RESOLVED")
    assert engine.definition.party.members[0].equipped_items[0].item_ref=="flail"


def test_unapproved_flail_no_extra_special_reach_or_armor_piercing():
    p=PrototypeReferenceProvider()
    w=p.weapon("flail",RuleProfile(house_rule_overlays=(FLAIL_RULE,)))
    assert w.sides==6 and w.rule_id==FLAIL_RULE and w.origin=="OWNER_APPROVED_HOUSE_RULE"
    assert not hasattr(w,"reach") and not hasattr(w,"knockdown")


@pytest.mark.parametrize("tamper",[
    "wrong_actor","invalid_target","bad_token","foreign_session","stale_version","unsupported_action"
])
def test_invalid_actions_rejected_without_roll_hp_or_state(tamper):
    engine,src=make_engine([6,2, 20,6])
    d=engine.next_decision();assert d is not None
    cmd=CombatCommand("id1",engine.session_id,d.actor_id,d.version,d.token,"ATTACK_MELEE","orc-01")
    if tamper=="wrong_actor":cmd=replace(cmd,actor_id="evro")
    if tamper=="invalid_target":cmd=replace(cmd,target_id="alho")
    if tamper=="bad_token":cmd=replace(cmd,decision_token="bogus")
    if tamper=="foreign_session":cmd=replace(cmd,session_id="other-session")
    if tamper=="stale_version":cmd=replace(cmd,expected_version=123)
    if tamper=="unsupported_action":cmd=replace(cmd,kind="CAST")
    before=engine.snapshot();count=len(events(engine))
    with pytest.raises(CombatError):engine.submit(cmd)
    assert engine.snapshot()==before and len(events(engine))==count and src.cursor==2
    assert engine.next_decision()==d


def test_duplicate_command_and_stale_replay_do_not_reroll():
    engine,src=make_engine([6,2, 12, 4])
    d=engine.next_decision()
    cmd=CombatCommand("unique-id",engine.session_id,d.actor_id,d.version,d.token,"HOLD")
    engine.submit(cmd)
    v=engine.version;cursor=src.cursor
    with pytest.raises(CombatError):engine.submit(cmd)
    assert engine.version==v and src.cursor==cursor


def test_multiple_actions_same_actor_cannot_react_in_same_round():
    engine,_=make_engine([6,3,6,3])
    seen=[]
    for i in range(6):
        d=engine.next_decision();seen.append(d.actor_id)
        act(engine,id=f"id-{i}")
    assert sorted(seen)==sorted(a.encounter_actor_id for a in scene().members)
    next_d=engine.next_decision()
    # Next round initiative requires new dice; cannot fabricate.
    assert next_d is None or next_d.round_index==2


def test_no_secret_hp_ac_traits_or_unrevealed_actor_in_player_view():
    e,_=make_engine([])
    private=e.snapshot()
    assert private["hp"]["orc-01"]==6
    view=e.player_view()
    orcs=[a for a in view["actors"] if a["side_id"]=="orcs-side"]
    assert len(orcs)==3
    assert all("hp_current" not in a and "hp_max" not in a and "armor_class_source" not in a for a in orcs)
    assert "UNREVEALED_CREATURE_TRAITS" not in json.dumps(view)
    view["actors"][0]["hp_current"]=-111
    assert e.snapshot()["hp"]["alho"]==8
    # Hidden actor is not leaked even as an ID.
    d=scene()
    foe=d.opposing_forces[0]
    hidden=replace(foe.side.members[0],publicly_visible=False)
    hidden_side=replace(foe.side,members=(hidden,*foe.side.members[1:]))
    new_def=replace(d,opposing_forces=(replace(foe,side=hidden_side),))
    x,_=make_engine([],definition=new_def)
    assert "orc-01" not in json.dumps(x.player_view())


def test_journal_event_details_are_not_mutable_aliases():
    e,_=make_engine([6,3,12,5]);act(e);act(e,"ATTACK_MELEE","orc-01")
    original=events(e,"MELEE_RESOLVED")[-1].details["damage"]
    v=list(e.journal());next(x for x in v if x.kind=="MELEE_RESOLVED").details["damage"]=-111
    assert events(e,"MELEE_RESOLVED")[-1].details["damage"]==original
    assert e.player_view()["actors"][3]["defeated"] is True


def test_export_jsonl_is_chronological_safe_nonoverwriting_and_exactly_replayable(tmp_path:Path):
    def run():
        e,_=make_engine([6,3,12,5]);act(e);act(e,"ATTACK_MELEE","orc-01")
        return e
    a=run();b=run()
    assert [asdict(x) for x in a.journal()]==[asdict(x) for x in b.journal()]
    path=a.export_jsonl(tmp_path,name="round01")
    assert str(path).endswith("reports/combat-logs/round01.jsonl")
    lines=[json.loads(x) for x in path.read_text().splitlines()]
    assert len(lines)==len(a.journal()) and [x["seq"] for x in lines]==list(range(1,len(lines)+1))
    resolved=next(x for x in lines if x["kind"]=="MELEE_RESOLVED")
    assert resolved["details"]["hit_roll"]["source"]=="FIXED"
    with pytest.raises(CombatError):a.export_jsonl(tmp_path,name="round01")
    with pytest.raises(CombatError):a.export_jsonl(tmp_path,name="../outside")
    assert not (tmp_path/"outside.jsonl").exists()


@pytest.mark.parametrize("flag",["missile_enabled","magic_enabled","stationary_fixture"])
def test_enabled_but_unimplemented_phase_blocks_truthfully(flag):
    p=RuleProfile(house_rule_overlays=(FLAIL_RULE,),fixture_loadout_confirmed=True)
    p=replace(p,**{flag:False if flag=="stationary_fixture" else True})
    e,s=make_engine([6,3],profile=p)
    assert e.next_decision() is None and e.status() is CombatStatus.NEEDS_RULING
    assert not events(e,"MELEE_RESOLVED") and e.version==0
    assert any(x.details.get("status")=="BLOCKED_UNIMPLEMENTED" for x in events(e,"PHASE_CHECKPOINT"))


def test_due_group_morale_halts_without_fake_check_and_single_group_trigger():
    # 1 HP monster, so a single legal flail hit triggers first death.
    d=scene();foe=d.opposing_forces[0]
    m=replace(foe.side.members[0],hp_current=1)
    new_side=replace(foe.side,members=(m,*foe.side.members[1:]))
    d=replace(d,opposing_forces=(replace(foe,side=new_side),))
    p=RuleProfile(house_rule_overlays=(FLAIL_RULE,),fixture_loadout_confirmed=True,morale_enabled=True)
    e,s=make_engine([6,3,18,4],definition=d,profile=p)
    dec,result=act(e,"ATTACK_MELEE","orc-01")
    assert result["damage"]==4 and e.snapshot()["hp"]["orc-01"]==0
    assert e.status() is CombatStatus.NEEDS_RULING and e.next_decision() is None
    morale=events(e,"MORALE_TRIGGER")
    assert len(morale)==1
    assert morale[0].details=={"group_id":"orc-group-01","trigger_id":"FIRST_DEATH_EITHER_SIDE",
                               "status":"BLOCKED_UNIMPLEMENTED","no_roll_performed":True}
    assert not events(e,"ENCOUNTER_TERMINAL")
    assert len(events(e,"MELEE_RESOLVED"))==1


def test_morale_disabled_records_source_rule_config_not_false_check():
    e,_=make_engine([6,3,18,6])
    act(e,"ATTACK_MELEE","orc-01")
    assert len(events(e,"MORALE_TRIGGER"))==1
    assert events(e,"MORALE_TRIGGER")[0].details["status"]=="SCENARIO_RULE_DISABLED"
    assert e.status() is CombatStatus.READY


def test_two_rounds_can_resolve_supported_actions_with_independent_side_turns():
    # Each side has a complete selected initiative pair per NORMAL round.
    # Round1: party first. Alho holds, Evro hits orc1 for 4, Sho hits orc2 for 2.
    # Orcs hold. Round2: party first, flail kills orc3, Evro kills orc1,
    # Sho kills orc2. All state is computed from raw face values.
    seq=[6,3, 12,1, 15,2, 5,1, 18,4, 16,2, 16,3]
    e,src=make_engine(seq)
    assert e.next_decision().actor_id=="alho"
    act(e)                                # alho holds
    act(e,"ATTACK_MELEE","orc-01")     # evro 12 +3 hits, 1+3 =4 -> orc1 2
    act(e,"ATTACK_MELEE","orc-02")     # sho 15 hits; 2 -> orc2 2
    for _ in range(3):act(e)             # orcs hold
    d=e.next_decision();assert d.round_index==2 and d.actor_id=="alho"
    act(e,"ATTACK_MELEE","orc-03")     # flail 18 & 4 -> orc3 0
    act(e,"ATTACK_MELEE","orc-01")     # evro 16 & 2+3 -> orc1 0
    act(e,"ATTACK_MELEE","orc-02")     # sho 16 & 3 -> orc2 0
    assert e.outcome=="PARTY_VICTORY"
    assert e.next_decision() is None
    assert e.snapshot()["hp"]=={"alho":8,"evro":8,"sho-rembo":9,"orc-01":0,"orc-02":0,"orc-03":0}
    assert e.version==9 and src.cursor==14
    assert len(events(e,"SIDE_INITIATIVE"))==2
    assert len(events(e,"ENCOUNTER_TERMINAL"))==1
    assert len(events(e,"MORALE_TRIGGER"))==2 # first death and half unavailable only
    assert e.player_view()["outcome"]=="PARTY_VICTORY"
    assert all(x["status"] in ("SCENARIO_RULE_DISABLED","STATIONARY_SCENARIO","READY_MELEE")
               for x in (entry.details for entry in events(e,"PHASE_CHECKPOINT")))


def test_unavailable_dice_produces_no_fake_HP_or_success():
    e,src=make_engine([6,3])
    d=e.next_decision()
    before=e.snapshot();loglen=len(events(e))
    with pytest.raises(FixedRollsExhausted):
        act(e,"ATTACK_MELEE","orc-01")
    assert src.cursor==2 and e.snapshot()==before and len(events(e))==loglen


def test_malformed_damage_die_descriptor_prevented_before_attack_roll():
    d=scene();kit=canonical_dice_kit(d)
    from aidm.combat.dice import Die
    badkit=DiceKit(kit.initiative,kit.attack,{**kit.damage,"alho":Die("incorrect-die",8,"blue")})
    p=RuleProfile(house_rule_overlays=(FLAIL_RULE,),fixture_loadout_confirmed=True)
    src=FixedRollSource([6,2,18,4])
    e=CombatEngine(d,surprise=SurpriseResult(SurpriseKind.NONE,d.encounter_id,"ENCOUNTER_AGENT","ev-1",p.profile_id),
                   roller=DiceRoller(src),dice=badkit,profile=p,session_id="test-session")
    e.next_decision()
    with pytest.raises(CombatError,match="damage die"):
        act(e,"ATTACK_MELEE","orc-01")
    assert src.cursor==2 and e.version==0


def test_public_declared_targets_do_not_reveal_hidden_foe_ids():
    d=scene();force=d.opposing_forces[0]
    hidden=replace(force.side.members[0],publicly_visible=False)
    side=replace(force.side,members=(hidden,*force.side.members[1:]))
    d=replace(d,opposing_forces=(replace(force,side=side),))
    e,_=make_engine([6,3],definition=d)
    first=e.next_decision()
    assert first.actor_id=="alho"
    assert "orc-01" not in first.allowed_targets
    assert set(first.allowed_targets)=={"orc-02","orc-03"}
    with pytest.raises(CombatError):act(e,"ATTACK_MELEE","orc-01")


def test_provider_swap_retains_same_reproducible_mechanical_outcome():
    d=scene()
    class ProviderProxy:
        def __init__(self): self.other=PrototypeReferenceProvider()
        def weapon(self,*a):return self.other.weapon(*a)
        def attack_target(self,*a):return self.other.attack_target(*a)
        def effective_ac(self,*a):return self.other.effective_ac(*a)
        def strength_modifier(self,*a):return self.other.strength_modifier(*a)
    p=RuleProfile(house_rule_overlays=(FLAIL_RULE,),fixture_loadout_confirmed=True)
    a,_=make_engine([6,3,12,5])
    b,_=make_engine([6,3,12,5])
    b.provider=ProviderProxy()
    for x in (a,b):
        act(x)
        act(x,"ATTACK_MELEE","orc-01")
    assert a.snapshot()==b.snapshot()
    assert [asdict(x) for x in a.journal()]==[asdict(x) for x in b.journal()]


def test_owner_party_defeat_is_deterministic_fixture_state_not_narration():
    d=scene()
    # Distinct synthetic test-only state: existing character source is untouched.
    party=replace(d.party.side,members=tuple(replace(a,hp_current=1,armor_class_source=9)
                                              for a in d.party.members))
    d=replace(d,party=replace(d.party,side=party))
    e,src=make_engine([1,6, 18,2, 18,2, 18,2],definition=d)
    assert e.next_decision().actor_id=="orc-01"
    act(e,"ATTACK_MELEE","alho")
    act(e,"ATTACK_MELEE","evro")
    act(e,"ATTACK_MELEE","sho-rembo")
    assert e.outcome=="PARTY_DEFEAT"
    assert e.snapshot()["hp"]["alho"]==0
    assert e.snapshot()["hp"]["evro"]==0
    assert e.snapshot()["hp"]["sho-rembo"]==0
    assert len(events(e,"ENCOUNTER_TERMINAL"))==1
    assert e.next_decision() is None
    assert src.cursor==8


def test_fixed_queue_missing_damage_has_no_state_commit_but_known_cursor_limit():
    e,src=make_engine([6,3,18])
    e.next_decision()
    original=e.snapshot();journal_len=len(e.journal())
    with pytest.raises(FixedRollsExhausted):
        act(e,"ATTACK_MELEE","orc-01")
    assert e.snapshot()==original
    assert len(e.journal())==journal_len
    # Accepted 005.2 roller returns its raw d20 immediately; source does not
    # offer a transaction for conditionally-required damage. The consumed hit
    # face cannot be rolled back here. An explicit source transaction is debt,
    # not falsely declared safe replay of the incomplete command.
    assert src.cursor==3


def test_selected_dice_kit_is_immutable_even_if_caller_reassigns_mapping():
    kit=canonical_dice_kit(scene())
    original=kit.attack["alho"].die_id
    with pytest.raises(TypeError):
        kit.attack["alho"]=kit.attack["evro"]
    caller=dict(kit.attack)
    kit2=DiceKit(kit.initiative,caller,kit.damage)
    caller["alho"]=kit.attack["evro"]
    assert kit2.attack["alho"].die_id==original


def test_unavailable_side_initiative_blocks_once_without_double_round_start():
    e,src=make_engine([6])
    assert e.next_decision() is None and e.status() is CombatStatus.NEEDS_RULING
    assert src.cursor==0
    assert len(events(e,"ROUND_STARTED"))==1
    assert len(events(e,"INITIATIVE_SOURCE_UNAVAILABLE"))==1
    e.next_decision()
    assert len(events(e,"ROUND_STARTED"))==1
    assert e.version==0 and src.cursor==0


def test_invalid_command_identifier_types_fail_safe_before_membership_check():
    e,src=make_engine([6,3,16,4])
    d=e.next_decision()
    for bad_id in (["unhashable"],"../escape","",None):
        bad=CombatCommand(bad_id,e.session_id,d.actor_id,d.version,d.token,"HOLD")
        with pytest.raises(CombatError,match="Invalid command identifier"):
            e.submit(bad)
    bad=CombatCommand("valid",e.session_id,d.actor_id,True,d.token,"HOLD")
    with pytest.raises(CombatError,match="Invalid expected state version"):
        e.submit(bad)
    assert src.cursor==2 and e.version==0