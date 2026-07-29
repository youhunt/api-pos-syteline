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
[COMPLETED] blank-filter validation
[COMPLETED] CO Number-only Preview filtering
[COMPLETED] Order Date-only Preview filtering
[COMPLETED] combined Order Date AND CO Number filtering
[COMPLETED] process_status inline display mapping
[COMPLETED] process_status read-only verification
[NEXT]      customer validation against customer_mst
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

Evidence:

```text
tests/evidence/2026-07-29-smk069-process-status-display.md
```

## Immediate Next Step

Begin only the customer-validation implementation:

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

Validation scope:

```text
SiteRef + co_num
```

The validation must be reusable by the form, CSV import, REST API ingestion, and Process/Reprocess action. Do not implement customer lookup only inside a form event.

Detailed next guide:

```text
implementation/13-create-SMK069-customer-validation.md
```

The first small action is to open the tenant IDO method maintenance screen for:

```text
ue_SMK069TempSales
```

Show the available method implementation/type options before creating or saving a method. This prevents inventing an unsupported stored-procedure or extension-class pattern.

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
- Form ue_SMK069APISalesErrorProcessing selesai dan berhasil dibuka.
- Seluruh Preview behavior selesai diuji.
- process_status menampilkan New/Valid/Error/Processed/Cancelled tetapi menyimpan N/V/E/P/C.
- process_status sudah terkonfirmasi read-only.
- Process, Customer Order creation, controlled service IDO receive method, dan REST API ingestion belum dimulai.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → standard Customer Order processing.

Langkah berikutnya hanya customer validation:
cust_num harus ada di customer_mst.

Baca implementation/13-create-SMK069-customer-validation.md. Pertama, buka IDO method maintenance untuk ue_SMK069TempSales dan tampilkan opsi method type/implementation type yang tersedia. Jangan save method sebelum opsi tenant terlihat.
```
