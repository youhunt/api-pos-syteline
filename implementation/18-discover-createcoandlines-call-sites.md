# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                         : DEV
Controlled malformed probes         : COMPLETED
All four no-order checks             : COMPLETED — ZERO ROWS
Base64 input requirement             : CONFIRMED
Decoded payload type                 : JSON object / JObject
Specific order structure required   : CONFIRMED
Exact business JSON schema           : NOT YET CONFIRMED
Further property-name guessing      : STOPPED
Standard call-site discovery        : STARTED — READ-ONLY
Candidate event metadata IDOs       : CONFIRMED
EventHandlers property discovery    : COMPLETED
Filtered MethodToCall search        : COMPLETED — ZERO ROWS
Event-action collection discovery   : COMPLETED
EventActions property discovery     : NEXT
```

## Why the Discovery Path Changes

The completed runtime probes confirmed:

```text
1. raw input is rejected unless it is valid Base64;
2. decoded content is parsed as a JSON object / JObject;
3. an empty object is treated as blank order input;
4. an arbitrary non-business property is also treated as blank order input;
5. no Customer Order was created by any of the four probes in the checked windows.
```

The method therefore expects one or more specific business members or a specific nested order structure. Guessing names such as `Order`, `Header`, `Lines`, `Co`, or similar is not authorized because tenant evidence has not confirmed them.

The safe path is to locate a standard form event handler, form script, global script, application event action, or another metadata call site that invokes:

```text
SLCos.CreateCoAndLines
```

A standard call site may reveal the exact JSON construction and Base64 encoding behavior.

## Completed Step — Candidate Event Metadata Collections

Read-only tenant metadata returned:

| CollectionName | Description | ServerName | AccessAs |
| --- | --- | --- | --- |
| `EventHandlerRevisions` | Event Handler Revisions | `MGCore` | `Core` |
| `EventHandlers` | Event Handlers | `MGCore` | `Core` |
| `EventHandlerStates` | Event Handler Status | `MGCore` | `Core` |
| `IdoEventHandlerAppliesToObjects` | NULL | `MGCore` | `Core` |
| `IdoEventHandlerAppliesToTasks` | NULL | `MGCore` | `Core` |
| `QueuedEventHandlers` | Event Queue | `MGCore` | `Core` |

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
```

## Completed Step — EventHandlers Property Metadata

Relevant published properties include:

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

Evidence:

```text
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
```

## Completed Step — Filter EventHandlers.MethodToCall

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

This does not rule out a standard call site. The reference may be in child event actions, revisions, form metadata, scripts, or another metadata object.

Evidence:

```text
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
```

## Completed Step — Event-Action Collection Discovery

Read-only `IdoCollections` discovery returned:

| CollectionName | Description | ServerName | AccessAs |
| --- | --- | --- | --- |
| `EventAction_GenericParms` | Event Action - Generic Parameters | `MGCore` | `Core` |
| `EventActionRevisions` | Event Action - Revisions | `MGCore` | `Core` |
| `EventActions` | Event Actions | `MGCore` | `Core` |
| `EventActionStates` | Event Handler Status – Actions tab | `MGCore` | `Core` |
| `EventActionVariableAccess` | Event Actions – Variable Access tab | `MGCore` | `Core` |

The primary candidate for child action records is:

```text
EventActions
```

The other collections appear, from tenant-provided descriptions, to support generic parameters, revisions, state/status, or variable access. Their property contracts remain uninspected.

Evidence:

```text
tests/evidence/2026-07-30-event-action-metadata-collections.md
```

## Current Small Step — Read EventActions Property Metadata

Use REST v1 IDOInfo:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventActions
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete response, especially the published `Properties` list.

The purpose is to identify actual tenant fields that may hold:

```text
action type
action description
method or function name
target IDO
parameters
expression or script text
parent event/handler identifiers
sequence or action GUID
```

These are search objectives only, not assumed property names.

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines again.
- Do not guess a Customer Order JSON property.
- Do not load or edit EventActions rows yet.
- Do not inspect EventActionRevisions in the same step.
- Do not edit form handlers, event actions, scripts, events, or metadata.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```