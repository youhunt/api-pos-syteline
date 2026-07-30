# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                         : DEV
Controlled malformed probes         : COMPLETED
All four no-order checks            : COMPLETED — ZERO ROWS
Base64 input requirement            : CONFIRMED
Decoded payload type                : JSON object / JObject
Specific order structure required   : CONFIRMED
Exact business JSON schema          : NOT YET CONFIRMED
Further property-name guessing      : STOPPED
Standard call-site discovery        : STARTED — READ-ONLY
Candidate event metadata IDOs       : CONFIRMED
EventHandlers property discovery    : NEXT
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

## Completed Step — Candidate Metadata Collections

Read-only tenant metadata returned the following collections:

| CollectionName | Description | ServerName | AccessAs |
| --- | --- | --- | --- |
| `EventHandlerRevisions` | Event Handler Revisions | `MGCore` | `Core` |
| `EventHandlers` | Event Handlers | `MGCore` | `Core` |
| `EventHandlerStates` | Event Handler Status | `MGCore` | `Core` |
| `IdoEventHandlerAppliesToObjects` | NULL | `MGCore` | `Core` |
| `IdoEventHandlerAppliesToTasks` | NULL | `MGCore` | `Core` |
| `QueuedEventHandlers` | Event Queue | `MGCore` | `Core` |

Response status:

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
```

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
```

## Interpretation

The first metadata IDO to inspect is:

```text
EventHandlers
```

`EventHandlerRevisions` is also relevant, but it will not be inspected in the same small step. The other discovered IDOs appear to concern status, applicability, task/object association, or queued execution; their exact property contracts remain uninspected.

No handler-content property name is assumed yet.

## Current Small Step — Read EventHandlers Property Metadata

Use REST v1 IDOInfo:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventHandlers
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete response, especially the published `Properties` list.

The property list will determine whether `EventHandlers` exposes fields for:

```text
HandlerName
EventName
ActionType
ActionText
MethodName
IDOName
Script
Parameters
Description
Revision
```

These names are search objectives only, not assumed tenant property names.

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines again.
- Do not guess a Customer Order JSON property.
- Do not query EventHandlerRevisions in the same step.
- Do not edit form handlers, scripts, events, or metadata.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```