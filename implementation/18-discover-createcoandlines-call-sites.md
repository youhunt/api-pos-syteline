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
EventActions.SubstitutedParameters search  : NEXT
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

`EventActions` is the primary current child-action metadata source.

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

The absence of matches in these three fields does not rule out a standard call site. Remaining paths include `SubstitutedParameters`, action revisions, handler revisions, form metadata, scripts, or another metadata object.

## Current Small Step — Filter EventActions.SubstitutedParameters

Run this read-only REST v1 request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=SubstitutedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, including an empty result.

## Interpretation Rules

```text
- A returned row proves only that SubstitutedParameters contains CreateCoAndLines.
- Do not infer ActionType meaning from its number alone.
- Do not execute the action.
- Do not inspect revision metadata in the same step.
- If zero rows return, revision metadata becomes a later separate path.
```

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines again.
- Do not guess a Customer Order JSON property.
- Do not edit event actions, handlers, scripts, events, or metadata.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```
