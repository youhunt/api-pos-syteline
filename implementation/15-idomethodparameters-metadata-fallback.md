# Implementation 15 — IdoMethodParameters Metadata Fallback

## Status

```text
/IDORequestService/ido/info/IdoMethodParameters : FAILED — HTTP 500
REST v1 IDOInfo fallback                       : PENDING
CreateCoAndLines execution                     : NOT ATTEMPTED
Customer Order creation                        : NOT STARTED
```

## Failed Read-Only Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/ido/info/IdoMethodParameters
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Observed response:

```text
500 Internal Server Error
ASP.NET generic Runtime Error page
Detailed exception hidden by server customErrors
```

The result does not prove that `IdoMethodParameters` is missing. It only proves that this route failed in the tenant without returning a structured Mongoose error.

No business method was executed and no Customer Order data was created or changed.

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
```

## Current Small Step

Try only the REST API v1 IDOInfo route:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoMethodParameters
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

This is a read-only metadata call. Send the JSON response or the returned property-name list.

Do not invoke `CreateCoAndLines` during this step.
