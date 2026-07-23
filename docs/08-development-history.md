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
- Menambahkan mapping main account dan unit codes.
- Menambahkan optional fee account dan fee unit codes.
- Menambahkan optional customer dan bank.
- Menambahkan `settlement_type` dan `settlement_days`.

### Impact

- Stored procedure/IDO validation nanti dapat mengisi account hasil mapping pada payment staging.
- Mendukung GL langsung, clearing account, delayed settlement, maupun AR untuk aggregator.
- Jalur posting final tetap menunggu keputusan Finance dan flow resmi.

### Test

Dokumentasi dan struktur tabel telah ditambahkan. Pembuatan serta insert test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Tax Mapping Designed

### Reason

Kode pajak, rate, inclusive behavior, rounding, dan account dari POS tidak boleh langsung dianggap sesuai dengan aturan Finance serta konfigurasi SyteLine.

### Changes

- Menambahkan `SMK_RSC_POS_TaxMap_mst`.
- Primary key: `source_system + target_site + pos_tax_code`.
- Menambahkan `posting_mode` untuk tax-code processing, direct-account posting, dan no separate posting.
- Menambahkan target tax code, tax account, unit codes, expected rate, inclusive flag, taxable flag, rounding mode, dan tolerance amount.
- Menambahkan effective/expiration date dan active flag.
- Target tax code memakai `nvarchar(20)` sementara sampai domain/UDD tenant diverifikasi.

### Impact

- Validasi transaksi dapat memeriksa kode pajak berdasarkan site dan business date.
- Posting preview dapat memisahkan revenue dan tax account secara konsisten.
- Selisih pajak dapat dievaluasi menggunakan rounding rule dan tolerance.
- Tax treatment produksi tetap membutuhkan persetujuan Finance.

### Test

Pembuatan tabel, lookup test, dan posting test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — PoC Requirement Flexibility Confirmed

### Reason

Raw data resmi dari POS belum diterima. Format akhirnya mungkin lengkap, flat, atau hanya memiliki sejumlah field minimal.

### Changes

- Menegaskan bahwa seluruh tabel saat ini adalah candidate design.
- Menambahkan dokumentasi minimum data profile dan strategi perubahan requirement.
- Menetapkan bahwa source data tidak boleh ditimpa oleh hasil mapping.
- Menetapkan penambahan kolom secara backward-compatible dan penggunaan versioning/migration plan.
- `SMK_RSC_POS_RawLine_mst` dicatat sebagai alternatif bila source resmi berbentuk flat/minimal, bukan tabel wajib.

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
- Menambahkan rule criteria: outlet, item, kategori, sales channel, order type, line type, dan currency.
- Menambahkan `priority` serta pemilihan berdasarkan priority dan specificity.
- Menambahkan `amount_type` untuk revenue, discount, service charge, dan other component.
- Menambahkan account, unit codes, debit/credit direction, refund reversal, dan masa berlaku.

### Impact

- Validasi dapat memilih akun berdasarkan rule paling sesuai.
- Posting preview dapat memisahkan revenue, discount, service charge, dan komponen lain.
- Hasil ambigu menghentikan validasi.
- Account dan unit code final tetap membutuhkan persetujuan Finance.

### Test

Pembuatan tabel serta rule-resolution test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Posting Preview Designed

### Reason

Hasil mapping tidak boleh langsung diposting tanpa pemeriksaan account, unit code, debit, credit, currency, balance, approval, dan status posting.

### Changes

- Menambahkan `SMK_RSC_POS_PostingPreview_mst`.
- Primary key: `preview_num + line_num`.
- Menambahkan `generation_num` agar rebuild tidak menimpa preview approved/posted.
- Menambahkan source references, component type, mapping source/reference, currency, exchange rate, account, unit codes, debit-credit, approval, posting status, dan SyteLine reference.
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
- Primary key: `inbound_id` menggunakan `RowPointerType`/`uniqueidentifier`.
- Menambahkan `request_id`, `idempotency_key`, `correlation_id`, source metadata, endpoint, HTTP method, content type, dan payload version/format.
- Menambahkan storage mode untuk database, approved external storage, atau metadata-only.
- Menambahkan optional `payload_text`, `payload_location`, `content_length`, dan `payload_sha256`.
- Menambahkan receive/parse status, parsed date, optional batch reference, row/accepted/rejected counts, response, error, dan retry count.
- Menambahkan retention date, purge flag, dan purge date.
- Menetapkan larangan penyimpanan Authorization header, password, token, API secret, PIN, CVV, dan full card number.
- Menetapkan bahwa inbound dapat tetap ada tanpa batch ketika parsing gagal.

### Impact

- Duplicate dan idempotent retry dapat dikendalikan sebelum membuat staging baru.
- Parsing error tetap dapat diaudit walaupun batch belum tercipta.
- Request dapat ditelusuri dari inbound ke batch, process log, dan hasil berikutnya.
- Raw payload retention dapat dikelola tanpa menghapus metadata audit.
- Dukungan `nvarchar(max)`, ukuran request, storage mode, dan retensi masih harus diverifikasi pada tenant.

### Test

Dokumentasi dan struktur kandidat telah ditambahkan. Long-text test, duplicate test, payload parsing, retry, retention, dan purge test pada SyteLine Cloud belum dilakukan.

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

Inbound memakai status receive/parse tersendiri sesuai dokumentasi tabel inbound.

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
- per-table documentation.

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
