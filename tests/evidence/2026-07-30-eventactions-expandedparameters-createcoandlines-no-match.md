# Evidence — No EventActions.ExpandedParameters Match for CreateCoAndLines

Date: 30 July 2026

## Purpose

Search current tenant `EventActions` metadata for a derived `ExpandedParameters` reference containing:

```text
CreateCoAndLines
```

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActions/adv?props=EventName,EventHandlerSequence,Sequence,Description,ActionType,DerActionTypeText,Parameters,ExpandedParameters,SubstitutedParameters,AccessAs,EventHandlerRowPointer,RowPointer&filter=ExpandedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Response

```json
{
  "Items": [],
  "Message": "Success",
  "MessageCode": 0,
  "MoreRowsExists": false
}
```

The returned bookmark identified the `EventActions` collection keys, but no matching row was returned.

## Confirmed Result

```text
Request success                        : yes
MessageCode                            : 0
Rows returned                          : 0
MoreRowsExists                         : false
ExpandedParameters CreateCoAndLines hit: not found
```

No current `EventActions` row exposes `CreateCoAndLines` through `ExpandedParameters`.

This does not rule out a standard call site. The reference may still be in `SubstitutedParameters`, event-action revisions, event-handler revisions, form metadata, scripts, or another metadata object.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-action execution
No metadata edit
No Process/Reprocess implementation
```
