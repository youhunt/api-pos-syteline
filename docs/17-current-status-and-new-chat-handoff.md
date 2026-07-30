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

The official POS file/payload layout is not yet available. The final target remains controlled API integration.

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
[CONFIRMED] base extension owner = Customer.SLCos, assembly Customer
[CONFIRMED] Customer assembly type = Binary Only
[CONFIRMED] tenant source-code path for Customer.SLCos is unavailable through the assembly form
[NEXT]      confirm DEV/TEST/UAT/PROD boundary before any controlled runtime probe
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

Tenant metadata returned:

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

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
tests/evidence/2026-07-30-idocollections-idoinfo-properties.md
tests/evidence/2026-07-30-idocollections-slcoss-hierarchy.md
```

## Confirmed Customer Assembly Record

The standard **IDO Extension Class Assemblies** form shows:

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

Decision:

```text
- Customer.SLCos is backed by a binary-only assembly in this tenant.
- Source code is not exposed by this assembly record.
- The source-code discovery branch is closed.
- The exact CoAndLineInfoJson schema remains unconfirmed.
```

Evidence:

```text
tests/evidence/2026-07-30-customer-assembly-binary-only.md
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
```

## Immediate Next Step

Confirm only:

```text
1. Current environment: DEV, TEST, UAT, or PRODUCTION?
2. Is creation of a disposable test Customer Order allowed there?
```

Do not invoke `CreateCoAndLines` yet.

Decision branch:

```text
Non-production + disposable test allowed
→ design one controlled malformed/minimal invocation with pre/post verification

Production or disposable test not allowed
→ stop runtime probing and request an official method contract/sample from Infor or the solution owner
```

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
9. Do not invoke `CreateCoAndLines` until environment safety and controlled test conditions are confirmed.
10. Do not attempt to modify, rebuild, or reverse engineer the standard `Customer` binary assembly.

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
tests/evidence/2026-07-30-customer-assembly-binary-only.md
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
- SLCos_FT and ZIT_SLCos extend SLCos;
- assembly Customer is Binary Only, filename Customer, full name Customer Version 1.0.0.0, symbol file Customer.pdb;
- source code is not exposed in the tenant assembly record;
- the exact JSON schema and result contract remain unconfirmed;
- no standard business method has been executed;
- custom Process/Reprocess, Customer Order creation, controlled receive service, and final POS API are not complete.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Confirm whether the current environment is DEV, TEST, UAT, or PRODUCTION and whether a disposable test Customer Order may be created. Do not invoke CreateCoAndLines yet.
```
