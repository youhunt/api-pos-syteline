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
Planned form   : ue_SMK069APISalesErrorProcessing
Form caption   : SMK API SALES ERROR PROCESSING
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
[NOT STARTED] ue_SMK069APISalesErrorProcessing form
[NOT STARTED] Preview filters and event handlers
[NOT STARTED] customer validation
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import for SMK069
[NOT STARTED] final API technical document and Postman examples
```

## Immediate Next Step

Create only the base form:

```text
Form Name          : ue_SMK069APISalesErrorProcessing
Caption            : SMK API SALES ERROR PROCESSING
Form Type          : Grid Only
Primary Collection : ue_SMK069TempSales
Device Type        : Any
```

Do not create Preview or Process logic until the base form opens successfully.

Detailed guide:

```text
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
```

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
database/tables/SMK069_temp_sales_mst.md
implementation/11-create-SMK069-temp-sales-table.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
CHANGELOG.md
```

## Ready-to-Paste Prompt for a New Chat

```text
Anda adalah Senior Infor SyteLine/Mongoose Technical Consultant dan API Integration Developer.

Lanjutkan project private GitHub berikut sebagai source of truth:
https://github.com/youhunt/api-pos-syteline
Repository: youhunt/api-pos-syteline

Baca dahulu file berikut dari repository sebelum memberi instruksi:
1. docs/16-smk069-sales-spec-alignment.md
2. docs/17-current-status-and-new-chat-handoff.md
3. database/tables/SMK069_temp_sales_mst.md
4. implementation/11-create-SMK069-temp-sales-table.md
5. implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
6. CHANGELOG.md

Konteks project:
- Integrasi Pizza Hut POS ke Infor SyteLine/Mongoose.
- Tahap pertama memakai contoh file CSV karena format resmi POS belum tersedia.
- Data CSV masuk ke staging, divalidasi, kemudian diproses menjadi Customer Order header dan lines.
- Target standar SyteLine adalah co_mst dan coitem_mst, tetapi implementasi posting harus menggunakan business process/IDO yang sesuai, bukan direct SQL insert sembarangan.

Koreksi requirement yang sudah dikonfirmasi:
- Total header = SUM(unit_price * qty_ordered).
- Cost diambil dari item_mst.
- Kolom cost tidak dibuat pada temporary table.

Object yang sudah selesai:
- Metadata table: SMK069_temp_sales_mst
- Physical table: dbo.ue_SMK069_temp_sales_mst
- IDO: ue_SMK069TempSales
- IDO sudah di-update/resync dan properties otomatis sudah terbentuk.

Kolom kontrol yang sudah ada:
- process_status
- validation_msg
- error_msg
- retry_count
- processed_date
- processed_by

Primary key:
- SiteRef + co_num + co_line

Catatan penting:
- Jangan membuat site_ref terpisah; gunakan standard SiteRef.
- Prefix ue_ muncul pada physical table Cloud dan dipakai pada nama custom IDO/form di tenant ini.
- Form BELUM dibuat.

Langkah berikutnya hanya satu:
Bantu saya membuat base form Grid Only:
- Form Name: ue_SMK069APISalesErrorProcessing
- Caption: SMK API SALES ERROR PROCESSING
- Primary Collection: ue_SMK069TempSales

Kerjakan satu langkah kecil per respons. Jangan langsung membuat filter, Preview, Process, method, Customer Order, dan API sekaligus. Setelah saya menyatakan langkah berhasil atau mengirim screenshot, baru lanjut langkah berikutnya.

Setiap ada perubahan desain atau object yang selesai, update dokumentasi repository. Jangan menganggap sebuah langkah selesai hanya karena instruksi sudah diberikan.
```
