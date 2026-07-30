# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                         : DEV
Controlled malformed probes         : COMPLETED
All four no-order checks             : COMPLETED — ZERO ROWS
Base64 input requirement             : CONFIRMED
Decoded payload type                 : JSON object / JObject
Specific order structure required    : CONFIRMED
Exact business JSON schema           : NOT YET CONFIRMED
Further property-name guessing       : STOPPED
Standard call-site discovery         : STARTED — READ-ONLY
Candidate event metadata IDOs        : CONFIRMED
EventHandlers property discovery     : COMPLETED
Filtered MethodToCall search         : NEXT
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

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
```

## Completed Step — EventHandlers Property Metadata

REST v1 IDOInfo confirmed that `EventHandlers` publishes the following call-site-relevant properties:

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
EditableByWizard
Obsolete
Suspend
```

The strongest parent-row property for the first search is:

```text
MethodToCall
```

Context properties to return with each match are:

```text
EventName
Sequence
Description
Purpose
IDOCollections
AppliesToObjects
AccessAs
Active
InitialAction
InitialActionSequence
MethodToCall
```

`EventActions` is published as `CONTAINS`; its child-property schema has not yet been inspected and must not be guessed.

Evidence:

```text
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
```

## Current Small Step — Filter EventHandlers by MethodToCall

Run this read-only REST v1 request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventHandlers/adv?props=EventName,Sequence,Description,Purpose,IDOCollections,AppliesToObjects,AccessAs,Active,InitialAction,InitialActionSequence,MethodToCall&filter=MethodToCall%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, including an empty result.

### Interpretation Rules

```text
- A returned row is evidence only that the parent handler MethodToCall references the target text.
- Do not infer action parameters from the parent row.
- Do not inspect EventHandlerRevisions or EventActions in the same step.
- If zero rows are returned, the next separate path will inspect EventActions metadata or other script/form metadata.
```

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines again.
- Do not guess a Customer Order JSON property.
- Do not edit form handlers, event actions, scripts, events, or metadata.
- Do not query EventHandlerRevisions in the same step.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```
