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

Contoh:

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
- Mendukung rancangan GL langsung, clearing account, delayed settlement, maupun AR untuk aggregator.
- Jalur posting final tetap menunggu keputusan Finance dan flow resmi.

### Test

Dokumentasi dan struktur tabel telah ditambahkan ke repository. Pembuatan serta insert test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Tax Mapping Designed

### Reason

Kode pajak, rate, inclusive behavior, rounding, dan account dari POS tidak boleh langsung dianggap sesuai dengan aturan Finance serta konfigurasi SyteLine. Diperlukan mapping internal yang dapat dipakai baik untuk proses tax code maupun direct account posting.

### Changes

- Menambahkan `SMK_RSC_POS_TaxMap_mst`.
- Primary key: `source_system + target_site + pos_tax_code`.
- Menambahkan `posting_mode` untuk membedakan tax-code processing, direct-account posting, dan no separate posting.
- Menambahkan target tax code, tax account, unit codes, expected rate, inclusive flag, taxable flag, rounding mode, dan tolerance amount.
- Menambahkan effective/expiration date dan active flag.
- Mendokumentasikan target tax code sebagai `nvarchar(20)` sementara sampai domain/UDD tenant diverifikasi.

### Impact

- Validasi transaksi dapat memeriksa kode pajak berdasarkan site dan business date.
- Posting preview dapat memisahkan revenue dan tax account secara konsisten.
- Selisih perhitungan pajak dapat dievaluasi menggunakan rounding rule dan tolerance.
- Tax treatment produksi tetap membutuhkan persetujuan Finance.

### Test

Dokumentasi dan struktur tabel telah ditambahkan ke repository. Pembuatan tabel, lookup test, dan posting test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — PoC Requirement Flexibility Confirmed

### Reason

Raw data resmi dari POS belum diterima. Format akhirnya mungkin lengkap, flat, atau hanya memiliki sejumlah field minimal. Desain tidak boleh dianggap final terlalu dini.

### Changes

- Menegaskan bahwa seluruh tabel saat ini adalah candidate design.
- Menambahkan dokumentasi minimum data profile dan strategi perubahan requirement.
- Menetapkan bahwa source data tidak boleh ditimpa oleh hasil mapping.
- Menetapkan penambahan kolom secara backward-compatible dan penggunaan versioning/migration plan.
- `SMK_RSC_POS_RawLine_mst` dicatat sebagai alternatif bila source resmi berbentuk flat/minimal, bukan sebagai tabel wajib.

### Impact

- Tabel yang tidak relevan dapat tidak digunakan setelah raw data resmi diterima.
- Struktur dapat disederhanakan tanpa menghapus jejak desain awal.
- API contract dan posting logic tetap menunggu source sample serta keputusan Finance.

### Test

Belum ada raw-data validation test karena contoh payload resmi belum tersedia.

## 2026-07-23 — Revenue Mapping Designed

### Reason

Akun pendapatan tidak selalu dapat ditentukan hanya dari item. Requirement dapat meminta mapping berdasarkan kategori, outlet, sales channel, order type, line type, currency, atau kombinasi. Discount dan service charge juga mungkin membutuhkan akun tersendiri.

### Changes

- Menambahkan `SMK_RSC_POS_RevenueMap_mst`.
- Menggunakan `map_id` sebagai primary key agar kriteria mapping dapat berubah tanpa composite key yang panjang.
- Menambahkan rule criteria: outlet, item, kategori, sales channel, order type, line type, dan currency.
- Menambahkan `priority` serta pemilihan rule berdasarkan priority dan specificity.
- Menambahkan `amount_type` untuk revenue, discount, service charge, dan other component.
- Menambahkan account, unit codes, debit/credit direction, dan refund reversal control.
- Menambahkan active/effective/expiration controls.

### Impact

- Stored procedure/IDO validation nanti dapat memilih akun berdasarkan rule yang paling sesuai.
- Posting preview dapat memisahkan revenue, discount, service charge, dan komponen lainnya.
- Hasil ambigu harus menghentikan validasi agar tidak terjadi posting ke account yang salah.
- Account dan unit code final tetap membutuhkan persetujuan Finance.

### Test

Dokumentasi dan struktur tabel telah ditambahkan ke repository. Pembuatan tabel serta rule-resolution test pada SyteLine Cloud belum dilakukan.

## 2026-07-23 — Posting Preview Designed

### Reason

Hasil mapping tidak boleh langsung diposting ke modul keuangan tanpa pemeriksaan. Diperlukan lapisan preview yang memperlihatkan account, unit code, source reference, debit, credit, currency, balance, approval, dan status posting sebelum transaksi aktual dibuat di SyteLine.

### Changes

- Menambahkan `SMK_RSC_POS_PostingPreview_mst`.
- Primary key: `preview_num + line_num`.
- Menambahkan `generation_num` agar rebuild menghasilkan versi baru dan tidak menimpa preview approved/posted.
- Menambahkan `posting_group`, `target_module`, `source_level`, source transaction/line/payment reference, component type, mapping source, dan mapping reference.
- Menambahkan currency, exchange rate, account, unit codes, source amount, debit-credit transaction currency, dan debit-credit domestic currency.
- Menambahkan approval status, approver, posting status, posted date, dan SyteLine reference.
- Menetapkan balance rule untuk transaction serta domestic currency.

### Impact

- Tim dapat memeriksa simulasi jurnal sebelum posting aktual.
- Mapping error dan unbalanced entries dapat dihentikan lebih awal.
- Approval dapat diterapkan tanpa mengubah source staging.
- Preview history dapat dipertahankan untuk audit dan troubleshooting.
- Tabel tetap bersifat candidate sampai target module, grouping, dan approval flow resmi disepakati.

### Test

Dokumentasi dan struktur tabel telah ditambahkan ke repository. Generate-preview test, balancing test, approval test, dan posting test pada SyteLine Cloud belum dilakukan.

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

Gunakan format berikut untuk setiap perubahan:

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
