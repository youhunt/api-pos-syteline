# Implementation 14 — Discover Standard Customer Order Processing

## Current Status

```text
Customer validation               : FULLY COMPLETED
Process/Reprocess design           : STARTED — DISCOVERY ONLY
Standard Customer Order header IDO : CONFIRMED — SL.SLCos
Standard Customer Order line IDO   : CONFIRMED — SL.SLCoitems
SL.SLCos method list               : REVIEWED
CreateCoAndLines attributes        : CONFIRMED
CreateCoAndLines parameter names   : CONFIRMED
Parameter directions / JSON schema : NOT YET CONFIRMED
Standard creation process          : NOT YET CONFIRMED
Customer Order creation            : NOT STARTED
Form Process button                : NOT STARTED
Controlled API receive method      : NOT STARTED
```

## Objective

Identify the exact standard Customer Order IDOs and supported business process available in the user's SyteLine tenant before creating the custom Process/Reprocess method.

The final custom processor must create Customer Order Header and Customer Order Lines through supported SyteLine processing, with the final records stored in:

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

The form and future API must call the same processing core.

One processing call handles one staged order group:

```text
SiteRef + co_num
```

All staging lines for that group must be processed together.

## Confirmed Standard Entity IDOs

### Customer Order Header

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

### Customer Order Lines

```text
Primary Collection : SL.SLCoitems
Collection          : SL.SLCoitems
Collection Name     : blank / not assigned
```

Decision:

```text
Header IDO : SL.SLCos
Line IDO   : SL.SLCoitems
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

The earlier `SL.SLCustomers / oCustomers` screenshot belonged to the Customers form and is customer-master metadata only.

## SL.SLCos Method Discovery

The tenant method list includes several creation and validation candidates:

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

Tenant metadata confirms:

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

`CreateCoAndLines` is implemented by the standard `SL.SLCos` extension class. It is not a Stored Procedure method and there is no Stored Procedure name to configure.

## Confirmed `CreateCoAndLines` Parameter Metadata

The tenant displays two parameters:

| Sequence | Parameter Name | User Data Type |
| ---: | --- | --- |
| 1 | `CoAndLineInfoJson` | `VARIANT` |
| 2 | `CoResult` | `VARIANT` |

The **Custom Load Method Output Properties** area is blank, which is expected for a standard method rather than a custom load method.

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-parameters.md
```

## Current Interpretation — Not Yet Final Contract

The parameter names strongly suggest:

```text
CoAndLineInfoJson : JSON payload containing Customer Order header and line information
CoResult          : returned result/status payload
```

This is an inference from the parameter names, not yet a confirmed direction or JSON contract.

Still unknown:

```text
- whether CoResult is output-only or input/output
- the exact JSON property names and nesting
- required versus optional header fields
- required versus optional line fields
- how co_num is generated or accepted
- success and failure response shape
- whether the extension method creates header and lines atomically
- whether NewCustomerOrderValidSp or CoCustomerValidSp must be called first
- whether UpdateCollection participates in the process
```

Do not implement Process/Reprocess until these tenant-specific details are verified.

## Current Small Step — Read Metadata IDO Properties

Use a read-only metadata request to identify the properties exposed by the standard metadata IDO `IdoMethodParameters`.

```http
GET {{mongooseBaseUrl}}/IDORequestService/ido/info/IdoMethodParameters
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

This call reads IDO metadata only. It does not invoke `CreateCoAndLines` and cannot create a Customer Order.

Send the response, or at minimum the property names listed under `Properties`.

The next step will use those confirmed property names to load only the two parameter rows for `SLCos / CreateCoAndLines` and determine whether an output/by-reference flag is exposed.

Do not invoke `CreateCoAndLines`, inspect another business method, create Process logic, or create Customer Orders during this step.