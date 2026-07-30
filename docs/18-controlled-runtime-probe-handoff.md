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

Completed controlled probes:

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

An arbitrary non-empty object does not satisfy the method contract. Exact business member names and nesting remain unconfirmed.

## Business Result Rules

```text
- MessageCode = 0 is not business success.
- Parse CoResult as a JSON-array string.
- Evaluate Status.
- Failure records may or may not include ErrrorMessage.
- Some failure branches preserve input properties and add Status and Message.
```

## Completed Safety Verifications

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

## Confirmed Event-Handler Metadata

Candidate IDOs:

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

`EventHandlers` publishes call-site-relevant properties including:

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

A read-only search for:

```text
MethodToCall LIKE '%CreateCoAndLines%'
```

returned zero rows. Therefore no parent `EventHandlers` row stores the target directly in `MethodToCall`.

## Confirmed Event-Action Metadata Collections

Read-only `IdoCollections` discovery returned:

```text
EventAction_GenericParms
EventActionRevisions
EventActions
EventActionStates
EventActionVariableAccess
```

Tenant descriptions identify `EventActions` as the primary action collection. The others are supporting collections for generic parameters, revisions, state/status, or variable access. Their actual property contracts have not yet been inspected.

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
tests/evidence/2026-07-30-event-action-metadata-collections.md
```

## Next Step Only

Read published property metadata for `EventActions`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventActions
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, especially `Properties`.

Do not load action rows, inspect `EventActionRevisions`, invoke `CreateCoAndLines`, guess business-schema properties, or edit metadata in the same step.

## Status

```text
Four controlled probes              : COMPLETED
Four no-order checks                : COMPLETED — ZERO ROWS
Payload property guessing           : STOPPED
Event metadata collections          : CONFIRMED
EventHandlers property metadata     : CONFIRMED
Parent MethodToCall search          : COMPLETED — ZERO ROWS
Event-action collections            : CONFIRMED
EventActions property metadata      : NEXT
Exact decoded JSON schema           : PENDING
Process/Reprocess                    : NOT STARTED
Customer Order creation             : NOT STARTED
Controlled receive API              : NOT STARTED
```