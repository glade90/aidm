"""AIDM command-line version/status entry point (without starting the game).

Purpose: Make build identity visible before the Meta Service exists.
Usage: python -m aidm --version | python -m aidm
Change Log: 2026-11-18 COSTA — AIDM-DES-030.1 CLI identity hook.
"""

from __future__ import annotations

import argparse
from .versioning import startup_banner


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="AIDM runtime identity (Meta Service pending)")
    parser.add_argument("--version", action="store_true", help="Print exact build/source identity")
    args = parser.parse_args(argv)
    print(startup_banner())
    if not args.version:
        print("AIDM Meta Service has not been implemented; no game started.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())