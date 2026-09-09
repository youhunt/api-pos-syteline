# 08 — Development History

## 2026-07-23 — Repository Initialization

Repository `youhunt/api-pos-syteline` disiapkan sebagai pusat dokumentasi dan artefak integrasi POS ke SyteLine.

Keputusan awal:

- integrasi dibuat di dalam SyteLine/Mongoose;
- tidak membuat aplikasi web terpisah;
- data diterima melalui API atau custom form/import SyteLine;
- data disimpan pada permanent staging tables;
- pengolahan menggunakan stored procedure atau server-side IDO logic;
- hasil akhir diarahkan ke laporan keuangan SyteLine;
- jalur posting final belum diputuskan.

## 2026-07-23 — Cloud Naming Convention Confirmed

Dikonfirmasi bahwa environment Cloud menambahkan prefix `ue_` pada custom physical table.

```text
Metadata object : SMK_RSC_POS_Batch_mst
Physical table  : dbo.ue_SMK_RSC_POS_Batch_mst
```

## 2026-07-23 — Initial Tables Designed

### Staging

1. `SMK_RSC_POS_Batch_mst`
2. `SMK_RSC_POS_Tran_mst`
3. `SMK_RSC_POS_TranLine_mst`
4. `SMK_RSC_POS_Payment_mst`
5. `SMK_RSC_POS_ProcessLog_mst`

### Mapping

6. `SMK_RSC_POS_OutletMap_mst`
7. `SMK_RSC_POS_ItemMap_mst`

## 2026-07-23 — Table Documentation Format Standardized

Seluruh dokumentasi tabel menggunakan format kolom lengkap berikut:

```text
Column Name
Schema
Table Name
Data Type
System Data Type
Length
Decimal Position
Default Value
Is Nullable
Primary Key
Key Sequence
```

Kolom standar Mongoose juga dicantumkan pada setiap tabel.

## 2026-07-23 — Payment Mapping Designed

### Reason

Payment code dari POS tidak boleh langsung dipercaya sebagai account SyteLine. Diperlukan mapping internal untuk cash, QRIS, kartu, transfer, voucher, dan aggregator.

### Changes

- Menambahkan `SMK_RSC_POS_PaymentMap_mst`.
- Primary key: `source_system + target_site + payment_code`.
- Menambahkan main account, unit codes, optional fee account, optional customer/bank, `settlement_type`, dan `settlement_days`.

### Impact

- Validasi dapat mengisi account hasil mapping pada payment staging.
- Mendukung GL langsung, clearing account, delayed settlement, maupun AR untuk aggregator.
- Jalur posting final tetap menunggu keputusan Finance dan flow resmi.

### Test

Pembuatan tabel dan insert test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Tax Mapping Designed

### Reason

Kode pajak, rate, inclusive behavior, rounding, dan account dari POS tidak boleh langsung dianggap sesuai dengan aturan Finance serta konfigurasi SyteLine.

### Changes

- Menambahkan `SMK_RSC_POS_TaxMap_mst`.
- Primary key: `source_system + target_site + pos_tax_code`.
- Menambahkan `posting_mode`, target tax code, tax account, unit codes, rate, inclusive flag, taxable flag, rounding mode, tolerance, active flag, dan masa berlaku.
- Target tax code memakai `nvarchar(20)` sementara sampai domain/UDD tenant diverifikasi.

### Impact

- Validasi dapat memeriksa pajak berdasarkan site dan business date.
- Posting preview dapat memisahkan revenue dan tax account.
- Selisih pajak dapat dievaluasi menggunakan rounding rule dan tolerance.

### Test

Pembuatan tabel, lookup test, dan posting test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — PoC Requirement Flexibility Confirmed

### Reason

Raw data resmi dari POS belum diterima. Format akhirnya mungkin lengkap, flat, atau hanya memiliki sejumlah field minimal.

### Changes

- Menegaskan bahwa seluruh tabel saat ini adalah candidate design.
- Menambahkan dokumentasi minimum-data profile dan strategi perubahan requirement.
- Menetapkan source data tidak boleh ditimpa oleh hasil mapping.
- Menetapkan perubahan backward-compatible, versioning, dan migration plan.
- Mencatat `SMK_RSC_POS_RawLine_mst` sebagai alternatif bila source berbentuk flat/minimal.

### Impact

- Tabel yang tidak relevan dapat tidak digunakan setelah raw data resmi diterima.
- Struktur dapat disederhanakan tanpa menghapus jejak desain awal.
- API contract dan posting logic tetap menunggu source sample serta keputusan Finance.

### Test

Belum ada raw-data validation test karena contoh payload resmi belum tersedia.

## 2026-07-23 — Revenue Mapping Designed

### Reason

Akun pendapatan dapat bergantung pada kategori, outlet, sales channel, order type, line type, currency, atau kombinasi, bukan hanya item.

### Changes

- Menambahkan `SMK_RSC_POS_RevenueMap_mst`.
- Menggunakan `map_id` sebagai primary key.
- Menambahkan rule criteria, priority, specificity, amount type, account, unit codes, debit/credit direction, refund reversal, active flag, dan masa berlaku.

### Impact

- Validasi dapat memilih akun berdasarkan rule paling sesuai.
- Posting preview dapat memisahkan revenue, discount, service charge, dan komponen lain.
- Hasil ambigu menghentikan validasi.

### Test

Pembuatan tabel serta rule-resolution test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Posting Preview Designed

### Reason

Hasil mapping tidak boleh langsung diposting tanpa pemeriksaan account, unit code, debit, credit, currency, balance, approval, dan status posting.

### Changes

- Menambahkan `SMK_RSC_POS_PostingPreview_mst`.
- Primary key: `preview_num + line_num`.
- Menambahkan generation history, source/mapping reference, currency, exchange rate, account, unit codes, debit-credit, approval, posting status, dan SyteLine reference.
- Menetapkan balance rule untuk transaction dan domestic currency.

### Impact

- Tim dapat memeriksa simulasi jurnal sebelum posting aktual.
- Mapping error dan unbalanced entries dihentikan lebih awal.
- Approval dapat diterapkan tanpa mengubah source staging.
- Preview history dipertahankan untuk audit.

### Test

Generate-preview, balancing, approval, dan posting test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Inbound Request and Raw Payload Designed

### Reason

Request perlu dicatat sebelum parsing agar error awal, duplicate request, retry, payload version, dan audit tetap dapat ditelusuri. Raw payload mungkin perlu dipertahankan sesuai kebijakan keamanan dan retensi.

### Changes

- Menambahkan `SMK_RSC_POS_Inbound_mst`.
- Primary key: `inbound_id`.
- Menambahkan request/correlation/idempotency metadata, endpoint, HTTP/content metadata, payload version/format, storage mode, optional raw payload/location/hash, parsing result, counts, response/error, retry, retention, dan purge control.
- Menetapkan larangan penyimpanan authorization secret, password, token, API secret, PIN, CVV, dan full card number.

### Impact

- Duplicate dan idempotent retry dapat dikendalikan sebelum membuat staging baru.
- Parsing error tetap dapat diaudit walaupun batch belum tercipta.
- Request dapat ditelusuri dari inbound ke batch dan proses berikutnya.

### Test

Long-text, duplicate, parsing, retry, retention, dan purge test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Minimal Raw-Line Profile Designed

### Reason

Sebelum masuk desain IDO, diperlukan bentuk konkret untuk kemungkinan source minimal yang hanya berisi:

```text
business_date
trans_num
pos_item_code
pos_qty
total_amt
```

Desain harus dapat menerima format flat tersebut tanpa memaksa seluruh struktur header-detail-payment.

### Changes

- Menambahkan `SMK_RSC_POS_RawLine_mst`.
- Physical table: `dbo.ue_SMK_RSC_POS_RawLine_mst`.
- Primary key: `batch_num + source_row_num`.
- Menetapkan source fields: `business_date`, `trans_num`, `pos_item_code`, `pos_qty`, dan `total_amt`.
- Menambahkan hasil mapping terpisah: `item`, `syteline_qty`, dan `u_m`.
- Menambahkan status, validation/error message, process date, dan SyteLine reference.
- Menetapkan transaction summary melalui grouping `business_date + trans_num`.
- Menetapkan bahwa complete profile (`Tran/TranLine/Payment`) dan minimal profile (`RawLine`) merupakan alternatif sesuai raw data resmi.

### Impact

- Payload flat dapat disimpan tanpa membuat transaction header secara fisik pada tahap awal.
- Item yang sama dapat muncul beberapa kali karena identity baris menggunakan `source_row_num`.
- Source quantity dan total tetap utuh setelah mapping.
- Field payment, tax, discount, service charge, void/refund, outlet, dan currency yang tidak tersedia tidak boleh diisi menggunakan asumsi tersembunyi.
- Posting preview masih dapat dibentuk setelah mapping/default resmi tersedia.

### Test

Dokumentasi dan struktur kandidat telah ditambahkan. Import, duplicate-row, grouping, item mapping, reconciliation, dan posting-preview test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — IDO Architecture and Inbound IDO Designed

### Reason

Setelah struktur complete profile dan minimal profile terdokumentasi, diperlukan lapisan IDO yang memisahkan query/form binding dari public integration methods. Direct REST write ke custom table berisiko melewati idempotency, transaction control, validation, logging, dan duplicate-posting protection.

### Changes

- Menambahkan `docs/11-ido-design-overview.md`.
- Menetapkan tiga lapisan IDO: entity IDO, monitor/composite IDO, dan service IDO.
- Menetapkan candidate service IDO `SMKRSCPosIntegration`.
- Menyusun catalog nama entity IDO untuk seluruh staging, mapping, raw-line, dan posting-preview table.
- Menetapkan general property, source immutability, site isolation, update policy, security class, REST exposure, dan method transaction-boundary rules.
- Menambahkan `ido/01-SMKRSCPosInbounds.md`.
- Menetapkan IDO `SMKRSCPosInbounds` dengan primary key `InboundId`, default order `ReceivedDate DESC`, property mapping lengkap, default property list, status transition, optional batch subcollection, authorization matrix, dan test scenarios.
- Menetapkan `PayloadText` tidak termasuk default collection.
- Merancang controlled methods `GetInboundPayload`, `RetryParse`, dan `PurgePayload`.
- Menetapkan direct public insert/update/delete pada entity IDO tidak digunakan untuk proses integrasi utama.

### Impact

- Custom form dapat memonitor inbound request tanpa membuka raw payload secara default.
- Raw payload access dapat dibatasi pada authorization khusus.
- Retry dan purge memiliki jalur terkontrol serta dapat dicatat pada process log.
- Penerimaan API nantinya diarahkan melalui service IDO, bukan direct insert ke entity IDO.
- IDO dan method tetap candidate sampai naming, long-text support, authorization, dan tenant behavior diverifikasi.

### Test

Metadata IDO belum dibuat pada tenant. LoadCollection, property serialization, long-text behavior, security, retry, purge, subcollection, direct-update rejection, dan site-isolation test belum dilakukan.

## 2026-07-23 — Initial Status Model

```text
N = New
R = Received
V = Validated / Ready
I = In Process
P = Processed
E = Error
C = Cancelled
```

Inbound memakai status receive/parse tersendiri sesuai dokumentasi tabel dan IDO inbound.

## 2026-07-23 — Documentation Baseline Added

Dokumentasi awal dibuat meliputi:

- project overview;
- architecture and processing flow;
- database design;
- Cloud naming conventions;
- draft API contract;
- financial posting options;
- roadmap;
- open questions;
- per-table documentation;
- IDO architecture and per-IDO documentation.

## Format Entri Berikutnya

```markdown
## YYYY-MM-DD — Judul Perubahan

### Reason
Alasan bisnis/teknis.

### Changes
- Object/file yang berubah.
- Kolom/parameter/logic yang berubah.

### Impact
Dampak pada API, form, stored procedure, posting, atau data existing.

### Test
Test yang dilakukan dan hasilnya.

### Decision/Owner
Pihak yang menyetujui bila terkait aturan bisnis.
```
