# Evidence — No EventActions.SubstitutedParameters Match for CreateCoAndLines

Date: 30 July 2026

## Purpose

Search current tenant `EventActions` metadata for a derived `SubstitutedParameters` reference containing:

```text
CreateCoAndLines
```

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=SubstitutedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Response

```json
{
  "Bookmark": "<B><P><p>EventHandlerRowPointer</p><p>EvrEventName</p><p>RowPointer</p></P><D><f>false</f><f>false</f><f>false</f></D><F><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /></F><L><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /></L></B>",
  "Items": [],
  "Message": "Success",
  "MessageCode": 0,
  "MoreRowsExists": false
}
```

## Confirmed Result

```text
Request success                           : yes
MessageCode                               : 0
Rows returned                             : 0
MoreRowsExists                            : false
SubstitutedParameters CreateCoAndLines hit: not found
```

No current `EventActions` row exposes `CreateCoAndLines` through `SubstitutedParameters`.

The current `EventActions` fields checked are now:

```text
Parameters             : zero rows
ExpandedParameters     : zero rows
SubstitutedParameters  : zero rows
```

This does not rule out a standard call site. The reference may still exist in `EventActionRevisions`, `EventHandlerRevisions`, form metadata, scripts, or another metadata object.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-action execution
No metadata edit
No Process/Reprocess implementation
```
