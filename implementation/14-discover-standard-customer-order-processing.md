# Implementation 14 — Discover Standard Customer Order Processing

## Current Status

```text
Customer validation              : FULLY COMPLETED
Process/Reprocess design          : STARTED — DISCOVERY ONLY
Standard Customer Order IDO       : CONFIRMED — SL.SLCos
Standard Customer Order line IDO  : CONFIRMED — SL.SLCoitems
SL.SLCos method list              : REVIEWED
CreateCoAndLines method attributes: PARTIALLY CONFIRMED
CreateCoAndLines parameters       : NOT YET REVIEWED
Standard header creation process  : NOT YET CONFIRMED
Standard line creation process    : NOT YET CONFIRMED
Customer Order creation           : NOT STARTED
Form Process button               : NOT STARTED
Controlled API receive method     : NOT STARTED
```

## Objective

Identify the exact standard Customer Order IDOs and supported business process available in the user's SyteLine tenant before creating the custom Process/Reprocess method.

The final custom processor must create:

```text
Customer Order Header
Customer Order Lines
```

with the intended result stored by standard SyteLine processing in:

```text
co_mst
coitem_mst
```

Direct SQL insertion into those tables is prohibited.

## Reusable Architecture

```text
Error Processing form Process action
or
controlled POS/API service
        ↓
custom reusable Process/Reprocess method
        ↓
customer validation
        ↓
standard SyteLine Customer Order IDO/business process
        ↓
co_mst + coitem_mst
```

The form and future API must call the same processing core.

## Processing Scope

One call processes one staged order group:

```text
SiteRef + co_num
```

All staging lines belonging to that group must be handled together.

## Discovery Attempt 1 — Customers Form

The first screenshot displayed:

```text
Primary Collection : SL.SLCustomers
Collection Name    : oCustomers
```

This belongs to the standard **Customers** form and is not a Customer Order IDO.

```text
SL.SLCustomers = customer-master IDO only
```

No standard object was modified.

## Confirmed Customer Order Header IDO

The correct standard **Customer Orders** form displayed:

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

Decision:

```text
Standard Customer Order header IDO : SL.SLCos
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
```

## Confirmed Customer Order Line IDO

The standard **Customer Order Lines** form displayed:

```text
Primary Collection : SL.SLCoitems
Collection          : SL.SLCoitems
Collection Name     : blank / not assigned
```

Decision:

```text
Standard Customer Order line IDO : SL.SLCoitems
```

The tenant's standard entity IDOs are therefore:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

No standard form, collection, IDO, property, or method was modified during discovery.

## SL.SLCos Header Method Discovery

The available method list for `SL.SLCos` was reviewed from tenant metadata.

The list contains many inquiry, status, copy, validation, reporting, and processing methods. The creation-related candidates are:

| Method | Method Type | Transactional | Initial Assessment |
| --- | --- | ---: | --- |
| `CreateCoAndLines` | Extension Class - Standard Method | No | Strongest combined header-and-line candidate; parameter contract not yet inspected |
| `NewCustomerOrderValidSp` | Extension Class - Standard Method | Yes | Validates a new order and may return a default `co_num` |
| `CreateCoColSp` | Extension Class - Standard Method | Yes | Candidate header/collection creation method |
| `CoCustomerValidSp` | Extension Class - Standard Method | Yes | Customer validation and downstream default population |
| `CoCustomerValid2Sp` | Extension Class - Standard Method | No | Additional customer validation candidate |
| `CoCustSeqValidSp` | Extension Class - Standard Method | Yes | Customer ship-to validation candidate |
| `VerifyCoCustNumSp` | Extension Class - Standard Method | Yes | Customer/order verification candidate |
| `CoNextKeyDelSp` | Extension Class - Standard Method | Yes | Possibly related to order-key handling; purpose not assumed |
| `SumCoSp` | Extension Class - Standard Method | Yes | Likely recalculation/summary after creation |

Evidence:

```text
tests/evidence/2026-07-30-slcoss-header-method-list.md
```

## Confirmed `CreateCoAndLines` Method Attributes

Tenant metadata confirms:

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : not enabled / false according to the method list
Stored Proc.  : not applicable; this is not a Stored Procedure method
```

Important distinction:

```text
CreateCoAndLines is implemented by the standard SL.SLCos extension class.
It must not be documented or configured as a Stored Procedure method.
There is no Stored Procedure name to capture for this method.
```

The implementation-class source code is not exposed by the IDO Methods screen. The supported public contract is represented by the method name, method type, transactional setting, and generated parameter metadata.

## Discovery Decision

The tenant clearly provides dedicated Customer Order business methods. However, method names and method type alone do not prove the supported SMK069 creation sequence.

Still unknown:

```text
- CreateCoAndLines parameter contract
- whether CreateCoAndLines accepts serialized data, XML, JSON, IDO datasets, or scalar values
- whether it creates both SL.SLCos and SL.SLCoitems records atomically
- how Customer Order numbering is generated or accepted
- minimum required header and line values
- whether NewCustomerOrderValidSp must be called first
- whether CoCustomerValidSp must populate default values before creation
- whether UpdateCollection is still required
- expected return values and Infobar behavior
```

Do not implement the custom Process/Reprocess method until these tenant-specific details are confirmed.

## Current Small Step — Inspect Only the Parameters

Remain on `SL.SLCos` method `CreateCoAndLines` and perform only this discovery step:

1. do not edit, resync, save, or execute the method;
2. capture all parameter rows;
3. include parameter name, sequence, and user data type;
4. include parameter direction if the tenant screen exposes it;
5. include any output-property area if populated;
6. send the screenshot or copy the parameter table.

Required evidence:

```text
Parameter Name
Sequence
User Data Type
Input/output direction, if visible
Custom Load Method Output Properties, if any
```

Do not look for a Stored Procedure field or value; it is not applicable to this Extension Class method.

Do not inspect another method in the same step.

Do not inspect `SL.SLCoitems` methods yet.

Do not create the custom Process method, Process button, Customer Order, CSV import, or API receive method yet.

## Next Step After `CreateCoAndLines` Parameters

After the complete parameter contract is visible:

```text
- determine whether the method is suitable for SMK069;
- map staging fields to its required inputs;
- decide whether NewCustomerOrderValidSp is also required;
- only then inspect the next relevant method or SL.SLCoitems methods.
```

Each discovery action will be performed one small step at a time.