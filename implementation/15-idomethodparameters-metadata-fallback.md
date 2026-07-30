# Implementation 15 — IDO Method Metadata Discovery

## Status

```text
/IDORequestService/ido/info/IdoMethodParameters : FAILED — HTTP 500
REST v1 IdoMethodParameters IDOInfo             : COMPLETED
CreateCoAndLines parameter row load              : COMPLETED
CreateCoAndLines parameter directions            : CONFIRMED
REST v1 IdoMethods IDOInfo                       : COMPLETED
CreateCoAndLines method row load                  : PENDING
CreateCoAndLines JSON schema                     : NOT YET CONFIRMED
CreateCoAndLines execution                       : NOT ATTEMPTED
Customer Order creation                          : NOT STARTED
```

## Failed Legacy Read-Only Route

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

This did not prove that `IdoMethodParameters` was missing. It only proved that this route failed in the tenant.

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
```

## Successful REST v1 IdoMethodParameters IDOInfo

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

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md
```

## Completed CreateCoAndLines Parameter-Row Load

The tenant loaded only the rows for:

```text
CollectionName = SLCos
MethodName     = CreateCoAndLines
```

Request pattern:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Confirmed rows:

| Sequence | Parameter | Data Type | InputFlag | OutputFlag | MessageFlag |
| ---: | --- | --- | ---: | ---: | ---: |
| 1 | `CoAndLineInfoJson` | `VARIANT` | 1 | 0 | 0 |
| 2 | `CoResult` | `VARIANT` | 1 | 1 | 1 |

## Confirmed Public Direction Contract

```text
CoAndLineInfoJson
- input-only
- not output
- not message parameter

CoResult
- input/output
- message parameter
```

Therefore the extension method contract is currently confirmed as:

```text
Input  : CoAndLineInfoJson
In/Out : CoResult
Message: CoResult
```

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-parameter-directions.md
```

## Successful REST v1 IdoMethods IDOInfo

The tenant returned the published property metadata for `IdoMethods`.

Relevant scalar properties:

```text
CollectionName
MethodName
BaseCollectionName
MethodDesc
MethodType
TxnFlag
StoredProcName
DerOutriggerProfile
DerSpMethodsAllowed
DevelopmentFlag
```

Related nested metadata properties:

```text
MethodParameters
MethodResultSets
```

The response does **not** expose direct properties named like:

```text
ExtensionClass
Assembly
ImplementationClass
SourceCode
HelpUrl
JsonSchema
```

This means the IDOInfo property list alone does not reveal the extension-class source or the exact `CoAndLineInfoJson` contract.

Evidence:

```text
tests/evidence/2026-07-30-idomethods-idoinfo-properties.md
```

## Important Limitation

The confirmed metadata still does not reveal:

```text
- exact JSON property names and nesting
- required versus optional header fields
- required versus optional line fields
- whether co_num is generated or accepted
- success result shape
- failure result shape
- whether header and lines are created atomically
- whether another standard validation method must run first
```

No business method was invoked and no Customer Order data was created or changed.

## Current Small Step — Load Only the CreateCoAndLines Method Row

Use this read-only REST v1 Advanced LoadCollection request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethods/adv?props=CollectionName,MethodName,BaseCollectionName,MethodDesc,MethodType,TxnFlag,StoredProcName,DerOutriggerProfile,DerSpMethodsAllowed&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

This request reads only the method metadata row. It does not invoke `CreateCoAndLines`.

Send the complete JSON response.

Do not invoke `CreateCoAndLines`, create Process/Reprocess logic, inspect another business method, or create a Customer Order during this step.
