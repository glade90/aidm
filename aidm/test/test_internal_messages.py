"""AIDM-DES-033.1 deterministic contracts and trust-boundary acceptance tests.

Purpose: Validate safe in-process calls with fake tools, never real game writes.
Usage: python -m pytest aidm/test/test_internal_messages.py -q
Change Log: 2026-11-20 COSTA — contract tests; no network/LLM/credentials.
"""

from __future__ import annotations

from dataclasses import FrozenInstanceError

import pytest

from aidm.internal_messages import (
    CommittedEffects, ContractError, ErrorCode, InternalRequest, InternalResult,
    PlayerClarificationRequired, ResultStatus, RulesRulingRequired, SafeError,
    ServiceUnavailable, UnknownOperation, make_child_request, make_request,
    make_result, safe_call, safe_error, safe_failure,
)


def read_request(**changes):
    kwargs = dict(
        request_id="call-7", correlation_id="turn-42", caller="DM",
        capability="exploration", operation="inspect_area",
        payload={"space_id": "room-3"}, knowledge_scope="player",
    )
    kwargs.update(changes)
    return InternalRequest(**kwargs)


def write_request(**changes):
    kwargs = dict(operation="apply_damage", capability="combat", is_mutation=True,
                  command_id="command-1", expected_world_version=7)
    kwargs.update(changes)
    return read_request(**kwargs)


def test_read_only_minimal_request_requires_no_world_or_campaign_context():
    r = make_request(caller="DM", capability="exploration", operation="inspect_area",
                     payload={"space_id": "room-3"}, request_id="call-1")
    assert r.request_id == r.correlation_id == "call-1"
    assert r.expected_world_version is None and r.command_id is None
    assert r.campaign_id is None and r.expedition_id is None and r.session_id is None
    assert r.is_mutation is False


def test_unique_auto_request_ids_and_stable_correlation():
    a = make_request(caller="DM", capability="exploration", operation="inspect_area", payload={})
    b = make_request(caller="DM", capability="exploration", operation="inspect_area", payload={})
    assert a.request_id != b.request_id
    assert a.correlation_id == a.request_id


def test_child_preserves_correlation_has_distinct_invocation_and_parent():
    parent = read_request(session_id="session-a", campaign_id="campaign-a", encounter_id="enc-2")
    child = make_child_request(parent, caller="Expedition", capability="mapping",
                               operation="inspect_exit", payload={"exit_id": "north"})
    assert child.request_id != parent.request_id
    assert child.correlation_id == parent.correlation_id
    assert child.parent_request_id == parent.request_id
    assert child.session_id == "session-a" and child.campaign_id == "campaign-a"
    assert child.encounter_id == "enc-2" and child.knowledge_scope == "player"
    assert child.command_id is None and child.is_mutation is False


def test_child_cannot_rewrite_parent_correlation():
    for name, value in (("correlation_id", "false-turn"), ("parent_request_id", "false-parent")):
        with pytest.raises(ContractError):
            make_child_request(read_request(), caller="DM", capability="exploration",
                               operation="inspect_area", payload={}, **{name: value})


def test_fake_nested_tool_workflow_and_player_safe_projection():
    hidden_world = {"exits": ["north", "west"], "secret_trap": "poison needle behind tapestry"}
    parent = read_request()
    observed = []

    def fake_tool(r):
        observed.append(r)
        # Player projection is deliberately allowlisted by this *trusted fake tool*.
        return make_result(r, ResultStatus.COMPLETED, safe_summary="You see two exits.",
                           data={"exits": list(hidden_world["exits"])})

    def fake_orchestrator(r):
        child = make_child_request(r, caller="Expedition", capability="exploration",
                                   operation="inspect_area", payload=r.payload)
        return safe_call(child, fake_tool, supported_operations={"inspect_area"})

    answer = fake_orchestrator(parent)
    assert answer.status is ResultStatus.COMPLETED
    assert answer.request_id != parent.request_id
    assert answer.correlation_id == parent.correlation_id
    assert len(observed) == 1
    assert answer.safe_summary == "You see two exits."
    assert answer.data == {"exits": ["north", "west"]}
    assert "poison needle" not in repr(answer)
    assert answer.event_refs == () and answer.new_world_version is None


@pytest.mark.parametrize("status", list(ResultStatus))
def test_six_explicit_outcomes(status):
    request = read_request()
    code = (ErrorCode.INVALID_INPUT if status is ResultStatus.ERROR else
            ErrorCode.UNKNOWN_CAPABILITY if status is ResultStatus.BLOCKED else None)
    r = make_result(request, status, safe_summary="This is a safe status.", error_code=code)
    assert r.status == status
    assert r.request_id == request.request_id
    assert r.correlation_id == request.correlation_id
    assert r.event_refs == ()
    assert (r.status is ResultStatus.COMPLETED) == (r.status.value == "COMPLETED")


def test_handoff_is_not_completion_or_committed_state():
    r = make_result(read_request(), ResultStatus.HANDOFF, safe_summary="Needs another component")
    assert r.status is ResultStatus.HANDOFF
    assert r.event_refs == () and r.new_world_version is None


@pytest.mark.parametrize("bad", ["", " ", "str with whitespace", 5, None, "!bad", "a" * 129])
def test_invalid_request_ids_rejected_without_echo(bad):
    with pytest.raises(ContractError) as exc:
        read_request(request_id=bad)
    assert "request_id" in str(exc.value)
    if isinstance(bad, str) and len(bad.strip()) >= 4:
        assert bad not in str(exc.value)


@pytest.mark.parametrize("bad", [{"bad key": 1}, [1], "text", {3: "bad"}])
def test_malformed_payload_is_rejected(bad):
    with pytest.raises(ContractError, match="payload"):
        read_request(payload=bad)


@pytest.mark.parametrize("name", ["operation", "capability"])
def test_invalid_operation_and_capability_are_rejected(name):
    with pytest.raises(ContractError, match=name):
        read_request(**{name: "invalid operation"})


@pytest.mark.parametrize("changes", [
    {"command_id": None}, {"command_id": ""}, {"expected_world_version": None},
    {"expected_world_version": -1}, {"expected_world_version": True},
    {"expected_world_version": "7"},
])
def test_mutation_requires_command_id_and_expected_world_version(changes):
    request = dict(request_id="cmd-req-1", correlation_id="turn-42", caller="DM",
                   capability="combat", operation="apply_damage", payload={}, is_mutation=True,
                   command_id="cmd-1", expected_world_version=7)
    request.update(changes)
    with pytest.raises(ContractError):
        InternalRequest(**request)


def test_read_only_may_not_fake_mutation_metadata():
    with pytest.raises(ContractError, match="Read-only"):
        read_request(command_id="cmd-1")
    with pytest.raises(ContractError, match="Read-only"):
        read_request(expected_world_version=7)


def test_mutation_receipt_requires_trusted_fixture_and_real_command_pair():
    req = write_request()
    assert make_result(req, ResultStatus.COMPLETED).event_refs == ()
    effects = CommittedEffects("command-1", ("evt-10", "evt-11"), 8)
    result = make_result(req, ResultStatus.COMPLETED, committed_effects=effects)
    assert result.event_refs == ("evt-10", "evt-11")
    assert result.new_world_version == 8
    assert result.committed_effects.command_id == req.command_id


def test_no_events_from_read_request_or_unexecuted_action_proposal():
    receipt = CommittedEffects("command-1", ("evt-1",), 8)
    with pytest.raises(ContractError, match="Commit"):
        make_result(read_request(), ResultStatus.COMPLETED, committed_effects=receipt)
    with pytest.raises(ContractError, match="Committed"):
        make_result(write_request(), ResultStatus.HANDOFF, committed_effects=receipt)
    assert make_result(write_request(), ResultStatus.HANDOFF).new_world_version is None


@pytest.mark.parametrize("effect", [
    CommittedEffects("different-command", ("evt-1",), 8),
    CommittedEffects("command-1", ("evt-1",), 7),
    CommittedEffects("command-1", ("evt-1",), 6),
])
def test_invalid_or_stale_commit_receipt_rejected(effect):
    with pytest.raises(ContractError):
        make_result(write_request(), ResultStatus.COMPLETED, committed_effects=effect)


def test_duplicate_committed_event_ids_are_invalid():
    with pytest.raises(ContractError, match="event"):
        CommittedEffects("command-1", ("evt-a", "evt-a"), 8)


def test_duplicate_command_and_stale_version_rejected_by_fake_authority_not_contract():
    applied = set()
    world = {"version": 7, "hp": 10}

    def fake_bookkeeper(request):
        if request.command_id in applied:
            return safe_failure(request, ErrorCode.STATE_VERSION_CONFLICT)
        if request.expected_world_version != world["version"]:
            return safe_failure(request, ErrorCode.STATE_VERSION_CONFLICT)
        applied.add(request.command_id)
        world["hp"] -= 2
        world["version"] += 1
        effects = CommittedEffects(request.command_id, ("evt-damage-1",), world["version"])
        return make_result(request, ResultStatus.COMPLETED, committed_effects=effects)

    req = write_request()
    assert safe_call(req, fake_bookkeeper).event_refs == ("evt-damage-1",)
    assert world == {"version": 8, "hp": 8}
    duplicate = safe_call(req, fake_bookkeeper)
    assert duplicate.status is ResultStatus.ERROR
    assert duplicate.error.code is ErrorCode.STATE_VERSION_CONFLICT
    assert world == {"version": 8, "hp": 8}
    stale = safe_call(write_request(command_id="command-2"), fake_bookkeeper)
    assert stale.status is ResultStatus.ERROR
    assert stale.event_refs == ()
    assert world == {"version": 8, "hp": 8}


def test_unknown_operation_is_blocked_without_invoking_fake():
    count = []
    r = safe_call(read_request(operation="unknown_action"), lambda q: count.append(q),
                  supported_operations={"inspect_area"})
    assert count == []
    assert r.status is ResultStatus.BLOCKED
    assert r.error.code is ErrorCode.UNKNOWN_CAPABILITY
    assert r.error.source_operation == "unknown_action"
    assert r.correlation_id == "turn-42" and r.event_refs == ()


@pytest.mark.parametrize("failure_type,status,code", [
    (UnknownOperation, ResultStatus.BLOCKED, ErrorCode.UNKNOWN_CAPABILITY),
    (PlayerClarificationRequired, ResultStatus.NEEDS_PLAYER_INPUT, ErrorCode.INVALID_INPUT),
    (RulesRulingRequired, ResultStatus.NEEDS_RULING, ErrorCode.UNSUPPORTED_RULE),
    (ServiceUnavailable, ResultStatus.ERROR, ErrorCode.DEPENDENCY_UNAVAILABLE),
    (PermissionError, ResultStatus.BLOCKED, ErrorCode.UNAUTHORISED),
    (TimeoutError, ResultStatus.ERROR, ErrorCode.TIMEOUT),
    (RuntimeError, ResultStatus.ERROR, ErrorCode.INTERNAL_ERROR),
])
def test_tool_errors_are_mapped_without_exposing_exception_text(failure_type,status,code):
    secret = "API-KEY=VERY-SECRET-987"
    def broken(request):
        raise failure_type("internal raw exception " + secret)
    r = safe_call(read_request(), broken)
    assert r.status is status
    assert r.error.code is code
    assert r.event_refs == () and r.new_world_version is None
    assert secret not in str(r)
    assert "internal raw exception" not in str(r)
    assert r.error.correlation_id == "turn-42"
    if failure_type is TimeoutError:
        assert "unknown" in r.error.message.lower()


def test_returned_wrong_identity_or_wrong_return_type_is_error():
    original = read_request()
    incorrect = make_result(read_request(request_id="other"), ResultStatus.COMPLETED)
    for handler in [lambda _: incorrect, lambda _: {"status": "COMPLETED"}]:
        r = safe_call(original, handler)
        assert r.status is ResultStatus.ERROR and r.error.code is ErrorCode.INTERNAL_ERROR


def test_safe_error_only_approved_message_no_raw_secret():
    request = read_request()
    err = safe_error(request, ErrorCode.INTERNAL_ERROR)
    assert err.message == "The operation could not be completed."
    with pytest.raises(ContractError, match="Unsafe"):
        SafeError(ErrorCode.INTERNAL_ERROR, "secret passphrase", request.operation, request.correlation_id)


def test_error_status_cannot_be_disguised_as_success_or_no_error():
    req = read_request()
    with pytest.raises(ContractError):
        make_result(req, ResultStatus.ERROR)
    with pytest.raises(ContractError):
        make_result(req, ResultStatus.COMPLETED, error_code=ErrorCode.INTERNAL_ERROR)
    with pytest.raises(ContractError):
        make_result(req, ResultStatus.HANDOFF, error_code=ErrorCode.INTERNAL_ERROR)


def test_claimed_caller_and_scope_do_not_grant_permissions():
    fake_world = {"hidden_password": "TOPSECRET", "player_view": {"description": "A doorway."}}
    def trusted_tool(request):
        # Trusted test adapter *does not* trust claims of DM or scope='DM'.
        return make_result(request, ResultStatus.COMPLETED,
                           safe_summary="A doorway.", data=dict(fake_world["player_view"]))
    external_claim = read_request(caller="DungeonMaster", knowledge_scope="DM")
    response = safe_call(external_claim, trusted_tool)
    assert "TOPSECRET" not in repr(response)
    assert "hidden_password" not in response.data
    assert response.status is ResultStatus.COMPLETED


def test_payload_is_snapshotted_at_request_boundary():
    original = {"space_id": "room-3"}
    req = read_request(payload=original)
    original["space_id"] = "room-4"
    assert req.payload["space_id"] == "room-3"


def test_request_and_result_records_are_frozen():
    request = read_request()
    result = make_result(request, ResultStatus.COMPLETED)
    with pytest.raises(FrozenInstanceError):
        request.request_id = "different"
    with pytest.raises(FrozenInstanceError):
        result.status = ResultStatus.ERROR


def test_child_cannot_reuse_parent_request_id():
    parent = read_request()
    with pytest.raises(ContractError, match="distinct"):
        make_child_request(parent, caller="DM", capability="exploration",
                           operation="inspect_area", payload={}, request_id=parent.request_id)


def test_invalid_mutation_flag_rejected():
    with pytest.raises(ContractError, match="is_mutation"):
        read_request(is_mutation="true")


def test_safe_error_rejects_arbitrary_code_value():
    request = read_request()
    with pytest.raises(ContractError, match="error_code"):
        safe_error(request, "INTERNAL_ERROR")
    with pytest.raises(ContractError, match="error_code"):
        SafeError("INTERNAL_ERROR", "The operation could not be completed.",
                  request.operation, request.correlation_id)


def test_invalid_result_status_and_safe_summary_rejected():
    request = read_request()
    with pytest.raises(ContractError, match="result status"):
        InternalResult(request.request_id, request.correlation_id, "COMPLETED")
    with pytest.raises(ContractError, match="summary"):
        make_result(request, ResultStatus.COMPLETED, safe_summary="")


def test_mismatched_safe_error_correlation_is_rejected():
    request = read_request()
    another = read_request(correlation_id="different-turn")
    with pytest.raises(ContractError, match="correlation"):
        InternalResult(request.request_id, request.correlation_id, ResultStatus.ERROR,
                       error=safe_error(another, ErrorCode.INTERNAL_ERROR))


def test_safe_call_rejects_handler_supplied_mismatched_command_receipt():
    request = write_request()
    wrong = CommittedEffects("different-command", ("evt-fake",), 8)
    def mismatched_handler(r):
        # A direct constructor cannot verify a receipt against its source request.
        return InternalResult(r.request_id, r.correlation_id, ResultStatus.COMPLETED,
                              committed_effects=wrong)
    result = safe_call(request, mismatched_handler)
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.INTERNAL_ERROR
    assert result.event_refs == ()