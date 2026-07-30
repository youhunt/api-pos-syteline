# Implementation 15 — IdoMethodParameters Metadata Fallback

## Status

```text
/IDORequestService/ido/info/IdoMethodParameters : FAILED — HTTP 500
REST v1 IDOInfo fallback                       : COMPLETED
Relevant metadata properties                   : CONFIRMED
CreateCoAndLines parameter row load             : PENDING
CreateCoAndLines execution                      : NOT ATTEMPTED
Customer Order creation                         : NOT STARTED
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

This result did not prove that `IdoMethodParameters` was missing. It only proved that this route failed in the tenant without returning a structured Mongoose error.

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
```

## Successful REST v1 IDOInfo Fallback

The REST v1 IDOInfo route returned the published property metadata for `IdoMethodParameters`.

Relevant confirmed properties:

```text
CollectionName
MethodName
ParameterName
Sequence
DataType
InputFlag
OutputFlag
MessageFlag
```

Supporting properties also include:

```text
SpDataType
SpDataLength
SpDataScale
DevelopmentFlag
CreateDate
CreatedBy
RecordDate
UpdatedBy
RowPointer
_ItemId
_ItemWarnings
```

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md
```

No business method was invoked and no Customer Order data was created or changed.

## Current Small Step — Load Only CreateCoAndLines Parameter Rows

Use the REST v1 Advanced LoadCollection route:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

This is read-only metadata loading. It does not invoke `CreateCoAndLines`.

Expected rows:

```text
CoAndLineInfoJson
CoResult
```

The returned property order is:

```text
1. CollectionName
2. MethodName
3. ParameterName
4. Sequence
5. DataType
6. InputFlag
7. OutputFlag
8. MessageFlag
```

Send the complete JSON response. Do not invoke `CreateCoAndLines`, create Process/Reprocess logic, or create a Customer Order during this step.
