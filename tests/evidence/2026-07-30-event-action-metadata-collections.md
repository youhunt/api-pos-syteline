# Evidence — Event-Action Metadata Collections

Date: 30 July 2026

## Purpose

Identify the actual tenant metadata IDOs that may contain child event actions or supporting action metadata for a standard call site of:

```text
SLCos.CreateCoAndLines
```

The discovery was performed read-only through `IdoCollections`.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25EventAction%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Result

| CollectionName | Description | ServerName | AccessAs |
| --- | --- | --- | --- |
| `EventAction_GenericParms` | Event Action - Generic Parameters | `MGCore` | `Core` |
| `EventActionRevisions` | Event Action - Revisions | `MGCore` | `Core` |
| `EventActions` | Event Actions | `MGCore` | `Core` |
| `EventActionStates` | Event Handler Status – Actions tab | `MGCore` | `Core` |
| `EventActionVariableAccess` | Event Actions – Variable Access tab | `MGCore` | `Core` |

The request returned:

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
```

## Technical Interpretation

The strongest primary candidate for child action records is:

```text
EventActions
```

The remaining collections appear, based on tenant-provided descriptions, to support generic parameters, revisions, runtime/status state, or variable access. Their exact property contracts have not yet been inspected and must not be inferred from names alone.

The next read-only step is to inspect REST v1 IDOInfo for `EventActions` before filtering any action rows.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-handler edit
No event-action edit
No metadata change
No Process/Reprocess implementation
```