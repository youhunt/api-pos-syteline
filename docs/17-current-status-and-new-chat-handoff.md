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

The official POS payload/file format is not yet available. Development remains incremental, but the final target is a controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is not stored in the staging table.

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

Do not create a separate `site_ref`; standard `SiteRef` fulfills the source requirement and Mongoose site context.

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
[COMPLETED] first mandatory customer validation requirement
[CONFIRMED] standard Customer Order header IDO = SL.SLCos
[CONFIRMED] standard Customer Order line IDO = SL.SLCoitems
[REVIEWED]  SL.SLCos method-name list
[CONFIRMED] CreateCoAndLines = Extension Class - Standard Method, not Stored Procedure
[NEXT]      inspect CreateCoAndLines parameter rows
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
```

Parameters:

```text
1. SiteRef : input
2. CoNum   : input
3. Infobar : output
```

Verified branches:

```text
Invalid customer → process_status E + validation_msg
Valid customer   → process_status V + validation_msg NULL
```

Customer validation is fully completed and reusable by the form, CSV/import path, controlled API receive method, and Process/Reprocess action.

## Standard Customer Order Entity Discovery

### Header

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

### Lines

```text
Primary Collection : SL.SLCoitems
Collection          : SL.SLCoitems
Collection Name     : blank / not assigned
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

## SL.SLCos Method Discovery

The tenant method-name list was reviewed without modifying or executing any standard method.

Most relevant candidates:

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

Current assessment:

```text
CreateCoAndLines          : strongest combined header-and-line candidate
NewCustomerOrderValidSp   : validates a new order and may return default co_num
CreateCoColSp             : possible header/collection creation method
CoCustomerValidSp         : customer validation and default population
```

These are candidates only. The supported creation sequence is still not confirmed because parameter contracts have not been reviewed.

Evidence:

```text
tests/evidence/2026-07-30-slcoss-header-method-list.md
```

## Confirmed `CreateCoAndLines` Attributes

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : false / not enabled according to the method list
Stored Proc.  : not applicable
```

`CreateCoAndLines` is implemented in the standard `SL.SLCos` extension class. It is not a Stored Procedure method, so there is no Stored Procedure name to capture or configure.

The method's public parameter contract still needs to be inspected before deciding whether it is suitable for SMK069.

## Immediate Next Step

Stay on method:

```text
IDO         : SL.SLCos
Method Name : CreateCoAndLines
Method Type : Extension Class - Standard Method
```

Capture only its parameter metadata:

```text
Parameter Name
Sequence
User Data Type
Input/output direction, if visible
Custom Load Method Output Properties, if populated
```

Do not look for or supply a Stored Procedure name.

Do not edit, resync, save, or execute the standard method.

Do not inspect another method or `SL.SLCoitems` in the same step.

Do not create Process, Customer Orders, CSV import, or the controlled API receive method during this step.

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
2. Use tenant screenshots and actual options as the authority.
3. Distinguish metadata object names from physical SQL names.
4. Do not mark a step completed until tenant evidence confirms it.
5. Keep validation and processing reusable by form, CSV, and REST API paths.
6. Do not perform direct SQL insert into `co_mst` or `coitem_mst`.
7. Item mapping and broader item validation remain postponed.
8. Distinguish Stored Procedure methods from Extension Class methods; `CreateCoAndLines` is an Extension Class method.

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
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
tests/evidence/2026-07-30-slcoss-header-method-list.md
CHANGELOG.md
```

## Ready-to-Paste New-Chat Prompt

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Current status:
- staging table, IDO, Error Processing form, Preview, process_status mapping, and customer validation are complete;
- standard Customer Order header IDO is SL.SLCos;
- standard Customer Order line IDO is SL.SLCoitems;
- SL.SLCos method list has been reviewed;
- CreateCoAndLines is confirmed as Extension Class - Standard Method, not a Stored Procedure method;
- relevant candidates also include NewCustomerOrderValidSp, CreateCoColSp, and CoCustomerValidSp;
- no standard method has been modified or executed;
- custom Process/Reprocess, Customer Order creation, controlled service receive method, and final POS API are not complete.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Stay on SL.SLCos method CreateCoAndLines and provide its complete parameter rows: Parameter Name, Sequence, User Data Type, direction if visible, and output properties if populated. Do not look for a Stored Procedure because this is an Extension Class method. Do not modify, resync, save, or execute it, and do not inspect another method or SL.SLCoitems in the same step.
```