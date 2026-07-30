# Evidence — Event Handler Metadata Collections

Date: 30 July 2026

## Purpose

Identify the actual tenant metadata IDOs that may contain a standard call site for:

```text
SLCos.CreateCoAndLines
```

This discovery was performed read-only through `IdoCollections`.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25FormEvent%25%27%20OR%20CollectionName%20LIKE%20%27%25EventHandler%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Result

| CollectionName | Description | ServerName | AccessAs |
| --- | --- | --- | --- |
| `EventHandlerRevisions` | Event Handler Revisions | `MGCore` | `Core` |
| `EventHandlers` | Event Handlers | `MGCore` | `Core` |
| `EventHandlerStates` | Event Handler Status | `MGCore` | `Core` |
| `IdoEventHandlerAppliesToObjects` | NULL | `MGCore` | `Core` |
| `IdoEventHandlerAppliesToTasks` | NULL | `MGCore` | `Core` |
| `QueuedEventHandlers` | Event Queue | `MGCore` | `Core` |

The request returned:

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
```

## Technical Interpretation

The strongest candidates for locating a declarative or script-based call site are:

```text
EventHandlers
EventHandlerRevisions
```

The remaining collections appear, by tenant-provided descriptions and names, to represent status, applicability, task/object association, or queued execution. Their exact properties have not yet been inspected.

No property names or handler content are inferred at this stage. The next read-only step is to inspect the published property metadata for `EventHandlers`.

## Safety Result

```text
No CreateCoAndLines invocation
No form/event/script metadata edit
No Customer Order payload
No Customer Order creation
No Process/Reprocess implementation
```