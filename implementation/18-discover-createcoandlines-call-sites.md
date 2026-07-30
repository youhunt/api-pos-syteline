# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                           : DEV
Controlled malformed probes           : COMPLETED
All four no-order checks               : COMPLETED — ZERO ROWS
Base64 input requirement               : CONFIRMED
Decoded payload type                  : JSON object / JObject
Specific order structure required      : CONFIRMED
Exact business JSON schema             : NOT YET CONFIRMED
Further property-name guessing         : STOPPED
Standard call-site discovery           : STARTED — READ-ONLY
EventHandlers.MethodToCall search       : COMPLETED — ZERO ROWS
EventActions.Parameters search          : COMPLETED — ZERO ROWS
EventActions.ExpandedParameters search  : NEXT
```

## Why the Discovery Path Changed

The controlled runtime probes confirmed:

```text
1. raw input is rejected unless it is valid Base64;
2. decoded content is parsed as a JSON object / JObject;
3. an empty object is treated as blank order input;
4. an arbitrary non-business property is also treated as blank order input;
5. no Customer Order was created by any of the four probes in the checked windows.
```

The method therefore expects one or more specific business members or a specific nested order structure. Guessing names such as `Order`, `Header`, `Lines`, or `Co` is stopped.

The safe path is to locate standard tenant metadata that invokes:

```text
SLCos.CreateCoAndLines
```

A standard call site may reveal the exact JSON construction and Base64 encoding behavior.

## Confirmed Event Metadata Collections

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
```

## EventHandlers Discovery

Relevant `EventHandlers` properties include:

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

Evidence:

```text
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
```

## Confirmed Event-Action Collections

```text
EventAction_GenericParms
EventActionRevisions
EventActions
EventActionStates
EventActionVariableAccess
```

`EventActions` is the primary child-action metadata candidate. The remaining collections are later paths for generic parameters, revisions, state/status, or variable access.

Evidence:

```text
tests/evidence/2026-07-30-event-action-metadata-collections.md
```

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

## Completed Step — Filter Raw EventActions.Parameters

Read-only request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=Parameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
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
No current EventActions row stores CreateCoAndLines in raw Parameters.
```

This does not rule out a standard call site. The reference may be in derived parameter fields, revisions, form metadata, scripts, or another metadata object.

Evidence:

```text
tests/evidence/2026-07-30-eventactions-parameters-createcoandlines-no-match.md
```

## Current Small Step — Filter EventActions.ExpandedParameters

Run this read-only REST v1 request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=ExpandedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, including an empty result.

### Interpretation Rules

```text
- A returned row proves only that ExpandedParameters contains CreateCoAndLines.
- Do not infer ActionType meaning from its number alone.
- Do not execute the action.
- Do not search SubstitutedParameters or revision metadata in the same step.
- If zero rows return, SubstitutedParameters becomes a later separate fallback.
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