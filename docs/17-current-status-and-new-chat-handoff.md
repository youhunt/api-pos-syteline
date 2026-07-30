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

The official POS payload/file format is not yet available. Development remains incremental, but the final target is still a controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is not stored in the staging table.

## Current Objects

```text
Metadata table                    : SMK069_temp_sales_mst
Physical table                    : dbo.ue_SMK069_temp_sales_mst
Entity IDO                        : ue_SMK069TempSales
Error form                        : ue_SMK069APISalesErrorProcessing
Validation procedure              : dbo.SMK069ValidateCustomerSp
Validation IDO method             : ue_SMK069ValidateCustomerSp
Standard Customer Order header IDO: SL.SLCos
Primary key                       : SiteRef + co_num + co_line
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
[IN PROGRESS] standard Customer Order line IDO/business-process discovery
[NOT STARTED] custom Process/Reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] final external REST API contract and Postman collection
```

## Verified Customer Validation

Method:

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

## Standard Customer Order Discovery

### Incorrect first attempt

```text
SL.SLCustomers / oCustomers
```

This belongs to the standard Customers form and is only the customer-master IDO.

### Confirmed header IDO

The correct standard Customer Orders form primary collection shows:

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

Decision:

```text
Standard Customer Order header IDO = SL.SLCos
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
```

The standard Customer Order line IDO is not yet confirmed.

## Immediate Next Step

Stay in the standard Customer Orders form Design Mode and identify only the secondary collection used for order lines.

Find the collection whose property list contains line-level fields such as:

```text
CoNum
CoLine
Item
QtyOrdered
UM
Price
DueDate
Whse
```

Capture a screenshot showing:

```text
Secondary Collection label
Collection / IDO name
Collection Name
several line-level properties
```

Do not modify or save the standard form.

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
CHANGELOG.md
```

## Ready-to-Paste New-Chat Prompt

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Current status:
- staging table, IDO, Error Processing form, Preview, process_status mapping, and customer validation are complete;
- standard Customer Order header IDO is confirmed as SL.SLCos from the correct Customer Orders form;
- Collection Name on the primary collection is blank/not assigned;
- standard line IDO, standard methods, custom Process/Reprocess, Customer Order creation, controlled service receive method, and final POS API are not complete.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Inspect secondary collections on the standard Customer Orders form and provide a screenshot of the collection containing CoNum, CoLine, Item, QtyOrdered, UM, Price, DueDate, or Whse. Do not modify the standard form or create Process logic yet.
```