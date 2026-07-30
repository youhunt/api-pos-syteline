# Implementation 15 — IDO Method and Collection Metadata Discovery

## Status

```text
Legacy IdoMethodParameters info route       : FAILED — HTTP 500
REST v1 IdoMethodParameters IDOInfo         : COMPLETED
CreateCoAndLines parameter row load          : COMPLETED
CreateCoAndLines parameter directions        : CONFIRMED
REST v1 IdoMethods IDOInfo                   : COMPLETED
CreateCoAndLines method row load              : COMPLETED
Effective base collection contexts           : CONFIRMED
REST v1 IdoCollections IDOInfo               : COMPLETED
Collection implementation properties          : CONFIRMED
SLCos/SLCos_FT/ZIT_SLCos collection row load : PENDING
CreateCoAndLines JSON schema                 : NOT YET CONFIRMED
CreateCoAndLines execution                   : NOT ATTEMPTED
Customer Order creation                      : NOT STARTED
```

## Safety Boundary

All requests in this document are metadata-only reads. No standard business method has been invoked, and no Customer Order data has been created or changed.

Direct SQL insertion into `co_mst` or `coitem_mst` remains prohibited.

## 1. Failed Legacy Metadata Route

```http
GET {{mongooseBaseUrl}}/IDORequestService/ido/info/IdoMethodParameters
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Observed result:

```text
500 Internal Server Error
ASP.NET generic Runtime Error page
Detailed exception hidden by server customErrors
```

This did not prove that `IdoMethodParameters` was missing. It only proved that the legacy route failed in this tenant.

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
```

## 2. REST v1 IdoMethodParameters IDOInfo

The REST v1 IDOInfo route succeeded and exposed:

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

## 3. CreateCoAndLines Parameter Contract

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

## 4. IdoMethods Metadata

Relevant published properties:

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
MethodParameters
MethodResultSets
```

The published metadata does not directly expose properties named:

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

## 5. CreateCoAndLines Method Row

Read-only filtered request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethods/adv?props=CollectionName,MethodName,BaseCollectionName,MethodDesc,MethodType,TxnFlag,StoredProcName,DerOutriggerProfile,DerSpMethodsAllowed&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Returned rows:

| CollectionName | BaseCollectionName | MethodType | TxnFlag | StoredProcName | MethodDesc | DerOutriggerProfile | DerSpMethodsAllowed |
| --- | --- | ---: | ---: | --- | --- | --- | ---: |
| `SLCos` | `SLCos` | 2 | 0 | NULL | NULL | NULL | 1 |
| `SLCos` | `SLCos_FT` | 2 | 0 | NULL | NULL | NULL | 1 |
| `SLCos` | `ZIT_SLCos` | 2 | 0 | NULL | NULL | NULL | 1 |

All three rows returned the same `_ItemId`. Safe interpretation:

```text
- the method is one effective metadata record represented through three collection/base contexts;
- the inheritance relationship is not yet confirmed;
- do not assume which layer owns the extension implementation;
- MethodDesc, StoredProcName, and DerOutriggerProfile do not reveal the JSON contract.
```

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
```

## 6. IdoCollections IDOInfo

The tenant exposes collection-level implementation and inheritance metadata.

Relevant properties:

```text
CollectionName
Caption
CaptionOrName
CollectionDesc
Extends
ExtClassName
ExtClassNamespace
CustomAssemblyName
ServerName
AccessAs
OutriggerProfile
DerServerPlusCollection
ReplaceFlag
DevelopmentFlag
DerSpMethodsAllowed
```

Related nested metadata:

```text
Methods
Properties
Tables
Rules
DataRules
Filters
EventHandlerAppliesToObjects
```

The following fields are especially important for the next comparison:

```text
Extends
ExtClassName
ExtClassNamespace
CustomAssemblyName
ServerName
AccessAs
OutriggerProfile
DerServerPlusCollection
```

Evidence:

```text
tests/evidence/2026-07-30-idocollections-idoinfo-properties.md
```

## Remaining Unknowns

```text
- exact CoAndLineInfoJson property names and nesting
- required and optional Customer Order header fields
- required and optional line fields
- accepted date and numeric formats
- whether co_num is generated or supplied
- success CoResult shape
- failure CoResult shape
- whether header and lines are created atomically
- whether another standard validation method must run first
- actual inheritance and extension-class ownership across SLCos, SLCos_FT, and ZIT_SLCos
```

## Current Small Step — Load Three Collection Rows

Perform only this read-only request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,Extends,ExtClassName,ExtClassNamespace,CustomAssemblyName,ServerName,AccessAs,OutriggerProfile,DerServerPlusCollection,ReplaceFlag,DevelopmentFlag&filter=CollectionName%20%3D%20%27SLCos%27%20OR%20CollectionName%20%3D%20%27SLCos_FT%27%20OR%20CollectionName%20%3D%20%27ZIT_SLCos%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Expected collection names:

```text
SLCos
SLCos_FT
ZIT_SLCos
```

Purpose:

```text
- confirm the Extends chain;
- identify the extension class and namespace;
- identify any custom assembly or server project;
- identify access-as, outrigger, or server-plus collection references;
- determine which collection layer is the best lead for the CreateCoAndLines implementation contract.
```

Send the complete JSON response.

Do not invoke `CreateCoAndLines`, inspect another business method, create Process/Reprocess logic, or create a Customer Order during this step.