"""Deterministic tests for release-source provenance and build-identity safety.

Purpose: Validate VERSION, exact SHA, clean/dirty Git, packaged manifest and CLI.
Usage: python -m pytest aidm/test/test_versioning.py -q
Change Log: 2026-11-18 COSTA — AIDM-DES-030.1 identity acceptance tests.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
from unittest.mock import patch

import pytest

from aidm.__main__ import main as cli_main
from aidm.versioning import (
    UNKNOWN, BuildIdentity, VersionError, diagnostics, generate_development_manifest,
    get_build_identity, parse_version, read_version, startup_banner,
)


def _git(tmp_path: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(tmp_path), *args], check=True, text=True,
        capture_output=True,
    )
    return result.stdout.strip()


@pytest.fixture
def checkout(tmp_path: Path) -> tuple[Path, str]:
    root = tmp_path / "sample-project"
    root.mkdir()
    (root / "aidm").mkdir()
    (root / "VERSION").write_text("0.1.0\n", encoding="utf-8")
    (root / ".gitignore").write_text("aidm/_build_manifest.json\n", encoding="utf-8")
    _git(root, "init", "-q")
    _git(root, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "add", "-A")
    _git(root, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "commit", "-qm", "Initial test source")
    return root, _git(root, "rev-parse", "HEAD")


@pytest.mark.parametrize("version", ["0.1.0", "1.2.34", "10.0.100"])
def test_exact_semver(version: str) -> None:
    assert parse_version(version) == version


@pytest.mark.parametrize("bad", ["", "v0.1.0", "01.2.3", "1.02.3", "1.2.3-alpha", "1.2", "1.2.3\n", "sensitive-content"])
def test_invalid_version_does_not_echo_value(bad: str) -> None:
    with pytest.raises(VersionError) as failure:
        parse_version(bad)
    assert bad not in str(failure.value) if bad else True


def test_missing_or_malformed_version_fails_strictly(tmp_path: Path) -> None:
    with pytest.raises(VersionError, match="VERSION"):
        read_version(tmp_path)
    (tmp_path / "VERSION").write_text("not-a-version")
    with pytest.raises(VersionError, match="VERSION"):
        read_version(tmp_path)


def test_git_checkout_has_full_sha_and_never_claims_release(checkout: tuple[Path, str]) -> None:
    root, sha = checkout
    ident = get_build_identity(root)
    assert ident.version == "0.1.0"  # fixture only; not an approved project release
    assert ident.source_sha == sha and len(sha) == 40
    assert ident.build_type == "development"
    assert ident.dirty is False
    assert ident.build_timestamp == UNKNOWN
    assert ident.for_logging()["source_sha"] == sha
    assert ident.for_logging()["release_kind"] == "development"


def test_dirty_checkout_is_development(checkout: tuple[Path, str]) -> None:
    root, sha = checkout
    (root / "local-change.txt").write_text("work in progress")
    ident = get_build_identity(root)
    assert ident.source_sha == sha and ident.dirty is True
    assert ident.build_type == "development"
    assert "dirty=true" in startup_banner(ident)


def test_generator_requires_version_clean_source(tmp_path: Path, checkout: tuple[Path, str]) -> None:
    with pytest.raises(VersionError):
        generate_development_manifest(tmp_path)
    root, sha = checkout
    (root / "temporary-dirty.txt").write_text("dirty")
    with pytest.raises(VersionError, match="clean"):
        generate_development_manifest(root)
    (root / "temporary-dirty.txt").unlink()
    path = generate_development_manifest(root, build_id="controlled-dev-1")
    data = json.loads(path.read_text())
    assert data["version"] == "0.1.0" and data["source_sha"] == sha
    assert data["build_type"] == "development" and data["dirty"] is False
    assert get_build_identity(root).source_sha == sha  # Git checkout takes precedence
    with pytest.raises(FileExistsError):
        generate_development_manifest(root, build_id="again")


def test_packaged_manifest_with_no_git_can_prove_release(tmp_path: Path) -> None:
    root = tmp_path
    (root / "aidm").mkdir()
    sha = "1" * 40
    example = {
        "schema": 1, "version": "2.3.4", "source_sha": sha,
        "build_type": "release", "build_id": "signed-by-controlled-release-pipeline",
        "build_timestamp": "2026-11-18T12:00:00+00:00", "dirty": False,
    }
    (root / "aidm" / "_build_manifest.json").write_text(json.dumps(example))
    with patch("aidm.versioning._git_identity", return_value=(UNKNOWN, None)):
        ident = get_build_identity(root)
    assert ident.source_sha == sha and ident.build_type == "release"
    assert ident.version == "2.3.4" and ident.build_id == example["build_id"]
    assert diagnostics(root)["build_type"] == "release"
    assert "1" * 40 in startup_banner(ident)


def test_malformed_manifest_fails_closed(tmp_path: Path) -> None:
    (tmp_path / "aidm").mkdir()
    path = tmp_path / "aidm" / "_build_manifest.json"
    path.write_text(json.dumps({"schema": 1, "version": "2.0.0", "source_sha": "bad", "build_type": "release"}))
    ident = get_build_identity(tmp_path)
    assert ident.build_type == "development" and ident.source_sha == UNKNOWN
    assert ident.dirty is None


def test_unknown_checkout_does_not_invent_sha(tmp_path: Path) -> None:
    (tmp_path / "VERSION").write_text("0.2.0\n")
    ident = get_build_identity(tmp_path)
    assert ident.version == "0.2.0" and ident.source_sha == UNKNOWN
    assert ident.build_type == "development"


def test_cli_and_startup_emit_same_identity(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    identity = BuildIdentity("1.2.3", "f" * 40, "development", "dev-fixture", UNKNOWN, False)
    monkeypatch.setattr("aidm.__main__.startup_banner", lambda: startup_banner(identity))
    assert cli_main(["--version"]) == 0
    out = capsys.readouterr().out
    assert identity.source_sha in out and "AIDM 1.2.3" in out
    assert "Meta Service" not in out
    assert cli_main([]) == 0
    startup = capsys.readouterr().out
    assert startup.startswith(startup_banner(identity))
    assert "Meta Service has not been implemented" in startup


def test_packaged_mismatched_version_is_not_release(tmp_path: Path) -> None:
    (tmp_path / "aidm").mkdir()
    (tmp_path / "VERSION").write_text("2.1.0\n")
    path = tmp_path / "aidm" / "_build_manifest.json"
    path.write_text(json.dumps({
        "schema": 1, "version": "2.0.0", "source_sha": "a" * 40,
        "build_type": "release", "build_id": "untrusted", "build_timestamp": "2026-11-18T00:00:00Z", "dirty": False,
    }))
    identity = get_build_identity(tmp_path)
    assert identity.version == "2.1.0"
    assert identity.source_sha == UNKNOWN and identity.build_type == "development"


def test_unavailable_git_does_not_make_checkout_manifest_a_release(tmp_path: Path) -> None:
    (tmp_path / ".git").mkdir()
    (tmp_path / "aidm").mkdir()
    (tmp_path / "VERSION").write_text("2.1.0\n")
    path = tmp_path / "aidm" / "_build_manifest.json"
    path.write_text(json.dumps({
        "schema": 1, "version": "2.1.0", "source_sha": "a" * 40,
        "build_type": "release", "build_id": "untrusted", "build_timestamp": "2026-11-18T00:00:00Z", "dirty": False,
    }))
    with patch("aidm.versioning._git_identity", return_value=(UNKNOWN, None)):
        identity = get_build_identity(tmp_path)
    assert identity.source_sha == UNKNOWN
    assert identity.build_type == "development"