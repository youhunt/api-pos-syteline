# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                              : DEV
Controlled malformed probes              : COMPLETED
All four no-order checks                  : COMPLETED — ZERO ROWS
Base64 input requirement                  : CONFIRMED
Decoded payload type                     : JSON object / JObject
Specific order structure required         : CONFIRMED
Exact business JSON schema                : NOT YET CONFIRMED
Further property-name guessing            : STOPPED
Standard call-site discovery              : STARTED — READ-ONLY
EventHandlers.MethodToCall search          : COMPLETED — ZERO ROWS
EventActions.Parameters search             : COMPLETED — ZERO ROWS
EventActions.ExpandedParameters search     : COMPLETED — ZERO ROWS
EventActions.SubstitutedParameters search  : COMPLETED — ZERO ROWS
EventActionRevisions property discovery    : NEXT
```

## Confirmed Runtime Boundary

Controlled probes established:

```text
1. CoAndLineInfoJson must be Base64.
2. Decoded content must parse as a JSON object / JObject.
3. An empty object is rejected as blank order input.
4. An arbitrary non-business property is also rejected as blank order input.
5. No Customer Order was created by any of the four probes in the checked windows.
```

Therefore, business-property guessing is stopped. Discovery targets tenant metadata that may call:

```text
SLCos.CreateCoAndLines
```

## Confirmed Metadata Sources

Event-handler collections:

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

Event-action collections:

```text
EventAction_GenericParms
EventActionRevisions
EventActions
EventActionStates
EventActionVariableAccess
```

`EventActions` is the primary current child-action metadata source. `EventActionRevisions` is the next revision metadata source to inspect.

## Confirmed EventActions Properties

```text
ActionType                     : Byte, required
DerActionTypeText              : String(50), read-only
Parameters                     : String(MAX)
ExpandedParameters             : String(4000), read-only
SubstitutedParameters          : String(4000), read-only
EventName                      : String(50), read-only
EventHandlerSequence           : Short Integer, read-only
Sequence                       : Short Integer, required
Description                    : String(40)
EventHandlerRowPointer         : GUID, required
RowPointer                     : GUID, read-only
AccessAs                       : String(50), read-only
DerAccessAs                    : String(50)
EventActionVariableAccess      : CONTAINS
IsEventActionRevision          : Byte
EventHandlerRevisionRowPointer : GUID, read-only
```

Evidence:

```text
tests/evidence/2026-07-30-eventactions-idoinfo-properties.md
```

## Completed Call-Site Searches

### Parent EventHandlers.MethodToCall

```text
Filter          : MethodToCall LIKE '%CreateCoAndLines%'
Rows returned   : 0
Conclusion      : no direct parent MethodToCall reference found
```

Evidence:

```text
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
```

### Raw EventActions.Parameters

```text
Filter          : Parameters LIKE '%CreateCoAndLines%'
Rows returned   : 0
Conclusion      : no current raw Parameters reference found
```

Evidence:

```text
tests/evidence/2026-07-30-eventactions-parameters-createcoandlines-no-match.md
```

### Derived EventActions.ExpandedParameters

```text
Filter          : ExpandedParameters LIKE '%CreateCoAndLines%'
Rows returned   : 0
Message         : Success
MessageCode     : 0
MoreRowsExists  : false
Conclusion      : no current ExpandedParameters reference found
```

Evidence:

```text
tests/evidence/2026-07-30-eventactions-expandedparameters-createcoandlines-no-match.md
```

### Derived EventActions.SubstitutedParameters

```text
Filter          : SubstitutedParameters LIKE '%CreateCoAndLines%'
Rows returned   : 0
Message         : Success
MessageCode     : 0
MoreRowsExists  : false
Conclusion      : no current SubstitutedParameters reference found
```

Evidence:

```text
tests/evidence/2026-07-30-eventactions-substitutedparameters-createcoandlines-no-match.md
```

## Current EventActions Conclusion

The current action fields checked are exhausted:

```text
Parameters             : zero rows
ExpandedParameters     : zero rows
SubstitutedParameters  : zero rows
```

This does not prove that no standard call site exists. Remaining paths include event-action revisions, event-handler revisions, form metadata, scripts, or another metadata object.

## Current Small Step — Read EventActionRevisions Property Metadata

Before filtering revision rows, inspect the tenant-published property contract:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventActionRevisions
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, especially the `Properties` list.

## Interpretation Rules

```text
- Read metadata only.
- Do not assume EventActionRevisions uses the same property names as EventActions.
- Do not load or filter revision rows until the actual property contract is confirmed.
- Do not inspect EventHandlerRevisions in the same step.
```

## Safety Boundary

```text
- Do not invoke CreateCoAndLines again.
- Do not guess a Customer Order JSON property.
- Do not edit event actions, handlers, scripts, events, or metadata.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```
