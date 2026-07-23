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