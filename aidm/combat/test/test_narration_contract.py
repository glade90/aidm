"""AIDM-DES-004.2.1 — one-call narration response acceptance matrix.

These tests are pure parser tests and do NOT assert a live provider was called.
"""
import json

import pytest

from aidm.combat.narration_contract import NARRATION_MAX_CHARACTERS, parse_narration_response


@pytest.mark.parametrize("raw,expected", [
    ('{"narration":"The orc staggers backward."}', 'The orc staggers backward.'),
    (' { "narration" : "Round one ends.\\nThe party holds." } ',
     'Round one ends. The party holds.'),
    ('```json\n{"narration":"The orc falls."}\n```', 'The orc falls.'),
    ('Combat ends: PARTY_VICTORY.', 'Combat ends: PARTY_VICTORY.'),
    ('The orcs fall silent.', 'The orcs fall silent.'),
    ('  A final blow lands.   ', 'A final blow lands.'),
])
def test_valid_structured_and_explicit_legacy_prose(raw, expected):
    assert parse_narration_response(raw) == expected


@pytest.mark.parametrize("raw", [
    '', ' ', '\n', '{}', '{"narration":""}', '{"narration":"  "}',
    '{"narration":null}', '{"narration":12}', '{"narration":["x"]}',
    '{"narration":"True", "hidden_hp":100}',
    '{"text":"Not the chosen schema"}',
    '"Standalone JSON string"', 'null', 'true', 'false',
    '{"narration":"incomplete"',
    '{"narration":"valid"} extra trailing bytes',
    '{"narration": "unfinished \\"',
    '[{"narration":"object in list"}]',
    '```json\n{"narration":"unfinished"}',
    '```python\nprint(1)\n```',
    'I narrate: {"narration":"leaked"}',
    'A sentence with ```code``` markup',
    '{"narration":"safe\\u0000evil"}',
    '{"narration":"' + 'a' * 4010 + '"}',
])
def test_rejected_structures_fall_back_to_verified_journal(raw):
    assert parse_narration_response(raw) is None


def test_valid_long_structured_output_is_trimmed_after_parsing_and_at_word_boundary():
    long_prose = 'The party fights steadily. ' * 42
    output = parse_narration_response(json.dumps({'narration': long_prose}))
    assert output is not None
    assert len(output) <= NARRATION_MAX_CHARACTERS
    assert output.endswith('…')
    assert not output.endswith(' …')
    assert '{' not in output


def test_valid_long_plain_prose_has_same_output_bound():
    output = parse_narration_response('A confirmed blow lands. ' * 45)
    assert output is not None
    assert 10 < len(output) <= NARRATION_MAX_CHARACTERS
    assert output.endswith('…')


def test_model_malformed_long_json_must_not_be_truncated_to_apparent_prose():
    response = '{"narration":"' + 'Narration starts. ' * 45
    assert parse_narration_response(response) is None
