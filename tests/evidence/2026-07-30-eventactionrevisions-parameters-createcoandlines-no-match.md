# Evidence — No EventActionRevisions.Parameters Match for CreateCoAndLines

Date: 30 July 2026

## Purpose

Search tenant revision action metadata for a raw `Parameters` reference containing:

```text
CreateCoAndLines
```

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActionRevisions/adv?props=ActionType,Description,EventHandlerRowPointer,Sequence,Parameters,ExpandedParameters,RowPointer&filter=Parameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Response

```json
{
  "Bookmark": "<B><P><p>RowPointer</p></P><D><f>false</f></D><F><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /></F><L><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /></L></B>",
  "Items": [],
  "Message": "Success",
  "MessageCode": 0,
  "MoreRowsExists": false
}
```

## Confirmed Result

```text
Request success                               : yes
MessageCode                                   : 0
Rows returned                                 : 0
MoreRowsExists                                : false
EventActionRevisions.Parameters target match  : not found
```

No `EventActionRevisions` row stores `CreateCoAndLines` in raw `Parameters`.

This does not rule out a historical or revision call site. The remaining field in this collection is the derived/read-only `ExpandedParameters`; event-handler revisions, form metadata, scripts, and other metadata objects remain later paths.

## Next Read-Only Step

Search `EventActionRevisions.ExpandedParameters` for `CreateCoAndLines` in a separate request.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No revision execution
No metadata edit
No SQL execution
```
