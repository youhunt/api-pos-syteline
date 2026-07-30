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

The official POS payload/file format is not yet available. The final target remains a controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
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
[COMPLETED] invalid-customer SQL and Mongoose REST tests
[COMPLETED] valid-customer Mongoose REST and persisted staging tests
[COMPLETED] mandatory customer validation requirement
[CONFIRMED] standard Customer Order header IDO = SL.SLCos
[CONFIRMED] standard Customer Order line IDO = SL.SLCoitems
[REVIEWED]  SL.SLCos method-name list
[CONFIRMED] CreateCoAndLines is Extension Class - Standard Method, not SP
[CONFIRMED] CoAndLineInfoJson = input-only
[CONFIRMED] CoResult = input/output + message parameter
[CONFIRMED] effective method contexts = SLCos, SLCos_FT, ZIT_SLCos
[NEXT]      inspect read-only IdoCollections property metadata
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

The method is reusable by the form, CSV/import path, controlled API receive method, and Process/Reprocess action.

## Standard Customer Order Entity Discovery

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

The earlier `SL.SLCustomers / oCustomers` screenshot belonged to the Customers form and is not a Customer Order IDO.

## SL.SLCos Method Discovery

Creation-related candidates:

```text
CreateCoAndLines
NewCustomerOrderValidSp
CreateCoColSp
CoCustomerValidSp
CoCustomerValid2Sp
CoCustSeqValidSp
VerifyCoCustNumSp
CoNextKeyDelSp
SumCoSp
```

`CreateCoAndLines` was selected first because its name explicitly references both header and lines.

Evidence:

```text
tests/evidence/2026-07-30-slcoss-header-method-list.md
```

## Confirmed CreateCoAndLines Contract Metadata

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

Parameter metadata:

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

## Method Metadata Route Discovery

The first metadata route failed:

```text
/IDORequestService/ido/info/IdoMethodParameters
→ HTTP 500 generic ASP.NET Runtime Error
```

REST v1 metadata routes succeeded and exposed the parameter direction flags plus method-level metadata.

Relevant `IdoMethods` properties:

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
MethodParameters
MethodResultSets
```

No direct `ExtensionClass`, `Assembly`, `SourceCode`, `HelpUrl`, or `JsonSchema` property was exposed.

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md
tests/evidence/2026-07-30-idomethods-idoinfo-properties.md
```

## Confirmed CreateCoAndLines Effective Method Rows

A filtered read-only load of `IdoMethods` returned three rows:

| CollectionName | BaseCollectionName | MethodType | TxnFlag | StoredProcName | MethodDesc | DerOutriggerProfile |
| --- | --- | ---: | ---: | --- | --- | --- |
| `SLCos` | `SLCos` | 2 | 0 | NULL | NULL | NULL |
| `SLCos` | `SLCos_FT` | 2 | 0 | NULL | NULL | NULL |
| `SLCos` | `ZIT_SLCos` | 2 | 0 | NULL | NULL | NULL |

All rows returned the same `_ItemId`. Current safe interpretation:

```text
- one effective method metadata record is represented across three collection/base contexts;
- the exact inheritance/extension relationship is not yet confirmed;
- do not assume which collection layer contains the extension-class implementation;
- the row data does not reveal the JSON schema.
```

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
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
- which collection layer contains the extension implementation
```

## Immediate Next Step

Perform only this read-only metadata request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoCollections
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete response or at least the returned property names.

Purpose:

```text
- determine whether collection metadata exposes base/inheritance information;
- look for extension-class, assembly, profile, or implementation-reference fields;
- prepare a later filtered load for SLCos, SLCos_FT, and ZIT_SLCos.
```

Do not invoke `CreateCoAndLines`, inspect another business method, create Process logic, create Customer Orders, import CSV, or create the receive API method during this step.

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
9. Treat collection hierarchy conclusions as pending until collection metadata confirms them.

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
tests/evidence/2026-07-30-create-co-and-lines-method-row.md
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
- the method row is represented with BaseCollectionName SLCos, SLCos_FT, and ZIT_SLCos using the same _ItemId;
- the exact JSON schema, collection hierarchy, and result contract remain unconfirmed;
- no standard business method has been executed;
- custom Process/Reprocess, Customer Order creation, controlled service receive method, and final POS API are not complete.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Call REST v1 IDOInfo for IdoCollections and provide its property names. Do not invoke CreateCoAndLines or create a Customer Order.
```
