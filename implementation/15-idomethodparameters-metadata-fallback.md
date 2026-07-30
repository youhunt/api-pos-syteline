# Implementation 15 — IDO Method Metadata Discovery

## Status

```text
/IDORequestService/ido/info/IdoMethodParameters : FAILED — HTTP 500
REST v1 IdoMethodParameters IDOInfo             : COMPLETED
CreateCoAndLines parameter row load              : COMPLETED
CreateCoAndLines parameter directions            : CONFIRMED
REST v1 IdoMethods IDOInfo                       : COMPLETED
CreateCoAndLines method row load                  : COMPLETED
Effective base collection contexts               : CONFIRMED
CreateCoAndLines JSON schema                     : NOT YET CONFIRMED
CreateCoAndLines execution                       : NOT ATTEMPTED
Customer Order creation                          : NOT STARTED
```

## Failed Legacy Metadata Route

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

## Completed CreateCoAndLines Parameter Load

Filtered metadata request:

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

Confirmed direction contract:

```text
Input  : CoAndLineInfoJson
In/Out : CoResult
Message: CoResult
```

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-parameters.md
tests/evidence/2026-07-30-create-co-and-lines-parameter-directions.md
```

## Successful REST v1 IdoMethods IDOInfo

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

Related nested metadata:

```text
MethodParameters
MethodResultSets
```

The published IDOInfo properties do not directly expose:

```text
ExtensionClass
Assembly
ImplementationClass
SourceCode
HelpUrl
JsonSchema
```

Evidence:

```text
tests/evidence/2026-07-30-idomethods-idoinfo-properties.md
```

## Completed CreateCoAndLines Method Row Load

Read-only request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethods/adv?props=CollectionName,MethodName,BaseCollectionName,MethodDesc,MethodType,TxnFlag,StoredProcName,DerOutriggerProfile,DerSpMethodsAllowed&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

The tenant returned three rows:

| CollectionName | MethodName | BaseCollectionName | MethodType | TxnFlag | StoredProcName | MethodDesc | DerOutriggerProfile | DerSpMethodsAllowed |
| --- | --- | --- | ---: | ---: | --- | --- | --- | ---: |
| `SLCos` | `CreateCoAndLines` | `SLCos` | 2 | 0 | NULL | NULL | NULL | 1 |
| `SLCos` | `CreateCoAndLines` | `SLCos_FT` | 2 | 0 | NULL | NULL | NULL | 1 |
| `SLCos` | `CreateCoAndLines` | `ZIT_SLCos` | 2 | 0 | NULL | NULL | NULL | 1 |

All three rows returned the same `_ItemId` value. Therefore they are currently treated as three effective collection/base contexts for one method metadata record, not as three independently confirmed implementations.

Confirmed method facts:

```text
IDO UI Method Type   : Extension Class - Standard Method
MethodType metadata  : 2
TxnFlag               : 0
StoredProcName        : NULL
MethodDesc            : NULL
DerOutriggerProfile   : NULL
DerSpMethodsAllowed   : 1
Effective base contexts:
- SLCos
- SLCos_FT
- ZIT_SLCos
```

The exact inheritance or extension relationship between these three collection names remains unconfirmed. Do not assume that `SLCos_FT` or `ZIT_SLCos` contains the implementation until collection-level metadata is inspected.

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
```

## Important Limitation

Metadata still does not reveal:

```text
- exact CoAndLineInfoJson property names and nesting
- required versus optional header fields
- required versus optional line fields
- accepted date and numeric formats
- whether co_num is generated or supplied
- success CoResult shape
- failure CoResult shape
- whether header and lines are created atomically
- whether another standard validation method must run first
- which collection layer contains the extension implementation
```

No business method was invoked and no Customer Order data was created or changed.

## Current Small Step — Inspect Collection Metadata Properties

Use a read-only IDOInfo request for the collection metadata IDO:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoCollections
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Purpose:

```text
- confirm whether IdoCollections exists in this tenant;
- identify properties for base collection, extension class, assembly, profile, or inheritance metadata;
- prepare a later filtered read of SLCos, SLCos_FT, and ZIT_SLCos.
```

Send the returned property names or the complete response.

Do not invoke `CreateCoAndLines`, create Process/Reprocess logic, inspect another business method, or create a Customer Order during this step.
