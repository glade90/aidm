# AIDM Configuration — AIDM-DES-034.1

**Purpose:** single typed Python configuration boundary; no runtime or provider coupling.  
**Engineering authority:** Golden Braid Engineering Standards §12.  
**Change log:** 2026-11-17 COSTA — initial loader and developer instructions.

## Local development (Windows PowerShell)

1. Clone the private repository and select your persistent development branch.
2. Copy `.env.example` to `.env` in the repository root (`Copy-Item .env.example .env`). The `.env` file is optional; do not commit it or share it.
3. Add **only local development values** to `.env`. It is plain text: restrict filesystem access and never sync or publish it. Never place a real API key into `.env.example`.
4. Call `from aidm.config import load_config; settings = load_config()` from the repository root. Importing the module alone does not read the environment or access the network.
5. Existing process/OS values always override `.env`. For example, `$env:AIDM_DEBUG='true'` overrides `AIDM_DEBUG=false` in `.env`.

`AIDM_MODE` is **process-only** and supports `development`, `test`, `ci`, `production`; absent `AIDM_MODE`, `CI=true` defaults to `ci`, otherwise `development`. Development may read `.env`; test, CI and production never do. Supplying both `CI=true` and `AIDM_MODE=development` fails closed. CI/deployment credentials must use environment injection from their approved protected secret facilities, **not** a committed dotenv file. No local `.env` is needed if process environment settings suffice.

## Supported shared settings

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `AIDM_MODE` | enum | `development` locally / `ci` when `CI=true` | Process-only; controls whether .env may be read |
| `AIDM_DEBUG` | boolean | `false` | `true/false`, `yes/no`, `on/off`, `1/0` (case-insensitive) |
| `AIDM_LOG_LEVEL` | enum | `INFO` | `INFO`, `DEBUG`, `TRACE`; this story does not configure a logger |
| `AIDM_REQUEST_TIMEOUT_SECONDS` | positive finite float | `30` | Future runtime/provider adapters decide when to use it |

Do not invent or hard-code a live provider API-key name before AIDM-DES-015 selects one.

## Public API / integration handoff

```python
from aidm.config import ConfigError, Settings, load_config

# Standard/offline workflow: no provider key required.
settings: Settings = load_config()
print(settings.to_safe_dict())  # safe diagnostics: no secrets

# An authorised future provider adapter requests *only* the key it needs.
# 'DEMO_SERVICE_TOKEN' is a synthetic example, not a selected LLM provider.
settings = load_config(required_secrets=("DEMO_SERVICE_TOKEN",))
secret = settings.get_secret("DEMO_SERVICE_TOKEN")
# Inject the credential exclusively into the selected authorised adapter.
```

`load_config(environ={...}, dotenv_path=...)` permits an isolated unit-test environment without reading developer settings; `required_secrets` validates only the explicitly enabled integration's keys and `optional_secrets` opts into additional credential keys. `ConfigError` reports the configuration **key only**; neither supplied values nor partial credential fragments should appear. `Settings` repr/str and `to_safe_dict()` exclude credential values. `Settings` objects are not pickleable/JSON-serializable; serialize only the redacted `to_safe_dict()` output. Do not log raw environment dicts or print `get_secret()` values.

## Tests (offline, deterministic)

From repository root, run:

```powershell
python -m unittest discover -s aidm/test -p 'test_*.py' -v
```

This temporary dependency-free test command remains available until AIDM-DES-028.1 defines the standard pytest + coverage/report command; the colocated `aidm/test/` suite is also pytest-discoverable. No network access, credentials, LLM or paid APIs are required.

Verify ignore behaviour using `git check-ignore -v .env .env.local`; verify **`.env.example` is tracked/trackable** with `git check-ignore .env.example` (expected non-zero/no match) and `git ls-files --error-unmatch .env.example` after committing. This is only an ignore convenience, not a substitute for reviewing diffs for secrets.

If a credential is leaked into Git, a PR, a log, Airtable or a trace: revoke/rotate it immediately; do not assume deleting a file removes history. CI and deployment integrations belong to their separate Stories. The Meta Service (DES-013) consumes this loader, and the provider integration (DES-015) selects and injects appropriate secrets later.