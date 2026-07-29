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

The final POS CSV structure is not available yet. Development is intentionally incremental.

## Confirmed Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is therefore not part of the implemented staging table.

## Current Objects

```text
Metadata table : SMK069_temp_sales_mst
Physical table : dbo.ue_SMK069_temp_sales_mst
Entity IDO     : ue_SMK069TempSales
Form           : ue_SMK069APISalesErrorProcessing
Form caption   : SMK API SALES ERROR PROCESSING
Form status    : opens successfully; Preview verified
```

## Implemented Business Properties

```text
SiteRef
cust_num
order_date
terms_code
co_num
co_line
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
```

## Implemented Process-Control Properties

```text
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

Status values:

```text
N = New
V = Valid
E = Error
P = Processed
C = Cancelled
```

## Primary Key

```text
SiteRef + co_num + co_line
```

`SiteRef` is used for both the specification's `site_ref` requirement and Mongoose multi-site context. Do not add a second `site_ref` column.

## Actual Progress

```text
[COMPLETED] SMK069_temp_sales_mst created
[COMPLETED] cost removed from the implemented design
[COMPLETED] six process-control columns added
[COMPLETED] ue_SMK069TempSales IDO created
[COMPLETED] IDO updated/resynchronized; properties generated automatically
[COMPLETED] ue_SMK069APISalesErrorProcessing base form created
[COMPLETED] form opens successfully without metadata error
[COMPLETED] Order Date and CO Number controls displayed
[COMPLETED] Preview button displayed
[COMPLETED] blank-filter validation verified
[COMPLETED] controlled staging test data created
[COMPLETED] CO Number-only Preview filtering verified
[COMPLETED] Order Date-only Preview filtering verified
[COMPLETED] combined Order Date + CO Number Preview filtering verified
[IN PROGRESS] remaining form metadata and read-only verification
[NOT STARTED] customer validation
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import for SMK069
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] REST API ingestion
[NOT STARTED] final API technical document and Postman examples
```

## Tenant Evidence

The blank-filter test displays:

```text
Isi Order Date atau CO Number sebelum Preview.
```

Controlled test rows:

```text
TEST000001 | 2026-07-29 | line 1
TEST000001 | 2026-07-29 | line 2
TEST000002 | 2026-07-30 | line 1
```

Verified filtering evidence:

```text
CO Number TEST000001 + Order Date blank
→ returns TEST000001 line 1 and line 2 only

Order Date 7/30/2026 + CO Number blank
→ returns TEST000002 line 1 only

Order Date 7/30/2026 + CO Number TEST000001
→ returns no matching business rows
→ confirms order_date AND co_num
```

Still pending separate verification:

```text
- primary collection from form metadata
- all 20 required grid properties
- seven required read-only fields
```

## Immediate Next Step

Test only the `process_status` read-only setting:

```text
1. Load CO Number TEST000002
2. Click the Status cell containing N
3. Attempt to type E
4. Confirm the field cannot be edited and remains N
```

If it unexpectedly becomes editable, press `Esc`, do not save, and send a screenshot.

Do not add or test Process logic yet.

Detailed guide and implementation record:

```text
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
```

## API Direction

The project target remains an API integration, not only a form.

```text
POS / Postman / sample CSV
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ validation and Error Processing form
→ supported Customer Order business process
→ co_mst + coitem_mst
```

CSV import and REST API ingestion must reuse the same server-side processing core. Direct REST writes to the staging entity IDO are not the intended final architecture, and direct SQL insertion into standard Customer Order tables is prohibited.

## Development Rules

1. Work one small step at a time.
2. Do not combine table, IDO, form, method, and test work in one response.
3. Trust the user's SyteLine screenshots and adapt instructions to the available tenant controls.
4. Clearly distinguish metadata object names from physical SQL names.
5. Metadata table names do not manually include `ue_`; physical Cloud tables do.
6. Custom form and IDO names in this tenant use `ue_`.
7. IDO properties are generated automatically when the base table is added or the IDO is updated.
8. Update repository documentation after every completed object or material design correction.
9. Never mark a step completed merely because instructions were provided.
10. Item mapping and broad item validation remain postponed.

## Repository Documents to Read First

```text
docs/16-smk069-sales-spec-alignment.md
docs/17-current-status-and-new-chat-handoff.md
database/tables/SMK069_temp_sales_mst.md
implementation/11-create-SMK069-temp-sales-table.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
CHANGELOG.md
```

## Ready-to-Paste Prompt for a New Chat

```text
Anda adalah Senior Infor SyteLine/Mongoose Technical Consultant dan API Integration Developer.

Lanjutkan project private GitHub berikut sebagai source of truth:
Repository: youhunt/api-pos-syteline

Baca dahulu:
1. docs/16-smk069-sales-spec-alignment.md
2. docs/17-current-status-and-new-chat-handoff.md
3. database/tables/SMK069_temp_sales_mst.md
4. implementation/11-create-SMK069-temp-sales-table.md
5. implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
6. CHANGELOG.md

Status saat ini:
- Table SMK069_temp_sales_mst selesai.
- Physical table: dbo.ue_SMK069_temp_sales_mst.
- IDO ue_SMK069TempSales selesai dan sudah resync.
- Form ue_SMK069APISalesErrorProcessing berhasil dibuka.
- Seluruh perilaku Preview sudah berhasil diuji: blank, CO Number saja, Order Date saja, dan kombinasi AND.
- Controlled test rows TEST000001 dan TEST000002 tersedia.
- Read-only fields belum seluruhnya diuji.
- Process, customer validation, Customer Order creation, service IDO receive method, dan REST API ingestion belum dimulai.

Langkah berikutnya hanya satu:
Load TEST000002, lalu coba edit Status N menjadi E. Field harus read-only dan tetap N. Jangan save bila ternyata editable.

Target akhirnya tetap API:
POS/Postman/sample CSV → controlled service IDO → staging → validation → Customer Order standard process.

Kerjakan satu langkah kecil per respons dan update dokumentasi hanya setelah hasil tenant benar-benar terkonfirmasi.
```
