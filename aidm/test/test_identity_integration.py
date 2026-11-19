"""Identity integration acceptance tests for technical logger and test reports.

Purpose: Ensure full source/build identity accompanies every structured record.
Usage: python -m aidm.test_runner
Change Log: 2026-11-18 COSTA — AIDM-DES-030.1 cross-service identity tests.
"""

from __future__ import annotations

import json
from pathlib import Path
from xml.etree import ElementTree

from aidm.logging import close_logging, configure_logging, log, set_identity_provider
from aidm.test_runner import _stamp_junit
from aidm.versioning import BuildIdentity, UNKNOWN


def test_structured_logging_every_record_has_full_identity(tmp_path: Path) -> None:
    ident = BuildIdentity(
        "2.4.6", "c" * 40, "development", "build-fake-for-test",
        "2026-11-18T14:00:00+00:00", True,
    )
    path, jsonl = tmp_path / "technical.log", tmp_path / "technical.jsonl"
    try:
        configure_logging(path=path, json_path=jsonl)
        set_identity_provider(ident.for_logging)
        with log.correlation("turn-42"):
            log.info("verification")
            log.warning("second verification")
        lines = [json.loads(line) for line in jsonl.read_text(encoding="utf-8").splitlines()]
        assert len(lines) == 2
        for item in lines:
            assert item["version"] == "2.4.6"
            assert item["source_sha"] == "c" * 40
            assert item["build_type"] == "development"
            assert item["build_id"] == "build-fake-for-test"
            assert item["build_timestamp"] == ident.build_timestamp
            assert item["dirty"] == "true"
            assert item["correlation_id"] == "turn-42"
            assert item["severity"] in (20, 30)
        assert "ℹ️" in path.read_text(encoding="utf-8")
    finally:
        close_logging()
        set_identity_provider(None)


def test_junit_both_success_and_failure_contains_identity(tmp_path: Path) -> None:
    identity = BuildIdentity("3.1.4", "b" * 40, "development", "snapshot",
                             UNKNOWN, True)
    for failed in (False, True):
        path = tmp_path / ("failed.xml" if failed else "success.xml")
        root = ElementTree.Element("testsuites")
        suite = ElementTree.SubElement(root, "testsuite", name="aidm", tests="1",
                                      failures="1" if failed else "0")
        case = ElementTree.SubElement(suite, "testcase", name="check")
        if failed:
            ElementTree.SubElement(case, "failure", message="expected failure")
        ElementTree.ElementTree(root).write(path, encoding="utf-8")
        _stamp_junit(path, identity)
        parsed = ElementTree.parse(path).getroot().find("testsuite")
        props = {item.get("name"): item.get("value")
                 for item in parsed.findall("properties/property")}
        assert props["aidm.version"] == "3.1.4"
        assert props["aidm.source_sha"] == "b" * 40
        assert props["aidm.build_type"] == "development"
        assert props["aidm.build_id"] == "snapshot"
        assert props["aidm.dirty"] == "True"
        assert parsed.get("failures") == ("1" if failed else "0")