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

An arbitrary non-empty object does not satisfy the method contract. The exact required business member names and nesting remain unconfirmed.

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

## Technical Decision

Payload-property guessing is stopped. Discovery targets standard tenant metadata that may call:

```text
SLCos.CreateCoAndLines
```

## Confirmed Event Metadata

Candidate IDOs:

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

`EventHandlers` publishes:

```text
EventName
Sequence
MethodToCall
IDOCollections
AppliesToObjects
EventActions                 : CONTAINS
InitialAction
InitialActionSequence
Description
Purpose
AccessAs
Active
Synchronous
Transactional
TriggeringProperty
```

## Completed Parent-Handler Search

A read-only filter was applied:

```text
MethodToCall LIKE '%CreateCoAndLines%'
```

Tenant result:

```text
Message        : Success
MessageCode    : 0
Items          : zero rows
MoreRowsExists : false
```

Confirmed conclusion:

```text
No parent EventHandlers row stores CreateCoAndLines directly in MethodToCall.
```

This does not rule out a standard call site. The reference may exist in child event-action metadata, revisions, form metadata, or scripts.

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
```

## Next Step Only

Discover the actual tenant collection name or names related to event actions:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25EventAction%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, including an empty result.

Do not inspect `EventHandlerRevisions` in the same step. Do not assume that the parent `CONTAINS` property name `EventActions` is itself the loadable child IDO name.

## Status

```text
Four controlled probes              : COMPLETED
Four no-order checks                : COMPLETED — ZERO ROWS
Payload property guessing           : STOPPED
Event metadata collections          : CONFIRMED
EventHandlers property metadata     : CONFIRMED
Parent MethodToCall search          : COMPLETED — ZERO ROWS
Event-action collection discovery   : NEXT
Exact decoded JSON schema           : PENDING
Process/Reprocess                    : NOT STARTED
Customer Order creation             : NOT STARTED
Controlled receive API              : NOT STARTED
```

## Safety Boundary

```text
- Do not invoke CreateCoAndLines again.
- Do not guess a business-schema property.
- Do not edit form handlers, event actions, scripts, events, or metadata.
- Do not submit customer, item, site, order, date, quantity, or price data.
- Do not create Process/Reprocess logic yet.
```
