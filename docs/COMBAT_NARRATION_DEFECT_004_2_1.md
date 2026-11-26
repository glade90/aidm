# AIDM-DES-004.2.1 — Raw-JSON specialist narration defect

**COSTA — 26 November 2026 — Functional defect correction prepared for BON retest**

## Acceptance and cause

BON's first manual UAT case exercised a genuine live 3v3 encounter to terminal victory on SHA `3894e6e837d9d9d4c104e76ce613ac02b9abbbc4`. Rounds 1–4 displayed the provider's raw `{"narration":"..."}` object, whereas terminal output was ordinary prose. This is a player-facing formatting defect, **not proven** to be a combat-mechanics defect. DnD_Test's authoritative execution records are on PEQUOD and must be independently reviewed by BON; this developer bundle does not claim direct database access.

The old `CombatRoundAgent.narrate()` returned raw `_call()` output sliced to 500 characters. That exposed structured wrappers and could truncate a JSON response before validation. Fix at the specialist output boundary, **not** via browser stripping, ad-hoc HTML rendering or a second DM model request.

## Explicit response contract

For a `NARRATE` request, the specialist is instructed to return one JSON object with exactly this shape:

```json
{"narration":"Verified-event-based prose only."}
```

The specialist adapter validates **the complete response before truncating the extracted prose**. It accepts that one-key object and a complete legacy fenced-JSON variant. Explicit backwards compatibility permits plain prose without JSON wrappers (as observed at terminal). Extra keys, nested/non-string narration, partial JSON, malformed/fenced text, empty/oversized model responses, control characters and untrusted JSON-like prose all result in **no specialist narration**, leaving the already authoritative combat journal in the player response. This does **not** independently verify every factual claim inside well-formed provider prose; BON must compare the natural-language output with the unchanged journal.

A maximum 500-character **prose** limit is enforced after successful validation with word-boundary trimming. No new model call, source-rule change, combat-state write or provider client is introduced. The existing `CombatSessionService` boundary journal logic already ensures specialist narration only after a completed round or terminal event, never on a replay or `VIEW_LOG`.

## Regression matrix

1. Exact structured `narration` object; optional complete JSON fence; legacy terminal plain prose.
2. Malformed, truncated, extra-key, non-string, empty, invalid-fence and too-large structured output fails closed; verified journal is preserved, and untrusted wrappers are not displayed.
3. Valid long prose is bounded *after* structured validation, without partial JSON or split final words.
4. Real browser test with scripted specialist confirms one narration call on completed round, not per actor action, and none on read-only log.
5. Scripted browser fallback test for malformed JSON confirms no specialist label and intact `ROUND_COMPLETED` journal.
6. Simulated verified terminal `PARTY_VICTORY` input yields clean prose through the specialist; one call, no DM rewrite.
7. Existing full Python/JUnit, JavaScript/Node tests and >=90% app coverage must pass on clean source-matched PEQUOD checkout. Capture test-run ID, source SHA, exact covered/valid lines, exit codes and report location **before** BON independent Functional retest.
8. BON must repeat original UAT-01 through a real provider-backed encounter with at least one nonterminal completed round and terminal output; compare to journal and record observation/receipt in `DnD_Test.Test.UATTestExecution`. Parent DES-004.2 remains UAT Testing until BON and owner accept it; do not auto-close.

## Independent live-provider call evidence — recommended follow-up

The current `OpenAIResponsesPolicy._invoke()` receives the Responses API JSON but retains only `output[*].content[*].text`; `_post_json()` reads the HTTP body and discards response headers. Thus the existing narration, or a screenshot showing a nice model-written sentence, **does not by itself independently prove a provider call**.

For subsequent live UAT, instrument the existing opted-in transport (do not introduce a second provider):

- Upon a successful HTTP result, retain **`x-request-id`** from the response headers as the provider-side troubleshooting identifier; optionally send a trusted `X-Client-Request-Id` for correlation. Never log Authorization headers, credentials, prompts or hidden encounter context.
- Capture the Responses JSON `id`, `status` (must be `completed`, not an incomplete/failed generation), `model`, `created_at` (if returned), and `usage` token totals. A normalised, server-only `ProviderCallReceipt` should include UTC timestamp, monotonic latency, call purpose `INTENT`/`NARRATE`, AIDM correlation ID and tested source SHA. Distinguish transport success from actual model completion and parse success.
- Append receipt metadata to the structured application log under the run ID; BON can compare timestamps, provider response/request IDs and declared model with the project-specific OpenAI usage dashboard and request diagnostics. Attach the redacted receipt ID(s) as evidence to the applicable `DnD_Test` execution. A dashboard usage total is corroborating evidence, not necessarily a one-to-one match to each combat round.
- Preserve `store:false` unless explicitly approved otherwise. With non-stored Responses, do **not** promise to retrieve the full provider payload later by its response ID. Keep any redacted UAT transcript separately and do not use `store:true` just to make evidence convenient.
- For stronger independence, let BON inspect the provider dashboard/account or a separate attested server log rather than accepting only the browser narration or a developer-entered field. Record both the local AIDM source SHA and the provider-supplied request ID; a fabricated JSON response in tests has neither an authentic provider HTTP response nor externally corroborated usage.

The evidence instrumentation is a **proposal**, not part of this raw-JSON presentation fix, and no genuine provider call was made by COSTA in the coding sandbox.

## Remote GitHub publication

The five-file correction is committed on an isolated temporary defect branch from verified `main` SHA `b02e74f8aa613dfd6d2edb1f86969124da054096`, because permanent `costa` is occupied by draft DES-006.5 PR #27. This is a narrowly scoped exception to the permanent developer-branch workflow to avoid mixing Functional Stories. The fix requires full source-matched Python/Node regression, BON live-provider Functional UAT retest and ALEK acceptance before merging/closing. The prior offline parser tests are preliminary. Delete the temporary branch after the defect PR is merged.
