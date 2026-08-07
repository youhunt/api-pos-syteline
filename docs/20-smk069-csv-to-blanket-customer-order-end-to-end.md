# SMK069 — End-to-End CSV sampai Blanket Customer Order

> **Source status:** Dokumen ini menjelaskan final behavior yang sudah diterapkan/ditetapkan di tenant. Pada saat commit dokumentasi ini, exact final source untuk parser, `SMK069ReceivePosSalesJsonSp`, dan `SMK069ProcessCustomerOrderSp` masih menunggu sinkronisasi dari tenant ke repository. `SMK069RunCsvTestBatchSp` versi Import & Validate Only sudah dikomit.

## Quick Navigation

```text
CSV contract                 : section 5
Upload and binary storage    : section 6
CSV parser                   : section 7
Import & Validate wrapper    : section 8
Raw inbound and mapping      : section 9
Full validation and U/M      : section 10
Transfer to temp staging     : section 11
Error Processing form        : section 12
Blanket CO processing        : section 13
co_mst mapping               : section 14
coitem_mst mapping           : section 15
co_bln_mst mapping           : section 16
Idempotency                  : section 17
Mongoose transaction safety  : section 18
Last UAT error cases         : section 19
API choreography             : section 20
End-to-end example           : section 21
Verification SQL             : section 22
Recovery/reprocess           : section 23
UAT checklist                : section 24
Deployment order             : section 25
Known gaps                   : section 26
Repository source status     : section 27
Acceptance definition        : section 28
```

## 1. Identitas Dokumen

| Item | Nilai |
|---|---|
| Project | API POS → Infor SyteLine / Mongoose |
| Scope | SMK069 Sales Integration |
| Dokumen | Alur lengkap CSV mentah sampai `co_mst`, `coitem_mst`, dan `co_bln_mst` |
| Target environment | Infor SyteLine Cloud / Mongoose |
| Status | Current implemented design per 6–7 Agustus 2026 |
| Processing model | Receive dan validasi dipisahkan dari pembuatan Customer Order |
| Final order type | Blanket Customer Order, `co_mst.type = 'B'` |

Dokumen ini menjadi referensi teknis utama untuk alur berikut:

```text
CSV mentah
→ Binary upload
→ Parsed CSV rows
→ Canonical JSON
→ Raw inbound
→ Normalization dan validation
→ Temporary sales staging
→ Process/Reprocess per source order
→ co_mst
→ coitem_mst
→ co_bln_mst
```

Dokumen ini juga mencatat koreksi terakhir yang ditemukan saat UAT:

1. Customer Order harus dibuat sebagai Blanket Order (`type = B`).
2. Setiap staging line harus masuk ke `coitem_mst` dan `co_bln_mst`.
3. `co_bln_mst.allow_on_pick_list` wajib diisi `0` karena kolom tenant bersifat `NOT NULL`.
4. U/M tidak cukup hanya terisi; U/M harus sama dengan base U/M item atau memiliki U/M Conversion yang berlaku.
5. Satu line U/M invalid membuat seluruh source order invalid.
6. Stored procedure harus aman ketika dipanggil di dalam transaksi Mongoose/IDO.
7. Nomor source/POS dan nomor Customer Order SyteLine harus dipisahkan dengan jelas.

---

## 2. Ringkasan Arsitektur Final

```text
┌───────────────────────────────────────────────────────────────┐
│ CSV FILE                                                      │
│ custnum, order_date, conum, coline, item, qty, price, U/M... │
└──────────────────────────────┬────────────────────────────────┘
                               │ Binary Value Action
                               v
┌───────────────────────────────────────────────────────────────┐
│ dbo.ue_SMK069_pos_csv_batch_mst                               │
│ Header batch + csv_file VARBINARY(MAX)                        │
└──────────────────────────────┬────────────────────────────────┘
                               │ SMK069ImportCsvFileSp
                               v
┌───────────────────────────────────────────────────────────────┐
│ dbo.ue_SMK069_pos_csv_upload_mst                              │
│ Satu row per CSV line + format validation                     │
└──────────────────────────────┬────────────────────────────────┘
                               │ SMK069RunCsvTestBatchSp
                               │ Build JSON + receive/validate only
                               v
┌───────────────────────────────────────────────────────────────┐
│ dbo.ue_SMK069_pos_sales_inbound_mst                           │
│ Raw JSON + canonical fields + validation status/message       │
└──────────────────────────────┬────────────────────────────────┘
                               │ Valid order only
                               v
┌───────────────────────────────────────────────────────────────┐
│ dbo.ue_SMK069_temp_sales_mst                                  │
│ Processing staging, process_status = V                        │
└──────────────────────────────┬────────────────────────────────┘
                               │ SMK069ProcessCustomerOrderSp
                               │ One call per SiteRef + SourceCoNum
              ┌────────────────┼────────────────┐
              v                v                v
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│ dbo.co_mst        │ │ dbo.coitem_mst    │ │ dbo.co_bln_mst    │
│ 1 Blanket header  │ │ N CO item lines   │ │ N blanket lines   │
│ type = B          │ │ generated CO num  │ │ generated CO num  │
└───────────────────┘ └───────────────────┘ └───────────────────┘
```

Prinsip utamanya:

```text
1 source order / POS co_num
→ 1 co_mst header
→ N coitem_mst rows
→ N co_bln_mst rows
```

---

## 3. Perbedaan Nomor yang Wajib Dipahami

Ada tiga identitas berbeda yang tidak boleh dicampur.

### 3.1 Batch ID

Contoh:

```text
CSV-20260806-165400-A1B2C3
```

Fungsi:

- mengidentifikasi satu pengiriman CSV atau JSON;
- menjadi idempotency key pada Receive API;
- menghubungkan CSV header, CSV detail, dan inbound rows;
- bukan nomor Customer Order.

### 3.2 Source Order Number / POS Order Number

Contoh:

```text
CS26080001
```

Lokasi penyimpanan:

```text
CSV             : conum
CSV detail      : conum
Inbound         : co_num
Temp staging    : co_num
co_mst          : cust_po
```

`SMK069_temp_sales_mst.co_num` tetap menyimpan nomor source/POS. Kolom ini tidak ditimpa oleh nomor SyteLine.

### 3.3 Generated SyteLine Customer Order Number

Contoh:

```text
CO26080017
```

Lokasi penyimpanan:

```text
co_mst.co_num
coitem_mst.co_num
co_bln_mst.co_num
SMK069_temp_sales_mst.created_co_num
```

Aturan final:

```text
staging.co_num         = source/POS order number
co_mst.cust_po         = source/POS order number
@CreatedCoNum          = generated SyteLine CO number
coitem_mst.co_num      = @CreatedCoNum
co_bln_mst.co_num      = @CreatedCoNum
staging.created_co_num = @CreatedCoNum
```

Kesalahan yang harus dihindari:

```text
JANGAN: co_bln_mst.co_num = staging.co_num
BENAR : co_bln_mst.co_num = @CreatedCoNum
```

---

## 4. Objek yang Terlibat

### 4.1 Form

| Form | Fungsi |
|---|---|
| `SMK POS CSV TEST CONSOLE` | Membuat batch, upload CSV, parse CSV, dan menjalankan Import & Validate |
| `SMK API SALES ERROR PROCESSING` | Menampilkan staging, melihat validasi/error, dan menjalankan Process/Reprocess |

### 4.2 IDO

| IDO | Fungsi |
|---|---|
| `ue_SMK069PosCsvBatch` | Header batch dan binary CSV |
| `ue_SMK069PosCsvUpload` | Detail hasil parsing CSV |
| `ue_SMK069TempSales` | Temporary sales staging dan Process/Reprocess |

### 4.3 Custom Tables

| Physical table | Fungsi |
|---|---|
| `dbo.ue_SMK069_pos_csv_batch_mst` | Header batch dan `csv_file` |
| `dbo.ue_SMK069_pos_csv_upload_mst` | Detail parsed CSV |
| `dbo.ue_SMK069_pos_sales_inbound_mst` | Raw inbound, canonical fields, validation result |
| `dbo.ue_SMK069_pos_field_map_mst` | Mapping field eksternal ke canonical field |
| `dbo.ue_SMK069_temp_sales_mst` | Processing staging sebelum Customer Order |

### 4.4 Standard SyteLine Tables

| Table | Fungsi pada flow ini |
|---|---|
| `dbo.customer_mst` | Customer, terms, tax, contact, phone, dan related defaults |
| `dbo.customer_currency_mst` | Default currency customer |
| `dbo.item_mst` | Item, description, base U/M, unit cost, material cost |
| `dbo.u_m_conv_mst` | Validasi keberadaan U/M conversion |
| `dbo.whse_mst` | Validasi warehouse |
| `dbo.co_mst` | Blanket Customer Order header |
| `dbo.coitem_mst` | Customer Order item lines |
| `dbo.co_bln_mst` | Blanket Order lines |

### 4.5 Stored Procedures

| Procedure | Tanggung jawab |
|---|---|
| `dbo.SMK069InitializeCsvTestBatchSp` | Membuat batch baru |
| `dbo.SMK069ImportCsvFileSp` | Membaca BLOB CSV dan membangun CSV detail rows |
| `dbo.SMK069RunCsvTestBatchSp` | Membentuk JSON dan menjalankan Receive + Validate saja |
| `dbo.SMK069ReceivePosSalesJsonSp` | Raw inbound, mapping, normalization, validation, transfer ke temp |
| `dbo.SMK069ProcessCustomerOrderSp` | Membuat Blanket CO header, CO item lines, dan blanket lines |

---

## 5. Kontrak CSV

### 5.1 Canonical Headers dan Alias

| Canonical field | Header/alias yang diterima |
|---|---|
| `custnum` | `custnum`, `cust_num`, `customer`, `customer_code` |
| `order_date` | `order_date`, `orderdate` |
| `conum` | `conum`, `co_num`, `order_no`, `order_number` |
| `coline` | `coline`, `co_line`, `line_no`, `line_number` |
| `item` | `item`, `item_code`, `sku` |
| `qty_ordered` | `qty_ordered`, `qty`, `quantity` |
| `unit_price` | `unit_price`, `unitprice`, `price` |
| `siteref` | `siteref`, `site_ref`, `site` |
| `whse` | `whse`, `warehouse` |
| `due_date` | `due_date`, `duedate` |
| `u_m` | `u_m`, `um`, `unit_of_measure` |
| `terms_code` | `terms_code`, `terms` |
| `tax_code1` | `tax_code1`, `tax_code` |
| `exch_rate` | `exch_rate`, `exchange_rate` |

### 5.2 Required CSV Fields

Parser mewajibkan:

```text
custnum
order_date
conum
coline
item
qty_ordered
```

Field lain bersifat opsional dan dapat memperoleh default pada tahap Receive.

### 5.3 Contoh CSV

```csv
custnum,order_date,conum,coline,item,qty_ordered,unit_price,siteref,whse,due_date,u_m,terms_code,tax_code1,exch_rate
C000001,2026-08-13,CS26080001,1,AA00005,100,300000,DEFAULT,MAIN,2026-09-06,KG,CBD,PPN11%,1
C000001,2026-08-13,CS26080001,2,AA00007,50,150000,DEFAULT,MAIN,2026-09-06,KG,CBD,PPN11%,1
```

### 5.4 Width Constraints Final Tenant

```text
custnum : maksimum 7 karakter
conum   : maksimum 10 karakter
item    : maksimum 30 karakter
```

Receive SP final tenant juga mengecek batas yang sama. Exact final parser source untuk check ini masih pending repository sync.

### 5.5 Batas Physical Staging Lain yang Perlu Dijaga

Berdasarkan table staging:

```text
SiteRef    : 8
whse       : 4
u_m        : 3
terms_code : 3
tax_code1  : 6
```

Catatan hardening: panjang field ini perlu selalu disesuaikan dengan metadata tenant. Parser/Receive saat ini belum memberikan message panjang khusus untuk seluruh field tersebut, sehingga kontrak payload harus membatasi nilainya sesuai physical table.

### 5.6 Kemampuan Parser

Didukung:

- CSV comma-delimited;
- quoted value;
- escaped double quote `""`;
- UTF-16 little-endian;
- UTF-8 dengan BOM;
- ANSI/ASCII-compatible content;
- beberapa format tanggal menggunakan `TRY_CONVERT`.

Tidak didukung:

- embedded line break di dalam quoted field;
- file spreadsheet `.xlsx` langsung;
- CSV dengan delimiter selain comma tanpa perubahan parser.

---

## 6. Stage A — New Batch dan Binary Upload

### 6.1 New Batch

`New Batch` membuat record baru pada:

```text
dbo.ue_SMK069_pos_csv_batch_mst
```

Minimum state:

```text
batch_id      = generated unique batch ID
source_system = POS
batch_status  = D / Draft
csv_file      = NULL sebelum upload
```

### 6.2 Upload CSV

Binary Value Action membaca file dari browser dan mengisikan binary ke property `CsvFile`, yang terikat ke:

```text
dbo.ue_SMK069_pos_csv_batch_mst.csv_file
```

Binary content tidak menyimpan original filename sebagai metadata yang dapat diambil otomatis. Karena original filename tidak membantu proses bisnis, final UI decision adalah menyembunyikan field File Name.

### 6.3 Event Sequence Final yang Disarankan

```text
SMK069UploadCsv
├─ 0  Binary Value Action — Import ke CsvFile
├─ 10 Collection Save — Primary Collection
├─ 20 Generate Event / Call Parse CSV
├─ 30 Collection Refresh — Primary
└─ 40 Collection Refresh — Secondary/detail
```

Jika tenant masih memiliki tombol `Parse CSV to Rows`, tombol tersebut dapat dipertahankan sebagai `Re-parse CSV` untuk recovery. Namun indikator utama keberhasilan upload adalah detail row langsung muncul, bukan nama file.

### 6.4 Bukti File Berhasil Diterima

Bukti yang digunakan:

```text
csv_file tidak NULL
file_size = DATALENGTH(csv_file)
uploaded_date terisi
parsed detail rows muncul
result_message menunjukkan jumlah row dan format error
```

Original filename bukan bukti utama dan tidak diperlukan pada UI operasional.

---

## 7. Stage B — Parse CSV ke Detail Rows

Procedure:

```text
dbo.SMK069ImportCsvFileSp
```

Contract:

```text
@BatchId      INPUT
@RequestedBy  INPUT
@ImportedRows OUTPUT
@ErrorRows    OUTPUT
@Infobar      OUTPUT
```

### 7.1 Input

Procedure membaca:

```text
dbo.ue_SMK069_pos_csv_batch_mst.csv_file
```

### 7.2 Parsing Process

```text
1. Load BLOB
2. Decode encoding
3. Normalize CR/LF
4. Baca header
5. Canonicalize aliases
6. Baca setiap CSV row
7. Convert tanggal/angka
8. Validate required fields dan basic format
9. Rebuild detail table
10. Update batch result
```

### 7.3 Parser Validation

Contoh error final tenant:

```text
custnum kosong
order_date kosong / tidak valid
conum kosong
coline kosong / harus bilangan > 0
item kosong
qty_ordered kosong / harus angka > 0
unit_price tidak valid / negatif
due_date tidak valid
exch_rate harus > 0
custnum melebihi 7 karakter
conum melebihi 10 karakter
item melebihi 30 karakter
```

### 7.4 Output Table

```text
dbo.ue_SMK069_pos_csv_upload_mst
```

Satu CSV row menjadi satu table row.

### 7.5 CSV Detail Status

| Status | Arti |
|---|---|
| `N` | Parsed, belum Import & Validate |
| `E` | Format/basic parser error |
| `S` | Import & Validate berhasil untuk batch |

### 7.6 CSV Batch Status

| Status | Arti |
|---|---|
| `D` | Draft / parsed dan siap divalidasi |
| `R` | Running / sedang Import & Validate |
| `E` | Error |
| `C` | Completed untuk receive/validation stage |

`Completed` pada CSV batch tidak berarti Customer Order sudah dibuat. Dalam final design, batch selesai pada tahap import/validation, sedangkan CO dibuat terpisah dari Error Processing form atau Process API.

---

## 8. Stage C — Build Canonical JSON dan Import & Validate

Procedure wrapper:

```text
dbo.SMK069RunCsvTestBatchSp
```

Final behavior:

```text
CSV detail
→ build canonical JSON
→ call SMK069ReceivePosSalesJsonSp
→ transfer valid order ke temp
→ STOP
```

Procedure ini tidak memanggil pembuatan Customer Order.

### 8.1 Alasan Receive dan Process Dipisah

- pengguna dapat melihat dan memperbaiki error sebelum posting;
- invalid data tidak menyentuh standard CO tables;
- Process/Reprocess dapat dijalankan per source order;
- API dapat mengatur retry per order;
- error dan validation lebih mudah dilacak;
- satu batch dapat memiliki order valid dan invalid tanpa partial line posting.

### 8.2 Source System Normalization

CSV Console label seperti:

```text
POS-CSV-TEST
POS_CSV_TEST
CSV-TEST
CSV_TEST
```

dinormalisasi menjadi:

```text
POS
```

karena field mapping aktif berada pada namespace `POS`.

### 8.3 JSON yang Dibentuk

```json
[
  {
    "custnum": "C000001",
    "order_date": "2026-08-13",
    "conum": "CS26080001",
    "coline": 1,
    "item": "AA00005",
    "qty_ordered": 100.00000000,
    "unit_price": 300000.00000000,
    "siteref": "DEFAULT",
    "whse": "MAIN",
    "due_date": "2026-09-06",
    "u_m": "KG",
    "terms_code": "CBD",
    "tax_code1": "PPN11%",
    "exch_rate": 1.00000000
  }
]
```

### 8.4 Output Wrapper

```text
ReceivedRows
TotalOrders
ValidationValidOrders
ValidationErrorOrders
TransferredRows
ProcessedOrders       = 0
ProcessErrorOrders    = 0
Infobar
```

`ProcessedOrders` dan `ProcessErrorOrders` dipertahankan hanya untuk kompatibilitas IDO method lama dan selalu `0` pada versi Import & Validate Only.

---

## 9. Stage D — Receive, Preserve Raw Data, Mapping, dan Normalization

Procedure:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

### 9.1 Contract

```text
@SourceSystem    INPUT
@BatchId         INPUT
@PayloadJson     INPUT
@ReceivedBy      INPUT
@ReceivedRows    OUTPUT
@TotalOrders     OUTPUT
@ValidOrders     OUTPUT
@ErrorOrders     OUTPUT
@TransferredRows OUTPUT
@Infobar         OUTPUT
```

### 9.2 Batch Idempotency

Key:

```text
source_system + batch_id
```

Jika batch sudah pernah diterima:

```text
- procedure tidak memasukkan ulang data;
- existing counts dibaca kembali;
- Infobar menyatakan batch sudah pernah diterima;
- return code 0.
```

BatchId tidak boleh digunakan ulang untuk payload yang berubah.

### 9.3 Preserve Raw JSON

Setiap JSON object disimpan pada:

```text
dbo.ue_SMK069_pos_sales_inbound_mst.raw_json
```

Initial status:

```text
R = Received/raw
```

Tujuan:

- audit trail;
- troubleshooting mapping;
- membandingkan source dan canonical values;
- tidak kehilangan source data ketika validation gagal.

### 9.4 Dynamic Field Mapping

Mapping dibaca dari:

```text
dbo.ue_SMK069_pos_field_map_mst
```

Matching mempertimbangkan:

```text
source_system
source_field
is_active
priority_no
```

Jika beberapa source aliases mengarah ke target yang sama, nilai dengan mapping priority tertinggi dipilih.

### 9.5 Canonical Fields

```text
SiteRef
cust_num
order_date
co_num
co_line
item
qty_ordered
unit_price
whse
due_date
u_m
terms_code
tax_code1
exch_rate
```

### 9.6 Defaults dan Master Data Enrichment

| Canonical field | Default/fallback |
|---|---|
| `SiteRef` | `DEFAULT` jika tidak dikirim |
| `whse` | `MAIN` jika tidak dikirim |
| `due_date` | `order_date` jika tidak dikirim |
| `unit_price` | `0` jika tidak dapat dikonversi/blank pada normalization |
| `exch_rate` | `1` jika tidak dikirim |
| `u_m` | `item_mst.u_m` jika payload kosong |
| `terms_code` | `customer_mst.terms_code` jika payload kosong |
| `tax_code1` | `customer_mst.tax_code1` jika payload kosong |
| `cust_seq` | Current implementation menggunakan `0` |

Defaults bukan pengganti validasi. Setelah enrichment, semua canonical data tetap melewati validation.

---

## 10. Stage E — Validation Lengkap

### 10.1 Row-Level Validation

Satu inbound row menjadi Error jika salah satu kondisi berikut terjadi:

```text
cust_num kosong
cust_num > 7 karakter
order_date kosong atau invalid
co_num kosong
co_num > 10 karakter
co_line <= 0
item kosong
item > 30 karakter
qty_ordered <= 0
unit_price < 0
exch_rate <= 0
customer tidak ditemukan untuk SiteRef + cust_num + cust_seq 0
item tidak ditemukan untuk SiteRef + item
warehouse tidak ditemukan untuk SiteRef + whse
u_m kosong setelah fallback
u_m tidak sama dengan base U/M item dan tidak memiliki conversion
```

### 10.2 U/M Validation Rule

Final rule:

```text
1. Payload U/M kosong
   → fallback item_mst.u_m

2. Payload/final U/M = item_mst.u_m
   → Valid

3. U/M berbeda dari item_mst.u_m
   → Harus ada U/M Conversion yang berlaku

4. Tidak ada conversion
   → Error
```

Contoh error:

```text
u_m GR tidak valid untuk item AA00005;
base u_m item adalah KG dan U/M Conversion tidak ditemukan
```

### 10.3 U/M Conversion Scope

Receive SP menormalisasi data dari:

```text
dbo.u_m_conv_mst
```

Conversion diterima untuk scope:

```text
G = Global
I = Item
C = Customer
```

Conversion vendor dikecualikan:

```text
V = Vendor → tidak berlaku untuk Customer Order
```

Matching conversion memperbolehkan pasangan dua arah:

```text
base → transaction U/M
atau
transaction U/M → base
```

Site-specific conversion diterima jika site sama. Conversion dengan site kosong juga dapat berlaku.

### 10.4 Runtime Metadata Discovery pada `u_m_conv_mst`

Nama physical column dapat berbeda antar tenant/version. Procedure mendeteksi common names:

```text
from_u_m atau base_u_m
to_u_m, conv_u_m, atau converted_u_m
site_ref
type atau conv_type
item
cust_num, vend_num, atau cust_vend_num
```

Data kemudian dimasukkan ke normalized temp table `#UMConversion` agar stored procedure tidak gagal compile hanya karena optional column berbeda.

Jika base/from atau converted/to column tidak dapat ditemukan, Receive gagal dengan error yang jelas.

### 10.5 Important Limitation: Conversion Factor

Current U/M validation memastikan conversion record ada. Current Process SP masih menyalin:

```text
qty_ordered_conv  = qty_ordered
blanket_qty_conv = qty_ordered
price_conv        = unit_price
cont_price_conv   = unit_price
```

Artinya faktor conversion belum digunakan untuk menghitung converted quantity/price. Untuk U/M conversion dengan factor bukan `1`, behavior ini wajib dikonfirmasi secara fungsional dan dibandingkan dengan standard SyteLine processing.

### 10.6 Duplicate Line Validation

Duplicate key dalam batch:

```text
SiteRef + co_num + co_line
```

Semua duplicate lines menjadi Error dengan pesan:

```text
duplicate co_line dalam co_num yang sama
```

### 10.7 Header Consistency Validation

Dalam satu source order, field header harus konsisten:

```text
cust_num
order_date
whse
terms_code
tax_code1
```

Jika tidak konsisten:

```text
nilai header tidak konsisten dalam satu co_num
```

### 10.8 Atomic Order Rule

Satu order dianggap satu unit atomik.

```text
Jika satu line Error
→ semua line pada SiteRef + co_num menjadi Error
→ tidak ada partial order masuk temp
```

Line lain yang secara individual valid diberi pesan:

```text
Order memiliki line lain yang gagal validasi.
```

### 10.9 Existing Order di Temp

Receive menolak source order yang sudah ada pada:

```text
dbo.ue_SMK069_temp_sales_mst
```

Pesan:

```text
co_num sudah terdapat pada processing temp;
gunakan co_num baru atau periksa batch sebelumnya.
```

Tujuannya mencegah batch baru menimpa order yang sedang atau sudah diproses.

---

## 11. Inbound Status dan Transfer ke Temp

### 11.1 Inbound Status

| Status | Arti |
|---|---|
| `R` | Raw row received |
| `V` | Canonical row valid dan siap transfer |
| `E` | Validation error |
| `T` | Transferred ke temp staging |

### 11.2 Transfer Rule

Hanya row berstatus `V` yang dimasukkan ke:

```text
dbo.ue_SMK069_temp_sales_mst
```

Setelah transfer:

```text
inbound_status = T
transferred_date = GETDATE()
temp.process_status = V
```

### 11.3 Temp Staging Fields

```text
SiteRef
cust_num
order_date
terms_code
co_num                -- source/POS order
co_line
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
created_co_num         -- generated SyteLine CO after process
```

---

## 12. Stage F — Error Processing Form

Form:

```text
SMK API SALES ERROR PROCESSING
```

Primary collection:

```text
ue_SMK069TempSales
```

### 12.1 Tujuan

- menampilkan order yang sudah melewati Receive;
- mencari berdasarkan order date atau source CO number;
- melihat validation/error message;
- menjalankan Process/Reprocess per source order;
- menampilkan generated SyteLine CO number dari `created_co_num`.

### 12.2 Kolom Penting

```text
Site
Order Date
SyteLine CO Number       ← created_co_num
Source/POS CO Number     ← co_num
Line
Customer
Item
Quantity
U/M
Unit Price
Warehouse
Due Date
Terms
Tax Code
Exchange Rate
Status
Validation Message
Error Message
```

### 12.3 Status Temp

| Status | Arti |
|---|---|
| `N` | New/manual staging belum divalidasi |
| `V` | Valid, siap diproses |
| `E` | Processing/validation error |
| `P` | Processed, CO berhasil atau existing CO tersinkronisasi |
| `C` | Cancelled |

### 12.4 Tombol Process/Reprocess

Process dipanggil sekali untuk satu:

```text
SiteRef + SourceCoNum
```

Bukan sekali per line.

Jika source order memiliki lima line:

```text
1 method call
→ 1 co_mst
→ 5 coitem_mst
→ 5 co_bln_mst
```

---

## 13. Stage G — Create Blanket Customer Order

Procedure:

```text
dbo.SMK069ProcessCustomerOrderSp
```

### 13.1 Contract

```text
@SiteRef       INPUT
@SourceCoNum   INPUT
@CustSeq       INPUT, default 0
@ProcessedBy   INPUT
@CreatedCoNum  OUTPUT
@Success       OUTPUT
@Infobar       OUTPUT
```

### 13.2 Pre-Processing Validation

Procedure memvalidasi:

```text
SiteRef wajib
SourceCoNum wajib
staging order ada
status bukan Cancelled
line count > 0
semua line memiliki customer
satu order hanya memiliki satu customer
order_date ada dan konsisten
warehouse ada dan konsisten
item terisi
qty_ordered > 0
unit_price tidak negatif
terms_code konsisten
tax_code1 konsisten
customer + cust_seq ada
warehouse ada
default customer currency ada
semua item ada
u_m tidak kosong setelah fallback item_mst.u_m
```

Important: conversion validity utama dilakukan pada Receive. Direct/manual insert ke temp tidak boleh melewati Receive atau controlled validation, karena Process SP current hanya memastikan U/M tidak kosong.

### 13.3 Header Totals

```text
Header material cost = SUM(item_mst.matl_cost × qty_ordered)
Header cost          = SUM(item_mst.unit_cost × qty_ordered)
Header price         = SUM(unit_price × qty_ordered)
```

### 13.4 Customer Order Number Generation

Pattern:

```text
COYYMM####
```

Contoh order date Agustus 2026:

```text
CO26080017
```

Concurrency protection menggunakan:

```text
sys.sp_getapplock
resource = SMK069_CO_NUM|<SiteRef>|<Prefix>
lock mode = Exclusive
lock owner = Transaction
```

Setelah lock diperoleh, procedure mencari maximum suffix dan menambah `1`.

---

## 14. Mapping Temp ke `co_mst`

Final order type:

```text
co_mst.type = B
```

| `co_mst` field | Sumber/nilai |
|---|---|
| `co_num` | `@CreatedCoNum` |
| `type` | `'B'` |
| `cust_num` | staging `cust_num` |
| `cust_po` | `@SourceCoNum` / source POS order |
| `cust_seq` | `@CustSeq`, default `0` |
| `whse` | staging `whse` |
| `order_date` | staging `order_date` |
| `curr_code` | default `customer_currency_mst.curr_code` |
| `site_ref` | `@SiteRef` |
| `contact` | `customer_mst.contact##1` |
| `phone` | `customer_mst.phone##1` |
| `terms_code` | staging jika ada, fallback customer |
| `tax_code1` | staging jika ada, fallback customer |
| `end_user_type` | `customer_mst.end_user_type` |
| `orig_site` | `@SiteRef` |
| `include_tax_in_price` | customer default |
| `cost` | calculated header cost |
| `matl_cost_t` | calculated header material cost |
| `price` | `SUM(unit_price × qty_ordered)` |

Field lain yang tidak dimasukkan menggunakan standard table default/trigger behavior pada tenant.

---

## 15. Mapping Temp ke `coitem_mst`

Satu temp line menghasilkan satu `coitem_mst` row.

| `coitem_mst` field | Sumber/nilai |
|---|---|
| `co_num` | `@CreatedCoNum` |
| `co_line` | staging `co_line` |
| `item` | staging `item` |
| `qty_ordered` | staging `qty_ordered` |
| `u_m` | staging `u_m`, fallback `item_mst.u_m` |
| `due_date` | staging `due_date`, fallback order date |
| `price` | staging `unit_price` |
| `site_ref` | `@SiteRef` |
| `whse` | header/staging warehouse |
| `qty_ordered_conv` | staging `qty_ordered` |
| `cust_seq` | `@CustSeq` |
| `co_cust_num` | header customer |
| `ship_site` | `@SiteRef` |
| `co_orig_site` | `@SiteRef` |
| `description` | `item_mst.description` |
| `cost` | `item_mst.unit_cost` |
| `cgs_total` | `item_mst.unit_cost` |
| `price_conv` | staging `unit_price` |
| `matl_cost` | `item_mst.matl_cost` |
| `cost_conv` | `item_mst.unit_cost` |
| `matl_cost_conv` | `item_mst.matl_cost` |

Procedure memastikan jumlah inserted rows sama dengan staging line count. Jika berbeda, seluruh transaksi gagal.

---

## 16. Mapping Temp ke `co_bln_mst`

Satu temp line menghasilkan satu `co_bln_mst` row.

| `co_bln_mst` field | Contoh | Sumber/nilai |
|---|---:|---|
| `site_ref` | `DEFAULT` | staging `SiteRef` |
| `co_num` | `CO26080017` | `@CreatedCoNum` |
| `co_line` | `1` | staging `co_line` |
| `item` | `AA00144` | staging `item` |
| `cust_item` | `NULL` | `NULL` |
| `feat_str` | `NULL` | `NULL` |
| `blanket_qty` | `56.00000000` | staging `qty_ordered` |
| `eff_date` | `NULL` | `NULL` |
| `exp_date` | `NULL` | `NULL` |
| `cont_price` | `400.00000000` | staging `unit_price` |
| `stat` | `O` | default dibuat `'O'` |
| `promise_date` | `NULL` | `NULL` |
| `pricecode` | `NULL` | `NULL` |
| `u_m` | `GR` | staging `u_m`, fallback `item_mst.u_m` |
| `blanket_qty_conv` | `56.00000000` | staging `qty_ordered` |
| `cont_price_conv` | `400.00000000` | staging `unit_price` |
| `ship_site` | `DEFAULT` | staging `SiteRef` |
| `description` | `Beef FQ 85 CL` | `item_mst.description` |
| `config_id` | `NULL` | `NULL` |
| `print_kit_components` | `0` | `0` |
| `non_inv_acct` | `NULL` | `NULL` |
| `non_inv_acct_unit1` | `NULL` | `NULL` |
| `non_inv_acct_unit2` | `NULL` | `NULL` |
| `non_inv_acct_unit3` | `NULL` | `NULL` |
| `non_inv_acct_unit4` | `NULL` | `NULL` |
| `cost_conv` | `0.00000000` | `0` |
| `days_shipped_before_due_date_tolerance` | `NULL` | `NULL` |
| `days_shipped_after_due_date_tolerance` | `NULL` | `NULL` |
| `shipped_over_ordered_qty_tolerance` | `NULL` | `NULL` |
| `shipped_under_ordered_qty_tolerance` | `NULL` | `NULL` |
| `manufacturer_id` | `NULL` | `NULL` |
| `manufacturer_item` | `NULL` | `NULL` |
| `external_shipment_revision_id` | `NULL` | `NULL` |
| `external_planning_revision_id` | `NULL` | `NULL` |
| `allow_on_pick_list` | `0` | wajib `0`, kolom tenant `NOT NULL` |
| `whse` | `MAIN` | staging `whse` |
| `PL_override_item_description` | `0` | `0` |
| `PL_alternate_item_description` | `NULL` | `NULL` |

Procedure memastikan jumlah `co_bln_mst` rows sama dengan staging line count.

---

## 17. Idempotency pada Pembuatan CO

Existing CO dicari dengan:

```text
site_ref = @SiteRef
cust_num = staging customer
cust_po  = @SourceCoNum
type     = B
```

Jika existing Blanket CO ditemukan:

```text
1. Hitung existing coitem_mst rows
2. Hitung existing co_bln_mst rows
3. Bandingkan jumlah dengan staging
4. Bandingkan item dan quantity coitem
5. Bandingkan item, blanket_qty, dan cont_price co_bln
6. Jika cocok, jangan create CO baru
7. Set staging.created_co_num = existing CO
8. Set staging.process_status = P
9. Return Success = 1
```

Jika count/detail berbeda, process gagal agar duplicate atau conflicting order tidak disembunyikan.

---

## 18. Transaction Safety untuk Mongoose/IDO

### 18.1 Masalah yang Ditemukan

Error:

```text
Transaction count after EXECUTE indicates a mismatching number of
BEGIN and COMMIT statements. Previous count = 1, current count = 0.
```

Penyebab:

```text
Mongoose membuka outer transaction
→ SP menjalankan ROLLBACK TRANSACTION penuh
→ transaksi milik Mongoose ikut hilang
→ @@TRANCOUNT berubah dari 1 ke 0
```

### 18.2 Pola Final

```sql
DECLARE @InitialTranCount INT = @@TRANCOUNT;

IF @InitialTranCount = 0
    BEGIN TRANSACTION;
ELSE
    SAVE TRANSACTION SMK069ProcessCOSave;
```

Commit hanya jika transaksi dibuat oleh SP:

```sql
IF @InitialTranCount = 0 AND XACT_STATE() = 1
    COMMIT TRANSACTION;
```

Rollback:

```text
SP-owned transaction
→ full rollback

Caller-owned committable transaction
→ rollback to savepoint

Caller-owned uncommittable transaction
→ jangan full rollback di SP
→ rethrow original error
→ framework melakukan rollback miliknya
```

### 18.3 `XACT_ABORT`

Final process menggunakan:

```text
SET XACT_ABORT OFF
```

karena error ditangani secara terkontrol melalui TRY/CATCH dan savepoint. Receive SP juga menggunakan caller-safe transaction handling.

---

## 19. Error Case Terakhir dan Root Cause

### 19.1 Symptom

Form menampilkan:

```text
Uncommittable transaction is detected at the end of the batch.
The transaction is rolled back.
```

Data tampil `Valid`, tetapi Process/Reprocess gagal.

### 19.2 Root Cause

U/M pada payload tidak sesuai dengan base U/M item dan tidak memiliki conversion. Validation lama hanya memeriksa U/M kosong/terisi, sehingga row salah lolos sebagai Valid dan baru ditolak oleh standard processing/trigger saat pembuatan order.

### 19.3 Corrective Action

Validasi dipindahkan lebih awal ke Receive:

```text
U/M = base U/M item
atau
valid Global/Item/Customer conversion exists
```

Jika tidak:

```text
inbound_status = E
seluruh source order = E
TransferredRows = 0 untuk order tersebut
Process/Reprocess tidak dijalankan
```

### 19.4 Blanket Insert Error

Error berikut juga ditemukan:

```text
Cannot insert the value NULL into column 'allow_on_pick_list',
table 'dbo.co_bln_mst'; column does not allow nulls.
```

Fix:

```text
co_bln_mst.allow_on_pick_list = 0
```

---

## 20. API Choreography

### 20.1 Receive API

Memanggil method yang terhubung ke:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Satu call dapat membawa banyak source orders dan banyak lines.

Hasil receive:

```text
valid rows → temp process_status V
invalid rows → inbound status E
belum membuat Customer Order
```

### 20.2 Process API

Memanggil method yang terhubung ke:

```text
dbo.SMK069ProcessCustomerOrderSp
```

Satu call per distinct:

```text
SiteRef + SourceCoNum
```

### 20.3 Contoh Volume

```text
CSV rows       : 100
Source orders  : 25
Lines/order    : 4

API calls:
1 × Receive batch
25 × Process Customer Order

Output:
25 × co_mst
100 × coitem_mst
100 × co_bln_mst
```

### 20.4 Method Parameters — Process

Contoh conceptual parameter order:

```text
SiteRef       = DEFAULT
SourceCoNum   = CS26080001
CustSeq       = 0
ProcessedBy   = POS_API
CreatedCoNum  = output
Success       = output
Infobar       = output
```

Exact REST URL mengikuti IDO/configuration tenant. Kontrak stored procedure di atas adalah source of truth untuk parameter order.

---

## 21. End-to-End Example

### 21.1 CSV Input

```text
Batch ID     : CSV-20260806-165400-A1B2C3
Source order : CS26080001
Customer     : C000001
Lines        : 4
```

### 21.2 Parse Result

```text
ue_SMK069_pos_csv_upload_mst
4 rows
upload_status = N
format error = 0
```

### 21.3 Import & Validate Result

```text
ReceivedRows    = 4
TotalOrders     = 1
ValidOrders     = 1
ErrorOrders     = 0
TransferredRows = 4
```

Inbound:

```text
4 rows → status T
```

Temp:

```text
4 rows
co_num = CS26080001
process_status = V
created_co_num = NULL
```

### 21.4 Process Result

Generated:

```text
@CreatedCoNum = CO26080017
```

Standard tables:

```text
co_mst     : 1 row, co_num CO26080017, type B, cust_po CS26080001
coitem_mst : 4 rows, co_num CO26080017
co_bln_mst : 4 rows, co_num CO26080017
```

Temp after process:

```text
co_num          = CS26080001
created_co_num  = CO26080017
process_status  = P
processed_date  = current date/time
processed_by    = caller user
```

---

## 22. Read-Only Verification SQL

### 22.1 CSV Header

```sql
SELECT
    batch_id,
    source_system,
    batch_status,
    DATALENGTH(csv_file) AS file_size,
    uploaded_date,
    received_rows,
    total_orders,
    validation_valid_orders,
    validation_error_orders,
    transferred_rows,
    result_message
FROM dbo.ue_SMK069_pos_csv_batch_mst
WHERE batch_id = N'<BATCH_ID>';
```

### 22.2 Parsed CSV Detail

```sql
SELECT
    row_no,
    custnum,
    order_date,
    conum,
    coline,
    item,
    qty_ordered,
    unit_price,
    siteref,
    whse,
    due_date,
    u_m,
    upload_status,
    result_message
FROM dbo.ue_SMK069_pos_csv_upload_mst
WHERE batch_id = N'<BATCH_ID>'
ORDER BY row_no;
```

### 22.3 Inbound Validation

```sql
SELECT
    row_no,
    SiteRef,
    co_num,
    co_line,
    cust_num,
    item,
    qty_ordered,
    u_m,
    inbound_status,
    validation_msg,
    transferred_date
FROM dbo.ue_SMK069_pos_sales_inbound_mst
WHERE source_system = N'POS'
  AND batch_id = N'<BATCH_ID>'
ORDER BY row_no;
```

### 22.4 Temp Staging

```sql
SELECT
    SiteRef,
    co_num AS source_co_num,
    created_co_num,
    co_line,
    cust_num,
    item,
    qty_ordered,
    u_m,
    unit_price,
    process_status,
    validation_msg,
    error_msg,
    retry_count,
    processed_date,
    processed_by
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = N'DEFAULT'
  AND co_num = N'<SOURCE_CO_NUM>'
ORDER BY co_line;
```

### 22.5 CO Header

```sql
SELECT
    site_ref,
    co_num,
    [type],
    cust_num,
    cust_po,
    cust_seq,
    whse,
    order_date,
    curr_code,
    terms_code,
    tax_code1,
    price,
    [cost],
    matl_cost_t
FROM dbo.co_mst
WHERE site_ref = N'DEFAULT'
  AND co_num = N'<CREATED_CO_NUM>';
```

### 22.6 CO Item Lines

```sql
SELECT
    site_ref,
    co_num,
    co_line,
    item,
    description,
    qty_ordered,
    qty_ordered_conv,
    u_m,
    price,
    price_conv,
    whse,
    due_date
FROM dbo.coitem_mst
WHERE site_ref = N'DEFAULT'
  AND co_num = N'<CREATED_CO_NUM>'
ORDER BY co_line;
```

### 22.7 Blanket Lines

```sql
SELECT
    site_ref,
    co_num,
    co_line,
    item,
    description,
    blanket_qty,
    blanket_qty_conv,
    u_m,
    cont_price,
    cont_price_conv,
    [stat],
    ship_site,
    whse,
    allow_on_pick_list,
    PL_override_item_description
FROM dbo.co_bln_mst
WHERE site_ref = N'DEFAULT'
  AND co_num = N'<CREATED_CO_NUM>'
ORDER BY co_line;
```

### 22.8 Reconciliation Counts

```sql
DECLARE
    @SiteRef NVARCHAR(8) = N'DEFAULT',
    @SourceCoNum NVARCHAR(10) = N'<SOURCE_CO_NUM>',
    @CreatedCoNum NVARCHAR(10) = N'<CREATED_CO_NUM>';

SELECT N'Temp' AS object_name, COUNT(*) AS row_count
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = @SiteRef AND co_num = @SourceCoNum
UNION ALL
SELECT N'coitem_mst', COUNT(*)
FROM dbo.coitem_mst
WHERE site_ref = @SiteRef AND co_num = @CreatedCoNum
UNION ALL
SELECT N'co_bln_mst', COUNT(*)
FROM dbo.co_bln_mst
WHERE site_ref = @SiteRef AND co_num = @CreatedCoNum;
```

Expected:

```text
Temp row count = coitem_mst row count = co_bln_mst row count
co_mst count = 1
```

---

## 23. Recovery dan Reprocess

### 23.1 CSV Format Error

```text
Perbaiki CSV
→ Upload ulang pada New Batch atau Re-parse sesuai policy
→ Parse CSV
```

Completed batch tidak diimpor ulang. Gunakan BatchId baru untuk pengujian ulang agar idempotency tidak mengembalikan hasil lama.

### 23.2 Receive Validation Error

```text
Periksa inbound.validation_msg
→ perbaiki source/master/mapping
→ kirim dengan BatchId baru
```

Raw row lama tetap dipertahankan sebagai audit.

### 23.3 Process Error

```text
staging.process_status = E
error_msg terisi
retry_count bertambah
```

Setelah master/staging diperbaiki secara controlled, jalankan Process/Reprocess lagi untuk `SiteRef + SourceCoNum`.

### 23.4 Existing CO

Jika existing Blanket CO ditemukan dan detail cocok:

```text
CO tidak dibuat ulang
created_co_num diisi existing CO
staging menjadi P
Success = 1
```

Jika detail tidak cocok, jangan overwrite. Investigasi conflict terlebih dahulu.

---

## 24. UAT Checklist

### 24.1 Happy Path

```text
[ ] Upload CSV binary berhasil
[ ] Detail rows langsung muncul
[ ] Parser format error = 0
[ ] Import & Validate menghasilkan TotalOrders > 0
[ ] ValidOrders sesuai
[ ] TransferredRows sesuai line count
[ ] Temp status V
[ ] Process menghasilkan CreatedCoNum
[ ] co_mst type = B
[ ] co_mst.cust_po = source co_num
[ ] coitem count = staging count
[ ] co_bln count = staging count
[ ] allow_on_pick_list = 0
[ ] staging created_co_num terisi
[ ] staging status P
```

### 24.2 Negative Tests

```text
[ ] invalid customer
[ ] invalid item
[ ] invalid warehouse
[ ] U/M kosong dan item base U/M ada
[ ] U/M sama dengan base U/M
[ ] U/M berbeda dengan valid conversion
[ ] U/M berbeda tanpa conversion
[ ] duplicate co_line
[ ] header inconsistent dalam satu source order
[ ] conum > 10
[ ] item > 30
[ ] qty <= 0
[ ] price < 0
[ ] duplicate BatchId
[ ] source order sudah ada di temp
[ ] reprocess existing matching CO
[ ] existing CO dengan line count berbeda
[ ] error di co_bln_mst rollback seluruh order
```

### 24.3 Transaction Tests

```text
[ ] Direct SQL call saat @@TRANCOUNT = 0
[ ] IDO method call dengan outer transaction
[ ] Error sebelum insert standard tables
[ ] Error saat coitem insert
[ ] Error saat co_bln insert
[ ] Outer transaction doomed menampilkan original SQL error
[ ] Tidak muncul transaction count mismatch error 266
```

---

## 25. Deployment Order

Recommended sequence:

```text
1. Apply table/column changes
   - created_co_num pada temp staging

2. Update IDO property
   - CreatedCoNum

3. Apply SMK069ImportCsvFileSp

4. Apply SMK069ReceivePosSalesJsonSp
   - U/M validation
   - caller-safe transaction

5. Apply SMK069RunCsvTestBatchSp
   - Import & Validate Only

6. Apply SMK069ProcessCustomerOrderSp
   - type B
   - coitem_mst
   - co_bln_mst
   - allow_on_pick_list = 0
   - savepoint transaction handling

7. Refresh IDO metadata/cache

8. Update CSV Console events

9. Update Error Processing grid/buttons

10. Run UAT with new BatchId and new SourceCoNum
```

---

## 26. Current Known Gaps / Hardening Items

Dokumen ini membedakan implemented behavior dari item yang masih perlu konfirmasi:

1. **Conversion factor** — validation mengecek existence conversion, tetapi converted quantity/price masih copied 1:1.
2. **Defensive U/M conversion check di Process SP** — current main validation berada di Receive. Manual direct staging harus dicegah atau melalui controlled validation.
3. **Additional width validation** — `whse`, `u_m`, `terms_code`, dan `tax_code1` perlu explicit message sesuai physical metadata.
4. **Standard business logic** — direct insert memakai standard triggers/constraints, tetapi perlu UAT functional comparison dengan standard Blanket Order entry.
5. **Release semantics** — `coitem_mst` dan `co_bln_mst` dibuat bersamaan sesuai current requirement; Finance/Order Management perlu mengonfirmasi lifecycle release/shipment/invoice.
6. **Performance** — 100-row/25-order test perlu direkam sebagai formal evidence setelah tenant run.
7. **Security** — REST method authorization dan permission harus mengikuti least privilege.
8. **Repository parity** — exact final parser, Receive, dan Process SQL perlu diekspor dari tenant dan dikomit tanpa rekonstruksi manual.

---

## 27. Source Files dan Sinkronisasi

Sudah dikomit pada branch ini:

```text
database/procedures/SMK069RunCsvTestBatchSp.sql
forms/02-SMK069PosCsvTestConsole.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
database/tables/SMK069_temp_sales_mst.md
```

Exact final tenant source yang masih perlu disinkronkan:

```text
database/stored-procedures/SMK069ImportCsvFileSp.sql
database/procedures/SMK069ReceivePosSalesJsonSp.sql
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

Jika implementasi tenant berubah, file SQL final dan dokumen ini harus diubah dalam commit/PR yang sama agar dokumentasi tidak tertinggal dari runtime.

---

## 28. Final Acceptance Definition

Case ini dianggap selesai ketika satu source order dari CSV dapat dibuktikan end-to-end:

```text
CSV raw row preserved
→ parsed row visible
→ canonical mapping correct
→ validation correct termasuk U/M
→ valid rows transferred to temp
→ Process menghasilkan Blanket CO
→ co_mst.type = B
→ coitem_mst lengkap
→ co_bln_mst lengkap
→ source co number tersimpan di cust_po
→ generated co number tersimpan di created_co_num
→ transaction atomic dan idempotent
→ read-only verification counts match
```
