# Implementation 15 — IDO Method and Collection Metadata Discovery

## Status

```text
Legacy IdoMethodParameters info route       : FAILED — HTTP 500
REST v1 IdoMethodParameters IDOInfo         : COMPLETED
CreateCoAndLines parameter rows              : COMPLETED
CreateCoAndLines parameter directions        : CONFIRMED
REST v1 IdoMethods metadata                  : COMPLETED
CreateCoAndLines method rows                 : COMPLETED
REST v1 IdoCollections metadata              : COMPLETED
SLCos collection hierarchy                   : CONFIRMED
Base extension class and assembly             : CONFIRMED
CreateCoAndLines JSON schema                 : NOT YET CONFIRMED
CreateCoAndLines execution                   : NOT ATTEMPTED
Customer Order creation                      : NOT STARTED
```

## Safety Boundary

All requests documented here were metadata-only reads.

```text
No CreateCoAndLines invocation
No Customer Order created or modified
No standard metadata edited
No direct SQL insert into co_mst or coitem_mst
```

## 1. Metadata Route Result

The legacy route failed with a generic ASP.NET HTTP 500 response:

```http
GET {{mongooseBaseUrl}}/IDORequestService/ido/info/IdoMethodParameters
```

REST v1 metadata routes succeeded and became the tenant-supported discovery path.

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md
```

## 2. Confirmed CreateCoAndLines Method Contract

Tenant object:

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

Parameters:

| Sequence | Parameter | Data Type | InputFlag | OutputFlag | MessageFlag |
| ---: | --- | --- | ---: | ---: | ---: |
| 1 | `CoAndLineInfoJson` | `VARIANT` | 1 | 0 | 0 |
| 2 | `CoResult` | `VARIANT` | 1 | 1 | 1 |

Confirmed direction:

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

## 3. Confirmed Effective Method Rows

A filtered `IdoMethods` load returned the same method metadata through three base-collection contexts:

| CollectionName | BaseCollectionName | MethodType | TxnFlag | StoredProcName | MethodDesc |
| --- | --- | ---: | ---: | --- | --- |
| `SLCos` | `SLCos` | 2 | 0 | NULL | NULL |
| `SLCos` | `SLCos_FT` | 2 | 0 | NULL | NULL |
| `SLCos` | `ZIT_SLCos` | 2 | 0 | NULL | NULL |

All three rows returned the same `_ItemId`, so they represent one effective method record through inherited collection contexts.

Evidence:

```text
tests/evidence/2026-07-30-idomethods-idoinfo-properties.md
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
```

## 4. Confirmed Collection Hierarchy

A filtered `IdoCollections` load returned:

| Collection | Extends | Ext Class | Namespace | Assembly | Server | Access As | Server Plus Collection |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SLCos` | NULL | `SLCos` | `Customer` | `Customer` | `Customer` | `BaseSyteLine` | `Customer.SLCos` |
| `SLCos_FT` | `SLCos` | NULL | NULL | NULL | `WarehouseMobility` | `BaseSyteLine` | `WarehouseMobility.SLCos_FT` |
| `ZIT_SLCos` | `SLCos` | NULL | NULL | NULL | `ZITSL` | `ZIT` | `ZITSL.ZIT_SLCos` |

Confirmed hierarchy:

```text
SLCos
├── SLCos_FT extends SLCos
└── ZIT_SLCos extends SLCos
```

`SLCos` is the base Customer Order collection and directly publishes:

```text
Extension class : SLCos
Namespace       : Customer
Assembly        : Customer
Server project  : Customer
Runtime identity: Customer.SLCos
```

`SLCos_FT` and `ZIT_SLCos` inherit from `SLCos` and do not publish their own extension class, namespace, or custom assembly in the returned metadata.

Technical conclusion:

```text
Best implementation lead for CreateCoAndLines:
Customer.SLCos in assembly Customer
```

This conclusion is based on tenant metadata and confirms the owner metadata, but it does not expose source code or the JSON payload schema.

Evidence:

```text
tests/evidence/2026-07-30-idocollections-idoinfo-properties.md
tests/evidence/2026-07-30-idocollections-slcoss-hierarchy.md
```

## 5. Remaining Unknowns

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
- whether source code for the Customer assembly is available in this tenant
```

## Current Small Step — Inspect Assembly Metadata Only

Open the standard **IDO Extension Class Assemblies** form and filter:

```text
Assembly Name = Customer
```

Read only; do not check out, edit, build, import, save, or resynchronize anything.

Capture:

```text
Assembly Name
Assembly Type
Language
References
Source Code availability/button state
Binary or DLL information, if displayed
```

Purpose:

```text
- determine whether Customer is Build From Source or binary-only;
- determine whether tenant source code can be opened read-only;
- if source is available, locate Customer.SLCos.CreateCoAndLines and extract the exact JSON contract;
- if source is not available, choose a different controlled discovery path.
```

Do not invoke `CreateCoAndLines`, inspect another business method, create Process/Reprocess logic, or create a Customer Order during this step.