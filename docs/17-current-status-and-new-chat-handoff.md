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
[COMPLETED] invalid customer test case confirmed: TEST000002 / TST0002 NOT FOUND
[COMPLETED] direct stored-procedure invalid-customer logic test
[NEXT]      invoke ue_SMK069ValidateCustomerSp through Mongoose IDO REST layer
[NOT STARTED] valid-customer validation test
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

The grid displays `New`, `Valid`, `Error`, `Processed`, or `Cancelled`, while the database stores `N`, `V`, `E`, `P`, or `C`. The Status cell is read-only.

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

Controlled test case:

```text
SiteRef       : DEFAULT
co_num        : TEST000002
cust_num      : TST0002
CustomerCheck : NOT FOUND
```

Direct SQL execution result:

```text
ReturnCode     : 0
Infobar        : Customer TST0002 tidak ditemukan di customer_mst.
process_status : E
validation_msg : Customer TST0002 tidak ditemukan di customer_mst.
```

This proves the stored-procedure logic. It does not yet prove invocation through the IDO or REST layer.

## Immediate Next Step

Invoke the saved IDO method using the existing Mongoose API host and security token:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
Authorization: {{mongooseSecurityToken}}
```

Expected:

```text
ReturnValue = 0
Infobar     = Customer TST0002 tidak ditemukan di customer_mst.
```

Do not test a valid customer in the same step.

## API Direction

```text
POS / Postman / sample CSV
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ reusable validation and Error Processing
→ supported Customer Order business process
→ co_mst + coitem_mst
```

Direct REST writes to the staging entity IDO are not the intended final architecture. Direct SQL insertion into standard Customer Order tables is prohibited.

## Development Rules

1. Work one small step at a time.
2. Adapt instructions to the controls actually visible in tenant screenshots.
3. Distinguish metadata names from physical Cloud SQL names.
4. Custom IDO/form names use `ue_`; stored procedures follow the confirmed tenant rule without manually adding `ue_`.
5. Never mark a step completed until tenant evidence confirms it.
6. Keep validation and later processing reusable by form, CSV, and REST API paths.
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
- direct SQL invalid-customer test untuk DEFAULT + TEST000002 berhasil: ReturnCode 0, status E, validation_msg terisi;
- IDO/REST invocation test belum dilakukan;
- valid-customer test, Process, Customer Order creation, controlled service receive method, dan final API ingestion belum dimulai.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → standard Customer Order processing.

Langkah berikutnya hanya panggil ue_SMK069ValidateCustomerSp melalui Mongoose InvokeMethod REST API dengan parameter DEFAULT, TEST000002, dan output Infobar kosong. Jangan lanjut ke valid customer atau Process sebelum hasil IDO invocation terkonfirmasi.
```
