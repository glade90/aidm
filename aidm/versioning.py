"""AIDM's single-source version and reproducible runtime build identity.

Purpose: Resolve VERSION plus full Git source identity in development, or a
         generated manifest when Git is unavailable in packaged deployments.
Usage: from aidm.versioning import get_build_identity, startup_banner
Change Log: 2026-11-18 COSTA — AIDM-DES-030.1 implementation.

The approved Sprint target is required before the root VERSION file is seeded.
This module never claims a release from a VERSION file or a Git tag alone.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
from typing import Any, Literal, Mapping
from uuid import uuid4

UNKNOWN = "UNKNOWN"
MANIFEST_NAME = "_build_manifest.json"
_VERSION_RE = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z")
_SHA_RE = re.compile(r"(?:[a-fA-F0-9]{40}|[a-fA-F0-9]{64})\Z")
BuildType = Literal["development", "release"]


class VersionError(ValueError):
    """Version metadata is missing or invalid; errors contain no file values."""


@dataclass(frozen=True, slots=True)
class BuildIdentity:
    """Immutable source/build identity suitable for diagnostics and logs."""

    version: str
    source_sha: str
    build_type: str
    build_id: str
    build_timestamp: str
    dirty: bool | None

    def as_dict(self) -> dict[str, str | bool | None]:
        """No credentials; full SHA is intentionally preserved."""
        return asdict(self)

    def for_logging(self) -> dict[str, str]:
        """All fields used by the technical logger's structured records."""
        return {
            "version": self.version,
            "source_sha": self.source_sha,
            "build_id": self.build_id,
            "release_kind": self.build_type,
            "build_timestamp": self.build_timestamp,
            "dirty": UNKNOWN if self.dirty is None else str(self.dirty).lower(),
        }


def parse_version(value: str) -> str:
    """Validate the exact MAJOR.MINOR.PATCH format, no leading v/zeros."""
    if not isinstance(value, str) or _VERSION_RE.fullmatch(value) is None:
        raise VersionError("Invalid VERSION: expected MAJOR.MINOR.PATCH")
    return value


def read_version(root: Path) -> str:
    """Read the authoritative repository VERSION or fail without guessing."""
    try:
        value = (Path(root) / "VERSION").read_text(encoding="utf-8-sig").strip()
    except (OSError, UnicodeError):
        raise VersionError("VERSION is missing or unreadable") from None
    return parse_version(value)


def _git(root: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *args],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, check=True, timeout=5,
        )
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError, UnicodeError):
        return None


def _git_identity(root: Path) -> tuple[str, bool | None]:
    """Only trust a Git checkout whose top level is the requested project root."""
    top = _git(root, "rev-parse", "--show-toplevel")
    if top is None or Path(top).resolve() != root.resolve():
        return UNKNOWN, None
    sha = _git(root, "rev-parse", "--verify", "HEAD")
    if not sha or not _SHA_RE.fullmatch(sha):
        return UNKNOWN, None
    state = _git(root, "status", "--porcelain", "--untracked-files=normal")
    return sha.lower(), bool(state) if state is not None else None


def _manifest_data(manifest_path: Path) -> BuildIdentity | None:
    if not manifest_path.is_file():
        return None
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or data.get("schema") != 1:
            return None
        version = parse_version(data["version"])
        sha = data["source_sha"]
        kind = data["build_type"]
        build_id, timestamp = data["build_id"], data["build_timestamp"]
        if not isinstance(sha, str) or not _SHA_RE.fullmatch(sha):
            return None
        if kind not in ("development", "release"):
            return None
        if not isinstance(build_id, str) or not build_id.strip() or not isinstance(timestamp, str):
            return None
        if datetime.fromisoformat(timestamp.replace("Z", "+00:00")).tzinfo is None:
            return None
        if data.get("dirty") is not False:
            return None  # builds must originate from clean accepted source
        return BuildIdentity(version, sha.lower(), kind, build_id, timestamp, False)
    except (OSError, UnicodeError, ValueError, KeyError, TypeError):
        return None


def get_build_identity(
    root: Path | None = None, *, manifest_path: Path | None = None,
) -> BuildIdentity:
    """Prefer live Git checkout, then signed-off packaged metadata; never guess.

    A VERSION file alone never makes a release. A generated manifest is used
    only when the project root is a package without Git checkout metadata;
    an invalid/mismatched manifest does not grant a release identity.
    """
    root = (Path(root) if root is not None else Path(__file__).resolve().parents[1]).resolve()
    sha, dirty = _git_identity(root)
    if sha != UNKNOWN:
        try:
            version = read_version(root)
        except VersionError:
            version = UNKNOWN
        return BuildIdentity(version, sha, "development", f"dev-{sha[:12]}", UNKNOWN, dirty)

    path = Path(manifest_path) if manifest_path is not None else root / "aidm" / MANIFEST_NAME
    manifest = _manifest_data(path)
    # A checkout with no working Git binary cannot be mistaken for a release.
    if (root / ".git").exists():
        manifest = None
    if manifest is not None and (root / "VERSION").exists():
        try:
            if read_version(root) != manifest.version:
                manifest = None
        except VersionError:
            manifest = None
    if manifest is not None:
        return manifest
    try:
        version = read_version(root)
    except VersionError:
        version = UNKNOWN
    return BuildIdentity(version, UNKNOWN, "development", UNKNOWN, UNKNOWN, None)


def diagnostics(root: Path | None = None, *, manifest_path: Path | None = None) -> dict[str, Any]:
    """Public future Meta Service status/About contract; not a web endpoint."""
    return get_build_identity(root, manifest_path=manifest_path).as_dict()


def startup_banner(identity: BuildIdentity | None = None) -> str:
    """Console startup hook for the future Meta Service (DES-013)."""
    item = identity if identity is not None else get_build_identity()
    dirty = UNKNOWN if item.dirty is None else str(item.dirty).lower()
    return (f"AIDM {item.version} | {item.build_type} | source={item.source_sha} | "
            f"build={item.build_id} | timestamp={item.build_timestamp} | dirty={dirty}")


def generate_development_manifest(
    root: Path | None = None, *, output: Path | None = None,
    build_id: str | None = None,
) -> Path:
    """Package-time generation against the final clean source commit.

    Only development manifests are supported here; the controlled release
    workflow under DES-030.2 owns release designation, tag and attestation.
    Generated manifest is Git-ignored, never a committed self-referential SHA.
    """
    root = (Path(root) if root is not None else Path(__file__).resolve().parents[1]).resolve()
    version = read_version(root)  # Requires explicit approved Sprint target.
    sha, dirty = _git_identity(root)
    if sha == UNKNOWN or dirty is not False:
        raise VersionError("Manifest requires an available, clean Git revision")
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    identity = BuildIdentity(
        version, sha, "development", build_id or f"build-{uuid4().hex}", stamp, False,
    )
    target = Path(output) if output is not None else root / "aidm" / MANIFEST_NAME
    target.parent.mkdir(parents=True, exist_ok=True)
    # Refuse overwrite: stale manifests must be removed deliberately.
    with target.open("x", encoding="utf-8") as f:
        json.dump({"schema": 1, **identity.as_dict()}, f, indent=2)
        f.write("\n")
    return target


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser(description="AIDM build-identity inspection")
    parser.add_argument("--generate-development-manifest", action="store_true")
    args = parser.parse_args(argv)
    if args.generate_development_manifest:
        try:
            print(generate_development_manifest())
        except (VersionError, OSError) as exc:
            print(type(exc).__name__ + ": " + str(exc))
            return 2
    else:
        print(startup_banner())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())