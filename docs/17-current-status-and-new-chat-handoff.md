# 17 — Current Status and New Chat Handoff

## Project

```text
Repository : youhunt/api-pos-syteline
Project    : Pizza Hut POS / SMK069 Sales Integration to Infor SyteLine Mongoose
Updated    : 30 July 2026
```

## Target Flow

```text
POS sample CSV / REST payload
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ reusable validation
→ Error Processing form
→ reusable Process/Reprocess method
→ supported Customer Order business process
→ co_mst + coitem_mst
```

The official POS payload/file layout is not yet available. The final target remains controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst during Customer Order processing
```

`cost` is not stored in staging. Standard `SiteRef` is used; no duplicate `site_ref` column exists.

## Current Objects

```text
Metadata table                     : SMK069_temp_sales_mst
Physical table                     : dbo.ue_SMK069_temp_sales_mst
Entity IDO                         : ue_SMK069TempSales
Error form                         : ue_SMK069APISalesErrorProcessing
Validation procedure               : dbo.SMK069ValidateCustomerSp
Validation IDO method              : ue_SMK069ValidateCustomerSp
Standard Customer Order header IDO : SL.SLCos
Standard Customer Order line IDO   : SL.SLCoitems
Primary key                        : SiteRef + co_num + co_line
```

## Current Progress

```text
[COMPLETED] SMK069_temp_sales_mst and six process-control columns
[COMPLETED] ue_SMK069TempSales IDO and resynchronization
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display mapping and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp
[COMPLETED] ue_SMK069ValidateCustomerSp transactional IDO method
[COMPLETED] invalid-customer and valid-customer SQL/Mongoose REST tests
[COMPLETED] mandatory customer validation requirement
[CONFIRMED] standard Customer Order header IDO = SL.SLCos
[CONFIRMED] standard Customer Order line IDO = SL.SLCoitems
[REVIEWED]  SL.SLCos method-name list
[CONFIRMED] CreateCoAndLines = Extension Class - Standard Method, not SP
[CONFIRMED] CoAndLineInfoJson = input-only
[CONFIRMED] CoResult = input/output + message parameter
[CONFIRMED] collection hierarchy: SLCos base; SLCos_FT and ZIT_SLCos extend SLCos
[CONFIRMED] base extension owner metadata = Customer.SLCos, assembly Customer
[NEXT]      inspect Customer assembly metadata/source availability read-only
[NOT STARTED] custom Process/Reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] final external REST API contract and Postman collection
```

## Verified Customer Validation

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
Parameters    : SiteRef, CoNum, Infobar
```

Verified outcomes:

```text
Invalid customer → process_status E + validation_msg
Valid customer   → process_status V + validation_msg NULL
```

The validation method is reusable by the form, CSV/import path, controlled API receive method, and Process/Reprocess action.

## Confirmed Standard Customer Order Objects

```text
Header primary collection : SL.SLCos
Line primary collection   : SL.SLCoitems
Collection Name           : blank / not assigned on both forms
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

## Confirmed CreateCoAndLines Contract Metadata

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

| Sequence | Parameter | Data Type | InputFlag | OutputFlag | MessageFlag |
| ---: | --- | --- | ---: | ---: | ---: |
| 1 | `CoAndLineInfoJson` | `VARIANT` | 1 | 0 | 0 |
| 2 | `CoResult` | `VARIANT` | 1 | 1 | 1 |

Confirmed direction:

```text
CoAndLineInfoJson : input-only
CoResult          : input/output and framework message parameter
```

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-parameters.md
tests/evidence/2026-07-30-create-co-and-lines-parameter-directions.md
```

## Confirmed Collection Hierarchy and Extension Owner

Tenant `IdoCollections` metadata returned:

| Collection | Extends | Ext Class | Namespace | Assembly | Server | Access As | Runtime Identity |
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

Technical conclusion:

```text
Base Customer Order extension class : Customer.SLCos
Custom assembly                     : Customer
```

`SLCos_FT` and `ZIT_SLCos` inherit from `SLCos` and do not publish their own extension class, namespace, or assembly in the returned metadata.

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
tests/evidence/2026-07-30-idocollections-idoinfo-properties.md
tests/evidence/2026-07-30-idocollections-slcoss-hierarchy.md
```

No standard business method has been executed and no Customer Order has been created.

## What Is Still Unknown

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
- whether source code for assembly Customer is available in this tenant
```

## Immediate Next Step

Open the standard **IDO Extension Class Assemblies** form and filter:

```text
Assembly Name = Customer
```

Read only. Capture:

```text
Assembly Name
Assembly Type
Language
References
Source Code availability/button state
Binary or DLL information, if displayed
```

Do not check out, edit, build, import, save, resynchronize, or invoke `CreateCoAndLines`.

## API Direction

```text
POS / Postman / CSV
→ controlled service IDO receive method
→ custom staging
→ reusable validation
→ reusable Process/Reprocess method
→ supported Customer Order business processing
→ co_mst + coitem_mst
```

Direct SQL insertion into `co_mst` or `coitem_mst` remains prohibited.

## Development Rules

1. Work one small step at a time.
2. Use tenant screenshots and actual metadata as authority.
3. Distinguish metadata object names from physical SQL names.
4. Do not mark a step completed until tenant evidence confirms it.
5. Keep validation and processing reusable by form, CSV, and REST API paths.
6. Never direct-insert into `co_mst` or `coitem_mst`.
7. Item mapping and broader item validation remain postponed.
8. Distinguish Stored Procedure methods from Extension Class methods.
9. Do not invoke `CreateCoAndLines` until the JSON contract and controlled test conditions are confirmed.

## Repository Documents to Read First

```text
docs/16-smk069-sales-spec-alignment.md
docs/17-current-status-and-new-chat-handoff.md
database/tables/SMK069_temp_sales_mst.md
database/stored-procedures/SMK069ValidateCustomerSp.sql
implementation/11-create-SMK069-temp-sales-table.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
implementation/13-create-SMK069-customer-validation.md
implementation/14-discover-standard-customer-order-processing.md
implementation/15-idomethodparameters-metadata-fallback.md
tests/evidence/2026-07-30-idocollections-slcoss-hierarchy.md
CHANGELOG.md
```

## Ready-to-Paste New-Chat Prompt

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Current status:
- staging, IDO, Error Processing form, Preview, process_status mapping, and customer validation are complete;
- standard Customer Order header IDO = SL.SLCos;
- standard Customer Order line IDO = SL.SLCoitems;
- CreateCoAndLines is an Extension Class - Standard Method, Transactional unchecked, and not a Stored Procedure;
- CoAndLineInfoJson is input-only;
- CoResult is input/output and MessageFlag = 1;
- SLCos is the base collection with extension class Customer.SLCos in assembly Customer;
- SLCos_FT and ZIT_SLCos both extend SLCos and do not publish their own extension class/assembly;
- the exact JSON schema and result contract remain unconfirmed;
- no standard business method has been executed;
- custom Process/Reprocess, Customer Order creation, controlled receive service, and final POS API are not complete.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Open IDO Extension Class Assemblies, filter Assembly Name = Customer, and capture Assembly Type, Language, References, Source Code availability, and binary/DLL information. Do not edit, build, save, or invoke CreateCoAndLines.
```