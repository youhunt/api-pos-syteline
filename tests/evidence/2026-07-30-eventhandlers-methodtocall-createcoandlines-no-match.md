# Evidence — No EventHandlers.MethodToCall Match for CreateCoAndLines

Date: 30 July 2026

## Purpose

Search the tenant's parent `EventHandlers` metadata for a direct `MethodToCall` reference containing:

```text
CreateCoAndLines
```

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventHandlers/adv?props=EventName,Sequence,Description,Purpose,IDOCollections,AppliesToObjects,AccessAs,Active,InitialAction,InitialActionSequence,MethodToCall&filter=MethodToCall%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Response

```json
{
  "Bookmark": "<B><P><p>EventName</p><p>Sequence</p></P><D><f>false</f><f>false</f></D><F><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /></F><L><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /><v d3p1:nil=\"true\" xmlns:d3p1=\"http://www.w3.org/2001/XMLSchema-instance\" /></L></B>",
  "Items": [],
  "Message": "Success",
  "MessageCode": 0,
  "MoreRowsExists": false
}
```

## Confirmed Result

```text
Request success                 : yes
MessageCode                     : 0
Rows returned                   : 0
MoreRowsExists                  : false
Direct parent MethodToCall match: not found
```

## Technical Interpretation

No parent `EventHandlers` row stores `CreateCoAndLines` directly in the published `MethodToCall` property.

This does not prove that no standard call site exists. The reference may instead be located in:

```text
- child event-action metadata;
- an event-handler revision;
- form event metadata;
- form or global scripts;
- another standard metadata object.
```

The next safe step is to discover the tenant's actual collection name or names related to event actions through read-only `IdoCollections` metadata. Do not assume that the `CONTAINS` property name `EventActions` is automatically the loadable child IDO name.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-handler edit
No event-action edit
No Process/Reprocess implementation
```
