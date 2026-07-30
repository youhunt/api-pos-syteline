# 17 — Current Status and New Chat Handoff

## Project

```text
Repository : youhunt/api-pos-syteline
Project    : Pizza Hut POS / SMK069 Sales Integration to Infor SyteLine Mongoose
Updated    : 30 July 2026
```

## Agreed Phase-1 Flow

```text
POS sample CSV
→ custom staging table
→ reusable validation
→ Error Processing form
→ supported Customer Order business process
→ co_mst + coitem_mst
```

The final POS payload/file structure is not available yet. The implementation remains incremental, but the final target is a controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is not stored in the staging table.

## Current Objects

```text
Metadata table        : SMK069_temp_sales_mst
Physical table        : dbo.ue_SMK069_temp_sales_mst
Entity IDO            : ue_SMK069TempSales
Error form            : ue_SMK069APISalesErrorProcessing
Validation procedure  : dbo.SMK069ValidateCustomerSp
Validation IDO method : ue_SMK069ValidateCustomerSp
Primary key           : SiteRef + co_num + co_line
```

Do not create a separate `site_ref`; standard `SiteRef` fulfills both the source requirement and Mongoose site context.

## Current Progress

```text
[COMPLETED] SMK069_temp_sales_mst and six process-control columns
[COMPLETED] ue_SMK069TempSales IDO and resynchronization
[COMPLETED] ue_SMK069APISalesErrorProcessing base form
[COMPLETED] form-opening smoke test
[COMPLETED] Preview controls and all four filter behaviors
[COMPLETED] process_status display mapping and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp created
[COMPLETED] ue_SMK069ValidateCustomerSp persisted as transactional standard method
[COMPLETED] generated parameter review: SiteRef, CoNum, Infobar
[COMPLETED] invalid customer test case: TEST000002 / TST0002 NOT FOUND
[COMPLETED] direct stored-procedure invalid-customer test
[COMPLETED] Mongoose IDO REST invalid-customer invocation test
[NEXT]      select one real DEFAULT-site customer for valid-customer testing
[NOT STARTED] valid-customer validation execution test
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] final REST API ingestion contract and Postman collection
```

## Verified Form Behavior

```text
Order Date only → filter by order_date
CO Number only  → filter by co_num
Both entered    → order_date AND co_num
Both blank      → validation message; no unrestricted staging load
```

`process_statusGridCol` List Source:

```text
INLINE ENTRIES(N\New,V\Valid,E\Error,P\Processed,C\Cancelled) DISPLAY(2) VALUE(1)
```

The grid displays descriptive values while the database stores `N`, `V`, `E`, `P`, or `C`. The Status cell is read-only.

## Customer Validation Object

Requirement:

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

Scope:

```text
SiteRef + co_num
```

Tenant configuration:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

Tenant naming rule:

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix is added automatically
```

Persisted parameters:

```text
1. SiteRef : VARIANT : input
2. CoNum   : VARIANT : input
3. Infobar : VARIANT : output
```

The procedure reads `customer_mst`, updates only `dbo.ue_SMK069_temp_sales_mst`, and does not update `co_mst` or `coitem_mst`.

## Invalid-Customer Evidence

Controlled case:

```text
SiteRef       : DEFAULT
co_num        : TEST000002
cust_num      : TST0002
CustomerCheck : NOT FOUND
```

Direct SQL execution:

```text
ReturnCode     : 0
Infobar        : Customer TST0002 tidak ditemukan di customer_mst.
process_status : E
validation_msg : Customer TST0002 tidak ditemukan di customer_mst.
```

Mongoose IDO REST response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    "Customer TST0002 tidak ditemukan di customer_mst."
  ],
  "ReturnValue": "0"
}
```

This proves that the method is callable through the Mongoose IDO REST layer and returns its output `Infobar` correctly.

Evidence file:

```text
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
```

## Immediate Next Step

Select one real customer from the same site before modifying staging data:

```sql
SELECT TOP (10)
    c.site_ref,
    c.cust_num,
    c.cust_seq,
    c.name
FROM dbo.customer_mst AS c
WHERE c.site_ref = N'DEFAULT'
  AND c.cust_seq = 0
ORDER BY c.cust_num;
```

Choose one returned `cust_num` for the controlled valid-customer test.

Do not update `TEST000001` or invoke the validation method during this same step.

## API Direction

```text
POS / Postman / sample CSV
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ reusable validation and Error Processing
→ supported Customer Order business process
→ co_mst + coitem_mst
```

The successful validation-method REST call is an important API-layer proof, but it is not the final external POS receive endpoint. Direct REST writes to the staging entity IDO are not the intended final architecture. Direct SQL insertion into standard Customer Order tables is prohibited.

## Development Rules

1. Work one small step at a time.
2. Adapt instructions to controls actually visible in tenant screenshots.
3. Distinguish metadata names from physical Cloud SQL names.
4. Custom IDO/form names use `ue_`; stored procedures do not manually use `ue_` in this tenant.
5. Never mark a step completed until tenant evidence confirms it.
6. Keep validation and processing reusable by form, CSV, and REST API paths.
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
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
CHANGELOG.md
```

## Ready-to-Paste Prompt for a New Chat

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Status saat ini:
- staging table, IDO, Error Processing form, Preview, dan process_status mapping selesai;
- dbo.SMK069ValidateCustomerSp selesai;
- ue_SMK069ValidateCustomerSp tersimpan sebagai transactional Stored Procedure Standard Method;
- parameter SiteRef, CoNum, Infobar terverifikasi;
- direct SQL invalid-customer test berhasil;
- IDO REST invalid-customer test berhasil dengan ReturnValue 0 dan output Infobar pada parameter ketiga;
- valid-customer test, Process, Customer Order creation, controlled service receive method, dan final API ingestion belum dimulai.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → standard Customer Order processing.

Langkah berikutnya hanya pilih satu customer nyata untuk SiteRef DEFAULT dari customer_mst. Jangan update staging atau invoke method pada langkah yang sama.
```
