# AI Dungeon Master

![Adventuring party confronting stirges in a purple-lit cavern](assets/images/expedition_13_B1_partyFacesStirgesInThePurpleCorridor.png)

AIDM is the AI Dungeon Master project part of the **The Golden Braid**, Eric Kasper's personal journey through Agentic Engineering. The planned application combines a single player-facing conversational LLM Dungeon Master with Python orchestrators and authoritative deterministic services. It targets **1983 Mentzer Basic D&D** and explicit approved house rules, without inventing additional game mechanics.

The architectural direction includes a persistent runtime, browser interface, conversational DM, and orchestrators for adventure, expedition, character creation, geometry, rules, bookkeeping, encounters, combat, and cartography. Rules, dice, geometry and game-state changes are validated by tools and services—not made authoritative by LLM narration. Framework selection remains open.

This repository establishes the **source-control foundation**, not a completed game. Application code, unit-test infrastructure, CI, runtime, and release/version tooling belong to separate approved Developer Stories.

## Branch workflow

- `main` — stable, accepted integration baseline.
- `costa`, `davos`, `ester` — persistent developer branches, **not** feature or release branches.
- Developers normally integrate one completed Developer Story at a time. Pull requests target `main`, include the Airtable JiraID and verification evidence, and are reviewed before squash merge.
- After integration, synchronise the developer branch to the accepted `main` baseline before starting the next Story. Do not rewrite accepted `main` history or force-push it.

## Commit convention

Use `type(scope): description` (e.g. `test(repo): AIDM-DES-028.1 add pytest smoke checks`). Include the Airtable JiraID in the commit message **or** associated pull request. Preferred types: `feat`, `fix`, `test`, `docs`, `refactor`, `chore`.

## Security and content

Never commit passwords, API keys, `.env` files, private keys, or confidential or restricted content. A future committed `.env.example` may document placeholder names, but never working credentials. The B1 module, rulebook material and other potentially copyrighted content must not be redistributed without permission. See `.gitignore` for local artefact exclusions.

## Programme references

- Airtable is authoritative for Stories, ownership, scope, Test Results and Release Notes.
- OneNote: *Courses → Golden Braid → Engineering Standards*, particularly §4 (GitHub Repository and Commit Strategy).
- Architecture: *Courses → Golden Braid → AIDM - Architecture & Execution*, version 0.3 (12 November 2026), a planning rebaseline, not approved technical design.
- Sprint 1 transition: *Sprint Plan - 1.1 Transition*, baseline v1.2 (17 November 2026).

**Bootstrap story:** `AIDM-DES-026.1` (Technical Build). `VERSION`, CI, pytest, and the application skeleton intentionally belong to later Stories.
