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

## Technical Decision

Payload-property guessing is stopped. Discovery now targets standard tenant metadata that may call:

```text
SLCos.CreateCoAndLines
```

## Confirmed Event Metadata Collections

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

## Confirmed EventHandlers Properties

The tenant-published properties most relevant to call-site discovery are:

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

`MethodToCall` is the first parent-handler field to search. `EventActions` is a child `CONTAINS` property whose internal contract has not yet been inspected.

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
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

Run this read-only metadata query:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventHandlers/adv?props=EventName,Sequence,Description,Purpose,IDOCollections,AppliesToObjects,AccessAs,Active,InitialAction,InitialActionSequence,MethodToCall&filter=MethodToCall%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, including an empty result.

Do not inspect `EventHandlerRevisions` or `EventActions` in the same step.

## Status

```text
Four controlled probes              : COMPLETED
Four no-order checks                : COMPLETED — ZERO ROWS
Payload property guessing           : STOPPED
Event metadata collections          : CONFIRMED
EventHandlers property metadata     : CONFIRMED
Filtered MethodToCall search        : NEXT
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
