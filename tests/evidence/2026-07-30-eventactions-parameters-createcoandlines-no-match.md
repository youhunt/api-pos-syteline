# Evidence — No EventActions.Parameters Match for CreateCoAndLines

Date: 30 July 2026

## Purpose

Search the tenant's child `EventActions` metadata for a raw action-parameter reference containing:

```text
CreateCoAndLines
```

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=Parameters%20LIKE%20%27%25CreateCoAndLines%25%27
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
Request success                    : yes
MessageCode                        : 0
Rows returned                      : 0
MoreRowsExists                     : false
Raw EventActions.Parameters match  : not found
```

## Technical Interpretation

No current `EventActions` row stores `CreateCoAndLines` in the raw `Parameters` property.

This does not prove that no standard call site exists. The reference may instead appear in:

```text
- ExpandedParameters;
- SubstitutedParameters;
- EventActionRevisions;
- EventHandlerRevisions;
- form metadata or scripts;
- another standard metadata object.
```

The next separate read-only fallback is `ExpandedParameters`. `SubstitutedParameters` and revisions are not searched in the same step.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-action edit
No metadata change
No Process/Reprocess implementation
```