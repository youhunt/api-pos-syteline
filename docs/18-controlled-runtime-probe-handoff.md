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

Confirmed event-handler collections:

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

The parent search:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
```

returned zero rows.

Confirmed event-action collections:

```text
EventAction_GenericParms
EventActionRevisions
EventActions
EventActionStates
EventActionVariableAccess
```

`EventActions` is the primary child-action candidate.

## Confirmed EventActions Properties

```text
ActionType
DerActionTypeText
Parameters
ExpandedParameters
SubstitutedParameters
EventName
EventHandlerSequence
Sequence
Description
EventHandlerRowPointer
RowPointer
AccessAs
DerAccessAs
EventActionVariableAccess
IsEventActionRevision
EventHandlerRevisionRowPointer
```

## Completed Raw Parameters Search

The read-only search:

```text
EventActions.Parameters LIKE '%CreateCoAndLines%'
```

returned:

```text
Message        : Success
MessageCode    : 0
Items          : zero rows
MoreRowsExists : false
```

Therefore no current `EventActions` row stores the target in raw `Parameters`. This does not rule out a reference in derived fields, revisions, form metadata, or scripts.

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
tests/evidence/2026-07-30-event-action-metadata-collections.md
tests/evidence/2026-07-30-eventactions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactions-parameters-createcoandlines-no-match.md
```

## Next Step Only

Run:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=ExpandedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, including an empty result.

Do not search `SubstitutedParameters`, revisions, scripts, or another metadata collection in the same step. Do not invoke `CreateCoAndLines` or edit metadata.

## Status

```text
Four controlled probes                  : COMPLETED
Four no-order checks                    : COMPLETED — ZERO ROWS
Payload property guessing               : STOPPED
Event metadata collections              : CONFIRMED
EventHandlers property metadata         : CONFIRMED
Parent MethodToCall search              : COMPLETED — ZERO ROWS
Event-action collections                : CONFIRMED
EventActions property metadata          : CONFIRMED
Raw Parameters search                   : COMPLETED — ZERO ROWS
ExpandedParameters search               : NEXT
Exact decoded JSON schema               : PENDING
Process/Reprocess                       : NOT STARTED
Customer Order creation                 : NOT STARTED
Controlled receive API                  : NOT STARTED
```