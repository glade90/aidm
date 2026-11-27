# AIDM-DES-001.7.9.1 — Reviewed read-only SQL contract

**COSTA | Technical Build | 27 November 2026**

## Defect

BON found that SqlServerReader, on DAVOS source SHA
08928fc4edd040495e1f50c79ebac02b5da01b96, checked only for
sql.startswith("SELECT "). In a synthetic fake-cursor test this forwarded
SELECT-prefixed multi-statement DELETE and SELECT INTO. There is NO evidence
of any actual PEQUOD SQL write or schema alteration.

## Repair

SqlServerReader now accepts **only six exact, reviewed SQL statements**:
- Rules.Monster production Approved+Active query (version-pinned or not)
- Rules.Monster development-only SourceChecked+inactive query (pinned or not)
- Test.MonsterTestScenario lookup by ScenarioCode
- Test.MonsterTestCase lookup by ScenarioCode

The exact SQL is assembled only from module-controlled columns, tables and
predicates. A read-only MappingProxyType stores the reviewed contract. The
adapter validates the entire SQL against that allowlist, confirms an exact
tuple of the required bound parameter count and validates identifiers and
ISO RecordDate **before** calling connection_factory. It accepts no
arbitrary SELECT, SELECT INTO, batched statements, unreviewed joins/tables,
appended comment/hints/predicates or malformed parameter count.

This is **defence in depth** rather than a SQL parser. The SQL principal
must still be a dedicated SQL Server SELECT-only identity verified under
DES-037 / DES-037.1. Do not run a fake-cursor adversarial test against a
live writable database, and do not infer successful least-privileged
PEQUOD login from offline automated tests.

## Invariants retained

- Parameterised queries; no interpolation from player/LLM fields
- Query/connection timeout, results capped at 100 and close-in-finally
- Error redaction; no connection strings, credentials or driver errors
- No live SQL connection during import or normal CI
- No schema, seed data, Active/SourceStatus, ReadyForExecution, Combat or
  B1-encounter eligibility changes
- Same three provider families; production vs test-only gates unchanged

## Developer verification

Focused (no ODBC): \`python -m pytest aidm/test/test_catalogue.py
aidm/test/test_catalogue_smoke.py -q\`.

Full (exact branch SHA on GitHub Actions Windows):
\`python -m aidm.test_runner\` with >=90% line coverage and separate
\`node --test aidm/web/test/chat_client.test.mjs
aidm/web/test/combat_client.test.mjs\`.

Before claiming PASS, capture exact tested source SHA, run ID, JUnit outcomes,
covered/valid app lines, Node TAP result and reports artifact. BON should
re-run the original UAT-06 *fake-driver* attack, verifying zero calls to the
fake cursor and zero connection attempts for all rejected statements. A real
SELECT-only login remains a separate infrastructure gate DES-037.1.

Technical Build: developer automated regression -> ALEK technical acceptance,
with BON independent recheck of the parent DES-001.7.9 UAT-06 safety criterion.
Actual owner time and planning allocation must not be fabricated.
