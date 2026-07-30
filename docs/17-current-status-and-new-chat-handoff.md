# 17 — Current Status and New Chat Handoff

## Project

```text
Repository : youhunt/api-pos-syteline
Project    : Pizza Hut POS / SMK069 Sales Integration to Infor SyteLine Mongoose
Date       : 30 July 2026
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
Metadata table       : SMK069_temp_sales_mst
Physical table       : dbo.ue_SMK069_temp_sales_mst
Entity IDO           : ue_SMK069TempSales
Form                 : ue_SMK069APISalesErrorProcessing
Form caption         : SMK API SALES ERROR PROCESSING
Primary key          : SiteRef + co_num + co_line
Validation procedure : dbo.SMK069ValidateCustomerSp
Validation IDO method: ue_SMK069ValidateCustomerSp
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
[COMPLETED] dbo.SMK069ValidateCustomerSp created
[COMPLETED] ue_SMK069ValidateCustomerSp method persisted
[COMPLETED] generated method parameter review
[COMPLETED] TEST000002 / TST0002 confirmed absent from customer_mst
[NEXT]      execute invalid-customer validation logic once
[NOT STARTED] IDO-layer invalid-customer invocation test
[NOT STARTED] valid-customer validation test
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] REST API ingestion
[NOT STARTED] final API technical document and Postman examples
```

## Verified Form Behavior

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

## Customer Validation Object

Validation requirement:

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

Validation scope:

```text
SiteRef + co_num
```

Confirmed tenant configuration:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

Confirmed tenant prefix rule:

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix is added automatically
```

Generated and persisted parameters:

```text
1. SiteRef : VARIANT
2. CoNum   : VARIANT
3. Infobar : VARIANT
```

Direction follows the stored procedure definition:

```text
SiteRef : input
CoNum   : input
Infobar : output
```

The method remained available after the IDO Methods form was saved, closed, and reopened. This confirms the method metadata was persisted successfully.

Repository sources:

```text
database/stored-procedures/SMK069ValidateCustomerSp.sql
implementation/13-create-SMK069-customer-validation.md
```

The procedure reads `customer_mst` and updates only `dbo.ue_SMK069_temp_sales_mst`. It does not create or update Customer Orders.

## Invalid Customer Test Evidence

The controlled staging row was checked against `customer_mst`:

```text
SiteRef       : DEFAULT
co_num        : TEST000002
cust_num      : TST0002
CustomerCheck : NOT FOUND
```

This is the first invalid-customer test case.

## Immediate Next Step

Execute only the stored-procedure logic test:

```sql
DECLARE
    @ReturnCode int,
    @Infobar dbo.InfobarType;

EXEC @ReturnCode = dbo.SMK069ValidateCustomerSp
    @SiteRef = N'DEFAULT',
    @CoNum   = N'TEST000002',
    @Infobar = @Infobar OUTPUT;

SELECT
    @ReturnCode AS ReturnCode,
    @Infobar AS Infobar;

SELECT
    SiteRef,
    co_num,
    co_line,
    cust_num,
    process_status,
    validation_msg
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = N'DEFAULT'
  AND co_num = N'TEST000002'
ORDER BY co_line;
```

Expected:

```text
ReturnCode     = 0
process_status = E
validation_msg = Customer TST0002 tidak ditemukan di customer_mst.
```

This isolates the validation logic before testing the same method through the IDO/API layer.

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
- Staging table, IDO, Error Processing form, Preview, dan process_status mapping selesai.
- Stored procedure dbo.SMK069ValidateCustomerSp sudah dibuat.
- IDO method ue_SMK069ValidateCustomerSp sudah tersimpan, Transactional checked.
- Parameter method sudah terverifikasi: SiteRef, CoNum, Infobar.
- TEST000002 / TST0002 sudah dikonfirmasi NOT FOUND di customer_mst.
- Customer validation belum pernah dieksekusi.
- Process, Customer Order creation, controlled service IDO receive method, dan REST API ingestion belum dimulai.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → standard Customer Order processing.

Langkah berikutnya hanya menjalankan dbo.SMK069ValidateCustomerSp untuk DEFAULT + TEST000002 dan memeriksa ReturnCode, Infobar, process_status, serta validation_msg. Jangan lanjut ke IDO/API invocation atau Process sebelum hasil SQL logic test dikonfirmasi.
```
