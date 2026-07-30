# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Environment and Method

```text
Environment                        : DEV
Disposable Customer Order testing : ALLOWED
IDO                                : SL.SLCos
Method                             : CreateCoAndLines
Implementation                     : Customer.SLCos
Assembly                           : Customer — Binary Only
Transactional                      : false
```

```text
CoAndLineInfoJson : input-only
CoResult          : input/output + message
```

## Confirmed Runtime Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ locate expected non-blank order structure
→ business schema validation
→ Customer Order and line processing
```

Completed probes:

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

All four post-probe `dbo.co_mst` checks returned zero rows with no SQL error. Payload-property guessing is stopped.

## Business Result Rules

```text
- MessageCode = 0 is not business success.
- Parse CoResult as a JSON-array string.
- Evaluate Status.
- Failure records may or may not include ErrrorMessage.
- Some failure branches preserve input properties and add Status and Message.
```

## Standard Call-Site Discovery

Confirmed current searches:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'              : zero rows
EventActions.Parameters LIKE '%CreateCoAndLines%'                  : zero rows
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'          : zero rows
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'       : zero rows
```

The current `EventActions` path is exhausted. These zero-row results do not prove that no standard call site exists. Remaining paths include:

```text
EventActionRevisions
EventHandlerRevisions
form metadata
form or global scripts
another metadata object
```

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
tests/evidence/2026-07-30-event-action-metadata-collections.md
tests/evidence/2026-07-30-eventactions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactions-expandedparameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactions-substitutedparameters-createcoandlines-no-match.md
```

## Next Step Only

Read the published property metadata for `EventActionRevisions`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventActionRevisions
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, especially the `Properties` list.

Do not load revision rows, inspect `EventHandlerRevisions`, invoke `CreateCoAndLines`, guess business-schema properties, or edit metadata in the same step.

## Status

```text
Four controlled probes                    : COMPLETED
Four no-order checks                      : COMPLETED — ZERO ROWS
Payload property guessing                 : STOPPED
Event metadata collections                : CONFIRMED
EventHandlers property metadata           : CONFIRMED
Parent MethodToCall search                : COMPLETED — ZERO ROWS
Event-action collections                  : CONFIRMED
EventActions property metadata            : CONFIRMED
Raw Parameters search                     : COMPLETED — ZERO ROWS
ExpandedParameters search                 : COMPLETED — ZERO ROWS
SubstitutedParameters search              : COMPLETED — ZERO ROWS
EventActionRevisions property discovery   : NEXT
Exact decoded JSON schema                 : PENDING
Process/Reprocess                         : NOT STARTED
Customer Order creation                   : NOT STARTED
Controlled receive API                    : NOT STARTED
```
