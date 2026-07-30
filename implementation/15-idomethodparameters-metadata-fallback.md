# Implementation 15 — IDO Method, Collection, and Assembly Discovery

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
Customer assembly metadata                   : CONFIRMED — BINARY ONLY
Tenant source-code path                      : NOT AVAILABLE THROUGH THIS ASSEMBLY RECORD
CreateCoAndLines JSON schema                 : NOT YET CONFIRMED
CreateCoAndLines execution                   : NOT ATTEMPTED
Customer Order creation                      : NOT STARTED
```

## Safety Boundary

All completed discovery steps were read-only.

```text
No CreateCoAndLines invocation
No Customer Order created or modified
No standard metadata edited
No assembly checkout, import, build, or save
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
Best implementation owner for CreateCoAndLines:
Customer.SLCos in assembly Customer
```

Evidence:

```text
tests/evidence/2026-07-30-idocollections-idoinfo-properties.md
tests/evidence/2026-07-30-idocollections-slcoss-hierarchy.md
```

## 5. Confirmed Customer Assembly Record

The standard **IDO Extension Class Assemblies** form was inspected read-only with:

```text
Assembly Name = Customer
```

Confirmed values:

```text
Assembly Name         : Customer
Revision Num          : 1
Revision Date         : 5/12/2026
Locked By             : blank
Access As             : BaseSyteLine
Assembly Type         : Binary Only
Extend And Replace    : blank
Language              : blank
Assembly File Version : blank
References            : blank
Filename              : Customer
Full Name             : Customer, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null
Symbol File Name      : Customer.pdb
```

Technical decision:

```text
The Customer extension assembly is Binary Only in this tenant.
The tenant form does not expose source code for Customer.SLCos.
The source-code discovery branch is therefore closed.
```

The visible symbol-file name does not reveal the `CoAndLineInfoJson` contract.

Evidence:

```text
tests/evidence/2026-07-30-customer-assembly-binary-only.md
```

## 6. Remaining Unknowns

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
```

## Current Small Step — Confirm a Safe Runtime-Test Environment

Before any controlled invalid-payload invocation, confirm only the environment boundary:

```text
- Is the current tenant/database DEV, TEST, UAT, or PRODUCTION?
- Is creation of a disposable test Customer Order allowed there?
```

Do not invoke `CreateCoAndLines` yet.

The next technical branch depends on this answer:

```text
Non-production + disposable test allowed
→ design one controlled malformed/minimal request with pre/post verification

Production or test creation not allowed
→ stop runtime probing and request an official contract/sample from Infor or the solution owner
```

Do not create Process/Reprocess logic, import CSV, create the receive API method, or create a Customer Order during this step.
