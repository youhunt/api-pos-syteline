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

## Confirmed Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ locate expected non-blank order structure
→ business schema validation
→ Customer Order and line processing
```

## Completed Probes

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

Probe 4 confirmed that an arbitrary non-empty object does not satisfy the method contract. The exact required business member names and nesting remain unconfirmed.

## Business Result Rules

```text
- MessageCode = 0 is not business success.
- Parse CoResult as a JSON-array string.
- Evaluate Status.
- Failure records may or may not include ErrrorMessage.
- Some failure branches preserve input properties and add Status and Message.
```

## Completed No-Order Verifications

```text
Probe 1 check : zero rows
Probe 2 check : zero rows
Probe 3 check : zero rows
Probe 4 check : zero rows
SQL errors    : none
```

No unexpected Customer Order was found in any checked 30-minute window.

## Evidence

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
tests/evidence/2026-07-30-createcoandlines-empty-object-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-nonbusiness-marker-blank-order-failure.md
tests/evidence/2026-07-30-createcoandlines-marker-probe-no-order-created.md
```

## Technical Decision

Payload-property guessing is stopped. Discovery now targets standard tenant metadata that may call:

```text
SLCos.CreateCoAndLines
```

## Confirmed Event Metadata Collections

Read-only `IdoCollections` discovery returned:

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

All are published from:

```text
ServerName : MGCore
AccessAs   : Core
```

Strongest initial candidates:

```text
EventHandlers
EventHandlerRevisions
```

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
```

## Current Unknowns

```text
- exact top-level order member name or names
- exact header/line nesting
- required header fields
- required line fields
- accepted date and numeric formats
- whether co_num is supplied or generated
- success CoResult shape
- atomicity of header and line creation
- which standard metadata object calls CreateCoAndLines
```

## Next Step Only

Read the published property metadata for `EventHandlers`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventHandlers
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, especially `Properties`.

Do not inspect `EventHandlerRevisions` in the same step.

## Safety Boundary

```text
- Do not invoke CreateCoAndLines again.
- Do not guess a business-schema property.
- Do not edit form handlers, scripts, events, or metadata.
- Do not submit customer, item, site, order, date, quantity, or price data.
- Do not create Process/Reprocess logic yet.
```