# Evidence — EventActionRevisions.ExpandedParameters Illegal Filter

Date: 30 July 2026

## Purpose

Attempt a read-only search for `CreateCoAndLines` through the derived `EventActionRevisions.ExpandedParameters` property.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActionRevisions/adv?props=ActionType,Description,EventHandlerRowPointer,Sequence,Parameters,ExpandedParameters,RowPointer&filter=ExpandedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Response

```json
{
  "Bookmark": null,
  "Items": null,
  "Message": "Error processing LoadCollection request: IllegalFilterException",
  "MessageCode": 450,
  "MoreRowsExists": false
}
```

## Confirmed Result

```text
Request success                 : no
MessageCode                     : 450
Exception                       : IllegalFilterException
Items                           : null
ExpandedParameters match result : NOT EVALUATED
```

This response is not a zero-row search result. The server rejected the filter before a collection result was produced.

`ExpandedParameters` is published as a derived/read-only property. The tenant response confirms that it cannot be relied on as a server-side filter in this request path.

## Technical Decision

Do not retry the same filter syntax and do not record this path as no match. Move to a different confirmed metadata source.

The next read-only step is to inspect the tenant-published property contract for `EventHandlerRevisions` before filtering any handler-revision rows.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No revision execution
No metadata edit
No SQL execution
```
