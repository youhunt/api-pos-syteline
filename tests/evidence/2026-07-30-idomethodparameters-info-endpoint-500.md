# Evidence — IdoMethodParameters `/ido/info` Endpoint Returned 500

Date: 30 July 2026

## Read-Only Request Attempted

```http
GET {{mongooseBaseUrl}}/IDORequestService/ido/info/IdoMethodParameters
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Observed Result

```text
HTTP Status : 500 Internal Server Error
Response    : ASP.NET generic Runtime Error HTML
Application : /IDORequestService
Details     : hidden by server customErrors configuration
```

The response did not contain Mongoose JSON metadata or a specific authorization/object error.

## Interpretation

This result does **not** prove that the `IdoMethodParameters` IDO is missing. It only proves that this tenant/application-server route failed with a generic server-side error for this request.

Possible causes remain unconfirmed, including tenant/version route behavior, authorization to Core IDO metadata, configuration context, or an application-server issue.

## Safety Confirmation

The failed request was metadata read-only. It did not invoke `CreateCoAndLines`, did not create a Customer Order, and did not modify `co_mst`, `coitem_mst`, or custom staging.

## Next Controlled Fallback

Use the REST API v1 IDOInfo route, which is consistent with the already-working `MGRESTService.svc/json/method/...` calls:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoMethodParameters
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Do not invoke `CreateCoAndLines` during this fallback test.
