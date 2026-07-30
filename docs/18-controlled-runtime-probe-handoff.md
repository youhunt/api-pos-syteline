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

Probe 4 confirmed that an arbitrary non-empty object does not satisfy the method contract. The method requires one or more specific business members or a specific nested order structure. The exact names remain unconfirmed.

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
```

## Technical Decision

Stop guessing payload properties. The next safe discovery path is to locate a standard form event handler, form script, global script, application event action, or other tenant metadata call site that invokes:

```text
SLCos.CreateCoAndLines
```

A standard call site may expose the exact JSON-building and Base64-encoding behavior.

## Next Step Only

Follow:

```text
implementation/18-discover-createcoandlines-call-sites.md
```

Run this read-only metadata query:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25FormEvent%25%27%20OR%20CollectionName%20LIKE%20%27%25EventHandler%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response.

## Safety Boundary

```text
- Do not invoke CreateCoAndLines again.
- Do not guess a business-schema property.
- Do not edit form handlers, scripts, events, or metadata.
- Do not submit customer, item, site, order, date, quantity, or price data.
- Do not create Process/Reprocess logic yet.
```