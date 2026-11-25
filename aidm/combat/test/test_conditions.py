"""AIDM-DES-006.4 source-constrained generic condition engine tests.

Offline tests. Callers mint synthetic verified rule events; no poison effects,
spell rulings, death or source-world status decisions are implemented here.
"""
from dataclasses import replace

import pytest

from aidm.combat.state import Combatant, Origin, Controller
from aidm.combat.conditions import (
    ApplyCondition, ActorConditionSnapshot, ConditionCommand, ConditionDefinition,
    ConditionError, ConditionErrorCode, ConditionEventAuthority,
    ConditionLedgerSnapshot, ConditionStateService, ConditionStatus,
    EncounterActorIndex, RemoveCondition,
)
from aidm.timekeeping.clock import (
    ClockEventAuthority, ClockCommand, ClockRoundCompleted,
    GameClock, MENTZER_BASIC_1983,
)


def actors():
    return EncounterActorIndex((
        Combatant("pc-alpha", "Character", "party", Origin.CHARACTER,
                  "owner.pc", Controller.HUMAN, 8, 8),
        Combatant("mob-1", "Orc", "monsters", Origin.CREATURE,
                  "owner.orc", Controller.SCRIPTED, 4, 4, publicly_visible=True),
        Combatant("mob-hidden", "Hidden creature", "monsters", Origin.CREATURE,
                  "owner.monster", Controller.SCRIPTED, 5, 5),
    ))


def ready(*, definitions=None):
    authority = ConditionEventAuthority()
    idx = actors()
    kwargs = {} if definitions is None else {"definitions": definitions}
    service = ConditionStateService(idx, authority, clock_id="test-clock", **kwargs)
    return service, authority, idx


def command(s, auth, actor_id, operation, event_id, *, action_id=None, version=None, source='test.rule'):
    action_id = action_id or "action-" + event_id
    return ConditionCommand(action_id, event_id, actor_id,
                            s.get_active(actor_id).condition_version if version is None else version,
                            "corr-" + action_id,
                            auth.verified(event_id, actor_id, operation, source))


def apply(s, auth, actor_id, code="POISONED", *, event="event-1", instance=None,
          source='test.rule', applied_at=None, expires_at=None,
          params=(), version=None):
    cmd = command(s, auth, actor_id, "APPLY", event, version=version, source=source)
    return ApplyCondition(cmd, instance or ("inst-"+event), code, None,
                          "mentzer.synthetic", source,
                          applied_at_game_seconds=applied_at,
                          expiry_at_game_seconds=expires_at, parameters=params)


def remove(s, auth, actor_id, instance, event):
    src="test.rule"
    return RemoveCondition(command(s, auth, actor_id, "REMOVE", event, source=src), instance, src)


def rejected(s, code, call):
    snap=s.snapshot()
    with pytest.raises(ConditionError) as error:
        call()
    assert error.value.code is code
    assert s.snapshot()==snap


def test_01_registration_and_actor_isolation_existing_combatant_hp_unchanged():
    s,a,idx=ready()
    pc=idx.get('pc-alpha')
    s.apply(apply(s,a,'pc-alpha',event='poison'))
    s.apply(apply(s,a,'mob-1','ASLEEP',event='sleep'))
    assert s.get_active('pc-alpha').active[0].code=='POISONED'
    assert s.get_active('mob-1').active[0].code=='ASLEEP'
    assert s.get_active('mob-hidden').active==()
    assert idx.get('pc-alpha') is pc
    assert pc.hp_current==8
    assert s.get_active('pc-alpha').condition_version==1


def test_02_concurrent_different_named_flags_independent_remove():
    s,a,_=ready()
    s.apply(apply(s,a,'pc-alpha',event='p1'))
    s.apply(apply(s,a,'pc-alpha','NAUSEATED',event='p2'))
    s.apply(apply(s,a,'pc-alpha','ASLEEP',event='p3'))
    assert {x.code for x in s.get_active('pc-alpha').active}=={'POISONED','NAUSEATED','ASLEEP'}
    receipt=s.remove(remove(s,a,'pc-alpha','inst-p2','remove-p2'))
    assert receipt.status is ConditionStatus.REMOVED
    assert {x.code for x in s.get_active('pc-alpha').active}=={'POISONED','ASLEEP'}


def test_03_repeated_action_id_replay_even_after_actor_version_changed():
    s,a,_=ready()
    req=apply(s,a,'pc-alpha',event='first')
    receipt=s.apply(req)
    s.apply(apply(s,a,'pc-alpha','NAUSEATED',event='second'))
    assert s.apply(req) is receipt
    assert s.read_action_receipt(req.command.action_id) is receipt
    assert s.get_active('pc-alpha').condition_version==2


def test_04_conflicting_action_and_duplicate_source_event_fail_closed():
    s,a,_=ready()
    req=apply(s,a,'pc-alpha',event='same')
    s.apply(req)
    rejected(s,ConditionErrorCode.REPLAY_CONFLICT,
             lambda:s.apply(replace(req,code='ASLEEP')))
    duplicate=replace(req, command=replace(req.command, action_id='different-id',
                                          correlation_id='different-corr',expected_actor_version=1))
    rejected(s,ConditionErrorCode.DUPLICATE_EVENT,lambda:s.apply(duplicate))
    rejected(s,ConditionErrorCode.DUPLICATE_EVENT,
             lambda:s.apply(apply(s,a,'pc-alpha',event='new',instance='inst-same')))


def test_05_apply_remove_idempotent_and_cannot_remove_twice():
    s,a,_=ready()
    s.apply(apply(s,a,'pc-alpha'))
    cmd=remove(s,a,'pc-alpha','inst-event-1','rem')
    receipt=s.remove(cmd)
    assert s.remove(cmd) is receipt
    rejected(s,ConditionErrorCode.NOT_ACTIVE,
             lambda:s.remove(remove(s,a,'pc-alpha','inst-event-1','rem2')))
    assert s.get_active('pc-alpha').active==()


def test_06_unregistered_and_unsupported_stacking_and_independent_policy():
    s,a,_=ready()
    rejected(s,ConditionErrorCode.UNKNOWN_CONDITION,
             lambda:s.apply(apply(s,a,'pc-alpha','CHUCKLE',event='x')))
    s.apply(apply(s,a,'pc-alpha',event='x'))
    rejected(s,ConditionErrorCode.UNSUPPORTED_STACKING,
             lambda:s.apply(apply(s,a,'pc-alpha',event='y')))
    s2,a2,_=ready(definitions=(ConditionDefinition('POISONED',True),))
    s2.apply(apply(s2,a2,'pc-alpha',event='p1'))
    s2.apply(apply(s2,a2,'pc-alpha',event='p2'))
    assert len(s2.get_active('pc-alpha').active)==2


def test_07_bad_authority_mismatch_and_version_and_nonexistent_actor():
    s,a,_=ready()
    other=ConditionEventAuthority()
    forged=apply(s,other,'pc-alpha',event='e-forged')
    rejected(s,ConditionErrorCode.UNAUTHORISED,lambda:s.apply(forged))
    rejected(s,ConditionErrorCode.STALE_VERSION,
             lambda:s.apply(apply(s,a,'pc-alpha',event='stale',version=99)))
    req=apply(s,a,'pc-alpha',event='target')
    rejected(s,ConditionErrorCode.UNAUTHORISED,
             lambda:s.apply(replace(req,command=replace(req.command,actor_id='mob-1'))))
    with pytest.raises(ConditionError) as error:
        s.get_active('unknown')
    assert error.value.code==ConditionErrorCode.UNKNOWN_ACTOR


def test_08_invalid_duration_typed_params_and_unknown_source():
    s,a,_=ready()
    rejected(s,ConditionErrorCode.INVALID_DEADLINE,
             lambda:s.apply(apply(s,a,'pc-alpha',event='exp1',applied_at=10,expires_at=10)))
    rejected(s,ConditionErrorCode.INVALID_DEADLINE,
             lambda:s.apply(apply(s,a,'pc-alpha',event='exp2',expires_at=20)))
    rejected(s,ConditionErrorCode.INVALID,
             lambda:s.apply(apply(s,a,'pc-alpha',event='params',params=(('invalid',object()),))))
    rejected(s,ConditionErrorCode.INVALID,
             lambda:s.apply(apply(s,a,'pc-alpha',event='params2',params=(('a',2),('a',3)))))
    req=apply(s,a,'pc-alpha',event='origin')
    rejected(s,ConditionErrorCode.UNKNOWN_ACTOR,
             lambda:s.apply(replace(req,source_actor_id='not-an-actor')))


def clock(s, *, rounds=1):
    event=ClockEventAuthority()
    c=GameClock.create_clock('campaign',MENTZER_BASIC_1983,event,clock_id=s.clock_id)
    result=[]
    for n in range(1,rounds+1):
        eid=f'completed-round-{n}'
        env=ClockCommand(c.clock_id,'COMBAT',f'adv-{n}',eid,c.read_clock().version,
                         c.profile.ref,f'corr-adv-{n}')
        cmd=ClockRoundCompleted(env,'encounter',n,
                                event.completed_round(c.clock_id,eid,'encounter',n))
        result.append(c.complete_combat_round(cmd))
    return result


def test_09_due_boundary_and_exactly_once_clock_receipts():
    s,a,_=ready()
    s.apply(apply(s,a,'pc-alpha',event='p',applied_at=0,expires_at=20))
    s.apply(apply(s,a,'pc-alpha','NAUSEATED',event='n',applied_at=0,expires_at=30))
    s.apply(apply(s,a,'mob-1','ASLEEP',event='s',applied_at=0,expires_at=20))
    s.apply(apply(s,a,'mob-hidden','POISONED',event='indefinite'))
    clock_receipts=clock(s,rounds=3)
    assert s.get_due(10)==()
    assert len(s.get_due(20))==2
    assert s.process_due(clock_receipts[0],authority=a)==()
    first=s.process_due(clock_receipts[1],authority=a)
    assert len(first)==2
    assert s.process_due(clock_receipts[1],authority=a)==first
    assert len(s.get_active('pc-alpha').active)==1
    last=s.process_due(clock_receipts[2],authority=a)
    assert len(last)==1
    assert s.get_active('pc-alpha').active==()
    assert s.get_active('mob-hidden').active[0].code=='POISONED'


def test_10_clock_replay_and_false_caller_fail_without_mutation():
    s,a,_=ready()
    adv=clock(s,rounds=2)
    rejected(s,ConditionErrorCode.UNAUTHORISED,
             lambda:s.process_due(adv[0],authority=ConditionEventAuthority()))
    rejected(s,ConditionErrorCode.CLOCK_REPLAY,
             lambda:s.process_due(adv[1],authority=a))
    assert s.process_due(adv[0],authority=a)==()
    rejected(s,ConditionErrorCode.CLOCK_REPLAY,
             lambda:s.process_due(replace(adv[0],receipt_id=adv[0].receipt_id+'different'),authority=a))
    assert s.process_due(adv[1],authority=a)==()


def test_11_safe_view_only_allowlisted_no_source_or_deadline_leak():
    s,a,_=ready()
    s.apply(apply(s,a,'mob-hidden',event='secret',applied_at=0,expires_at=123))
    s.apply(apply(s,a,'mob-1','ASLEEP',event='visible'))
    assert s.get_player_safe('mob-hidden',visible_actor_ids=('pc-alpha','mob-1'))==()
    assert s.get_player_safe('mob-1',visible_actor_ids=('pc-alpha','mob-1'))==('ASLEEP',)
    assert s.get_player_safe('pc-alpha',visible_actor_ids=('pc-alpha','mob-1'))==()
    assert 'secret' not in repr(s.get_player_safe('mob-hidden',visible_actor_ids=('pc-alpha',)))


def test_12_snapshot_restore_action_ledger_and_clock_expiry():
    s,a,idx=ready()
    req=apply(s,a,'pc-alpha',event='event1',applied_at=0,expires_at=10)
    before=s.apply(req)
    snap=s.snapshot()
    recovered=ConditionStateService.restore(snap,idx,a)
    assert recovered.apply(req)==before
    advance=clock(s)[0]
    done=recovered.process_due(advance,authority=a)
    assert len(done)==1
    restored=ConditionStateService.restore(recovered.snapshot(),idx,a)
    assert restored.process_due(advance,authority=a)==done
    assert restored.get_active('pc-alpha').active==()
    bad=replace(snap,latest_clock_seconds=-1)
    with pytest.raises(ConditionError) as err:
        ConditionStateService.restore(bad,idx,a)
    assert err.value.code==ConditionErrorCode.CORRUPT_SNAPSHOT


def test_13_no_unintended_mutation_of_fixture_actor_references():
    s,a,idx=ready()
    actor=idx.get('mob-1')
    hp=actor.hp_current
    snap=s.snapshot()
    s.apply(apply(s,a,'mob-1','ASLEEP',event='sleep'))
    assert actor.hp_current==hp
    assert snap.actors[1].instances==()
    assert s.snapshot().actors[1].instances[0].status==ConditionStatus.ACTIVE


def test_14_actor_registry_rejects_duplicates_and_nonimmutable_stacking():
    a=actors().get('pc-alpha')
    with pytest.raises(ConditionError):
        EncounterActorIndex((a,a))
    with pytest.raises(ConditionError):
        ConditionDefinition('x',independent_instances='yes')


def test_15_actual_existing_3v3_combatant_identity_and_hp_preservation():
    from aidm.combat.fixtures import canonical_three_vs_three
    fixture=canonical_three_vs_three()
    index=EncounterActorIndex(fixture.encounter.members)
    trusted=ConditionEventAuthority()
    service=ConditionStateService(index,trusted,clock_id='test-clock')
    initial_hp={actor.encounter_actor_id:actor.hp_current for actor in fixture.encounter.members}
    assert len(initial_hp)==6
    service.apply(apply(service,trusted,'alho',event='goblin-bite-status'))
    service.apply(apply(service,trusted,'orc-01','ASLEEP',event='synthetic-sleep'))
    assert {a.encounter_actor_id:a.hp_current for a in fixture.encounter.members}==initial_hp
    assert service.get_active('alho').active[0].code=='POISONED'
    assert service.get_active('orc-01').active[0].code=='ASLEEP'


def test_16_hidden_opponent_is_not_revealed_even_if_in_display_allowlist():
    service,auth,_=ready()
    service.apply(apply(service,auth,'mob-hidden',event='hidden-cond'))
    assert service.get_player_safe('mob-hidden',visible_actor_ids=('mob-hidden',))==()
    service.apply(apply(service,auth,'pc-alpha','ASLEEP',event='pc-status'))
    assert service.get_player_safe('pc-alpha',visible_actor_ids=('pc-alpha',))==('ASLEEP',)


def test_17_full_clock_receipt_fingerprint_detects_same_id_modified_payload():
    service,auth,_=ready()
    receipt=clock(service)[0]
    assert service.process_due(receipt,authority=auth)==()
    rejected(service,ConditionErrorCode.CLOCK_REPLAY,
             lambda:service.process_due(replace(receipt,source_event_id='forged'),authority=auth))
