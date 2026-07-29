# 17 — Current Status and New Chat Handoff

## Project

```text
Repository : youhunt/api-pos-syteline
Project    : Pizza Hut POS / SMK069 Sales Integration to Infor SyteLine Mongoose
Date       : 29 July 2026
```

## Agreed Phase-1 Flow

```text
POS sample CSV
→ load into SMK069_temp_sales_mst
→ validate data
→ review through SMK API SALES ERROR PROCESSING
→ process Customer Order header and lines
→ standard SyteLine co_mst and coitem_mst
```

The final POS payload/file structure is not available yet. Development remains incremental, but the target is still a controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is not stored in the temporary table.

## Current Objects

```text
Metadata table : SMK069_temp_sales_mst
Physical table : dbo.ue_SMK069_temp_sales_mst
Entity IDO     : ue_SMK069TempSales
Form           : ue_SMK069APISalesErrorProcessing
Form caption   : SMK API SALES ERROR PROCESSING
Primary key    : SiteRef + co_num + co_line
```

Do not add a separate `site_ref`; standard `SiteRef` fulfills the requirement and Mongoose site context.

## Current Progress

```text
[COMPLETED] SMK069_temp_sales_mst
[COMPLETED] six process-control columns
[COMPLETED] ue_SMK069TempSales IDO and resynchronization
[COMPLETED] ue_SMK069APISalesErrorProcessing base form
[COMPLETED] form-opening smoke test
[COMPLETED] Order Date and CO Number Preview controls
[COMPLETED] all Preview filtering behaviors
[COMPLETED] process_status inline display mapping
[COMPLETED] process_status read-only verification
[CONFIRMED] customer validation method type: Stored Procedure - Standard Method
[COMPLETED] dbo.SMK069ValidateCustomerSp created and visible in the wizard
[CONFIRMED] generated IDO method name ue_SMK069ValidateCustomerSp
[COMPLETED] generated parameter review
[IN PROGRESS] save/persistence confirmation after reopening IDO Methods
[NOT STARTED] customer validation method execution test
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] REST API ingestion
[NOT STARTED] final API technical document and Postman examples
```

## Verified Form Behavior

Preview behavior:

```text
Order Date only → order_date
CO Number only  → co_num
Both entered    → order_date AND co_num
Both blank      → validation message; no unrestricted staging load
```

`process_statusGridCol` List Source:

```text
INLINE ENTRIES(N\New,V\Valid,E\Error,P\Processed,C\Cancelled) DISPLAY(2) VALUE(1)
```

Tenant verification confirms:

```text
N displays as New
Status cell cannot be manually edited
```

## Customer Validation Design

Validation requirement:

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

Validation scope:

```text
SiteRef + co_num
```

Confirmed tenant method configuration:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

## Confirmed Prefix Rule

The tenant naming behavior is:

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix is added automatically
```

Final confirmed object naming:

```text
Physical procedure : dbo.SMK069ValidateCustomerSp
IDO                  : ue_SMK069TempSales
IDO method            : ue_SMK069ValidateCustomerSp
Transactional         : Yes
```

Repository source:

```text
database/stored-procedures/SMK069ValidateCustomerSp.sql
implementation/13-create-SMK069-customer-validation.md
```

The procedure reads `customer_mst` and updates only `dbo.ue_SMK069_temp_sales_mst`. It does not create or update Customer Orders.

## Generated Parameter Evidence

Tenant-generated parameter grid:

```text
Sequence 1 : SiteRef : VARIANT
Sequence 2 : CoNum   : VARIANT
Sequence 3 : Infobar : VARIANT
```

Direction follows the stored procedure definition:

```text
SiteRef : input
CoNum   : input
Infobar : output
```

The visible tenant grid does not show separate direction, SQL type, or length columns. The Custom Load Method Output Properties area is blank, which is correct for a standard stored-procedure method.

## Immediate Next Step

Verify persistence only:

```text
1. Save the current IDO Methods record
2. Close IDO Methods
3. Reopen IDO Methods for ue_SMK069TempSales
4. Select ue_SMK069ValidateCustomerSp
5. Confirm Stored Procedure, Transactional, and all three parameters remain
```

Do not execute the validation method yet during this step.

## API Direction

```text
POS / Postman / sample CSV
→ controlled service IDO method
→ dbo.ue_SMK069_temp_sales_mst
→ reusable validation and Error Processing
→ supported Customer Order business process
→ co_mst + coitem_mst
```

Direct REST write to the staging entity IDO is not the intended final architecture. Direct SQL insertion into standard Customer Order tables is prohibited.

## Development Rules

1. Work one small step at a time.
2. Adapt instructions to the controls actually available in tenant screenshots.
3. Distinguish metadata names from physical Cloud SQL names.
4. Custom IDO and form names use `ue_`; stored procedures follow the confirmed tenant rule and do not manually use `ue_`.
5. Do not mark work completed until tenant evidence confirms it.
6. Update repository documentation after completed objects or design corrections.
7. Keep customer validation and later processing reusable by both CSV and REST API paths.
8. Item mapping and broader item validation remain postponed.

## Repository Documents to Read First

```text
docs/16-smk069-sales-spec-alignment.md
docs/17-current-status-and-new-chat-handoff.md
database/tables/SMK069_temp_sales_mst.md
database/stored-procedures/SMK069ValidateCustomerSp.sql
implementation/11-create-SMK069-temp-sales-table.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
implementation/13-create-SMK069-customer-validation.md
CHANGELOG.md
```

## Ready-to-Paste Prompt for a New Chat

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Status:
- SMK069_temp_sales_mst dan ue_SMK069TempSales selesai.
- Form ue_SMK069APISalesErrorProcessing dan seluruh Preview behavior selesai diuji.
- process_status display mapping dan read-only selesai.
- Stored procedure dbo.SMK069ValidateCustomerSp sudah dibuat dan muncul di wizard.
- IDO method otomatis bernama ue_SMK069ValidateCustomerSp dan Transactional dicentang.
- Parameter generated sudah terkonfirmasi: SiteRef sequence 1 VARIANT, CoNum sequence 2 VARIANT, Infobar sequence 3 VARIANT.
- Method belum dikonfirmasi tetap tersimpan setelah form IDO Methods ditutup dan dibuka ulang.
- Execution test, Process, Customer Order creation, controlled service IDO receive method, dan REST API ingestion belum dimulai.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → standard Customer Order processing.

Langkah berikutnya hanya save IDO Methods record, tutup, buka kembali, lalu pastikan ue_SMK069ValidateCustomerSp dan ketiga parameternya tetap ada. Jangan eksekusi method dahulu.
```
