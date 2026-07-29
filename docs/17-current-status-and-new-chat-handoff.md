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
```

Primary key:

```text
SiteRef + co_num + co_line
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
[DRAFTED]   dbo.ue_SMK069ValidateCustomerSp repository script
[NOT CREATED IN TENANT] customer validation stored procedure
[NOT CREATED] ValidateCustomer IDO method
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] REST API ingestion
[NOT STARTED] final API technical document and Postman examples
```

## Verified Form Behavior

Blank Preview message:

```text
Isi Order Date atau CO Number sebelum Preview.
```

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
IDO Name     : ue_SMK069TempSales
Method Type  : Stored Procedure - Standard Method
Stored Proc. : required existing stored procedure
Method Name  : required and unique
Transactional: available
```

Confirmed object names:

```text
Physical procedure : dbo.ue_SMK069ValidateCustomerSp
IDO method          : ValidateCustomer
Transactional       : Yes
```

Repository source:

```text
database/stored-procedures/ue_SMK069ValidateCustomerSp.sql
implementation/13-create-SMK069-customer-validation.md
```

The procedure reads `customer_mst` and updates only `dbo.ue_SMK069_temp_sales_mst`. It does not create or update Customer Orders.

## Immediate Next Step

Create only this stored procedure in the tenant application database:

```text
dbo.ue_SMK069ValidateCustomerSp
```

Then reopen the IDO Method Wizard and confirm the procedure appears in the Stored Procedure dropdown. Do not save the IDO method until its automatically generated parameters are visible and reviewed.

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
4. Custom IDO and form names in this tenant use `ue_`.
5. Do not mark work completed until tenant evidence confirms it.
6. Update repository documentation after completed objects or design corrections.
7. Keep customer validation and later processing reusable by both CSV and REST API paths.
8. Item mapping and broader item validation remain postponed.

## Repository Documents to Read First

```text
docs/16-smk069-sales-spec-alignment.md
docs/17-current-status-and-new-chat-handoff.md
database/tables/SMK069_temp_sales_mst.md
database/stored-procedures/ue_SMK069ValidateCustomerSp.sql
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
- Tenant mengonfirmasi method type Stored Procedure - Standard Method.
- Script dbo.ue_SMK069ValidateCustomerSp sudah tersedia di repository tetapi belum dibuat di tenant.
- IDO method ValidateCustomer belum dibuat.
- Process, Customer Order creation, controlled service IDO receive method, dan REST API ingestion belum dimulai.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → standard Customer Order processing.

Langkah berikutnya hanya membuat dbo.ue_SMK069ValidateCustomerSp dari database/stored-procedures/ue_SMK069ValidateCustomerSp.sql, lalu memastikan procedure muncul pada dropdown Stored Procedure di IDO Method Wizard. Jangan save method sebelum parameter hasil generate diperiksa.
```