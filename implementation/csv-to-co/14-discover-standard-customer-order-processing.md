# Implementation 14 — Discover Standard Customer Order Processing

## Current Status

```text
Customer validation                : FULLY COMPLETED
Process/Reprocess design            : DISCOVERY ONLY
Standard Customer Order header IDO  : CONFIRMED — SL.SLCos
Standard Customer Order line IDO    : CONFIRMED — SL.SLCoitems
SL.SLCos method list                : REVIEWED
CreateCoAndLines attributes         : CONFIRMED
CreateCoAndLines parameter names    : CONFIRMED
CreateCoAndLines parameter direction: CONFIRMED
CreateCoAndLines JSON schema        : NOT YET CONFIRMED
Standard creation process           : NOT YET CONFIRMED
Customer Order creation             : NOT STARTED
Form Process button                 : NOT STARTED
Controlled API receive method       : NOT STARTED
```

## Objective

Identify the exact standard Customer Order IDOs and supported business process available in the user's SyteLine tenant before creating the reusable custom Process/Reprocess method.

The final processor must create Customer Order Header and Customer Order Lines through supported SyteLine processing, with final records stored in:

```text
co_mst
coitem_mst
```

Direct SQL insertion into those standard tables is prohibited.

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

One processing call handles one staged group:

```text
SiteRef + co_num
```

All staging lines in that group must be processed together.

## Confirmed Standard Entity IDOs

```text
Customer Order Header IDO : SL.SLCos
Customer Order Line IDO   : SL.SLCoitems
Collection Name           : blank / not assigned on both standard forms
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

The earlier `SL.SLCustomers / oCustomers` screenshot belonged to the Customers form and is customer-master metadata only.

## SL.SLCos Method Discovery

Creation-related candidates found in the tenant:

| Method | Method Type | Transactional | Initial Assessment |
| --- | --- | ---: | --- |
| `CreateCoAndLines` | Extension Class - Standard Method | No | Strongest combined header-and-line candidate |
| `NewCustomerOrderValidSp` | Extension Class - Standard Method | Yes | Validates a new order and may return a default `co_num` |
| `CreateCoColSp` | Extension Class - Standard Method | Yes | Candidate header/collection creation method |
| `CoCustomerValidSp` | Extension Class - Standard Method | Yes | Customer validation and downstream default population |
| `CoCustomerValid2Sp` | Extension Class - Standard Method | No | Additional customer-validation candidate |
| `CoCustSeqValidSp` | Extension Class - Standard Method | Yes | Customer ship-to validation candidate |
| `VerifyCoCustNumSp` | Extension Class - Standard Method | Yes | Customer/order verification candidate |
| `CoNextKeyDelSp` | Extension Class - Standard Method | Yes | Purpose not yet assumed |
| `SumCoSp` | Extension Class - Standard Method | Yes | Possible recalculation/summary method |

Evidence:

```text
tests/evidence/2026-07-30-slcoss-header-method-list.md
```

## Confirmed `CreateCoAndLines` Attributes

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

`CreateCoAndLines` is implemented by the standard `SL.SLCos` extension class. It is not a Stored Procedure method.

## Confirmed Parameter Metadata

| Sequence | Parameter | Data Type | InputFlag | OutputFlag | MessageFlag |
| ---: | --- | --- | ---: | ---: | ---: |
| 1 | `CoAndLineInfoJson` | `VARIANT` | 1 | 0 | 0 |
| 2 | `CoResult` | `VARIANT` | 1 | 1 | 1 |

Confirmed direction contract:

```text
CoAndLineInfoJson : input-only
CoResult          : input/output and message parameter
```

The **Custom Load Method Output Properties** area is blank because this is a standard method.

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-parameters.md
tests/evidence/2026-07-30-create-co-and-lines-parameter-directions.md
```

## What Is Still Unknown

```text
- exact CoAndLineInfoJson schema
- required and optional header fields
- required and optional line fields
- accepted date and numeric formats
- whether co_num is generated or supplied
- success CoResult shape
- failure CoResult shape
- whether header and lines are created atomically
- whether NewCustomerOrderValidSp or CoCustomerValidSp must run first
- whether UpdateCollection participates in the process
```

Do not implement Process/Reprocess until these tenant-specific details are verified.

## Current Small Step

Read the published metadata for `IdoMethods` only:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoMethods
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the returned property-name list. We are looking for any extension-class, assembly, implementation-reference, source, help, or description property that can lead to the documented JSON contract.

This request is metadata-only. Do not invoke `CreateCoAndLines`, inspect another business method, create Process/Reprocess logic, or create a Customer Order during this step.
