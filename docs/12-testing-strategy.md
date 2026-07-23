# 12 — Testing Strategy

## Purpose

Dokumen ini menjelaskan cara menguji integrasi POS → SyteLine secara bertahap walaupun raw data resmi dan jalur posting final belum tersedia.

Testing tidak dimulai dari posting ke General Ledger. Testing dimulai dari lapisan paling aman:

```text
Metadata/Table → IDO → Receive/Staging → Validation/Mapping
→ Reconciliation → Posting Preview → Approval → Actual Posting
```

Actual posting hanya diuji setelah account, tax, refund, period, approval, dan target module disetujui Finance/SyteLine.

## Environment Rule

- Gunakan development/test tenant atau test site.
- Jangan menggunakan production untuk data simulasi.
- Gunakan prefix data test yang mudah dikenali, misalnya `TST-`, `TEST-`, atau `UAT-`.
- Account, item, outlet, customer, warehouse, dan unit code test harus disepakati.
- Seluruh test harus dapat dibersihkan tanpa menghapus data produksi.

## Testing Layers

### Layer 0 — Metadata Smoke Test

Tujuan: memastikan object dasar berhasil dibuat.

Periksa:

- custom table dapat dibuat;
- physical table `dbo.ue_SMK_...` tersedia;
- primary key dan default value bekerja;
- standard Mongoose columns terisi;
- `RowPointer` unik;
- `SiteRef` sesuai site;
- IDO dapat di-load;
- property type dan length sesuai.

Belum ada API atau posting pada layer ini.

### Layer 1 — Entity IDO CRUD/Read Test

Tujuan: memastikan IDO dapat membaca data dan kebijakan write bekerja.

Periksa:

- `LoadCollection` mengembalikan property yang benar;
- filter, order, paging, dan site isolation bekerja;
- direct insert/update/delete ditolak untuk IDO yang read-only;
- property besar/sensitif seperti `PayloadText` tidak otomatis dimuat;
- subcollection mengembalikan parent-child yang benar.

### Layer 2 — Receive and Staging Test

Tujuan: memastikan request diterima dan data staging dibuat konsisten.

Periksa:

- satu inbound record dibuat;
- satu batch dibuat ketika parsing berhasil;
- row count sesuai payload;
- source values tersimpan utuh;
- status berubah melalui transition yang diizinkan;
- process log dibuat;
- error parsing tetap meninggalkan inbound audit record;
- tidak terjadi partial record ketika transaction boundary gagal.

### Layer 3 — Validation and Mapping Test

Tujuan: memastikan source diterjemahkan ke master SyteLine secara terkendali.

Periksa:

- outlet mapping tepat satu;
- item mapping tepat satu;
- quantity conversion benar;
- payment mapping menghasilkan account yang valid;
- tax mapping mengikuti mode yang dipilih;
- revenue rule memilih priority/specificity yang benar;
- ambiguous mapping menghasilkan error;
- expired/inactive mapping tidak digunakan;
- source quantity, item code, amount, dan payload tidak ditimpa.

### Layer 4 — Reconciliation Test

Tujuan: memastikan angka antar-level konsisten.

Complete profile:

```text
Batch trans_count = jumlah transaction
Batch totals = SUM(transaction totals)
Transaction item_count = jumlah line yang valid
Transaction payment_amt = SUM(payment amount)
Transaction tax_amt = SUM(line/header tax sesuai rule)
```

Minimal profile:

```text
Raw row count = jumlah rows payload
Transaction count = COUNT(DISTINCT business_date + trans_num)
Transaction total = SUM(total_amt) per business_date + trans_num
Batch total = SUM(total_amt)
```

### Layer 5 — Posting Preview Test

Tujuan: menguji simulasi posting tanpa membuat transaksi keuangan aktual.

Periksa:

- setiap line memiliki account dan unit code valid;
- satu line hanya memiliki debit atau credit;
- total debit = total credit;
- domestic debit = domestic credit;
- source dan mapping reference dapat ditelusuri;
- generation baru tidak menimpa preview lama;
- preview error/unbalanced tidak dapat di-approve;
- preview posted tidak dapat diposting ulang.

Layer ini menjadi batas aman PoC sebelum jalur posting final disetujui.

### Layer 6 — API/Service IDO Test

Gunakan Postman atau REST client setelah service IDO tersedia.

Periksa:

- authentication dan authorization;
- request schema/version;
- response code;
- idempotency;
- retry;
- malformed payload;
- payload terlalu besar;
- unsupported version;
- timeout dan rollback;
- concurrent duplicate requests;
- rate/volume behavior.

Public receive harus memanggil controlled service method, bukan direct write ke entity IDO.

### Layer 7 — Actual Posting Test

Dijalankan terakhir pada test environment.

Prasyarat:

- preview balance;
- account/dimension disetujui Finance;
- target module final;
- accounting period terbuka;
- approval terpenuhi;
- rollback/reversal procedure tersedia;
- duplicate-posting protection aktif.

Periksa:

- transaksi SyteLine benar-benar tercipta;
- `syteline_ref` tersimpan;
- staging menjadi posted hanya setelah target berhasil;
- kegagalan target tidak meninggalkan status posted palsu;
- retry tidak membuat transaksi ganda;
- laporan/ledger sesuai preview.

## Recommended First PoC

Mulai dari minimal profile karena paling mudah diverifikasi:

```text
business_date, trans_num, pos_item_code, pos_qty, total_amt
```

Dataset contoh:

```text
2026-07-23 | TRX001 | PIZZA001 | 2 | 200000
2026-07-23 | TRX001 | DRINK001 | 1 |  25000
2026-07-23 | TRX002 | PIZZA002 | 1 | 125000
```

Expected result:

```text
Inbound record       : 1
Batch                 : 1
Raw lines             : 3
Distinct transactions : 2
TRX001 total          : 225000
TRX002 total          : 125000
Batch total           : 350000
```

Sebelum test, siapkan mapping test untuk `PIZZA001`, `DRINK001`, dan `PIZZA002`.

## Test Execution Sequence

Urutan yang disarankan:

1. buat table dan IDO di test tenant;
2. seed master/mapping test;
3. jalankan metadata smoke test;
4. kirim minimal valid payload;
5. cocokkan inbound, batch, raw line, count, dan totals;
6. jalankan unmapped-item test;
7. perbaiki mapping lalu jalankan retry;
8. kirim payload yang sama dengan idempotency key yang sama;
9. pastikan tidak ada batch kedua;
10. generate posting preview;
11. uji unbalanced preview dan approval rejection;
12. setelah Finance menyetujui, lanjut actual posting test.

## Evidence Required

Untuk setiap test simpan:

- Test Case ID;
- tanggal, tester, environment, dan site;
- request/payload yang dipakai;
- response API/IDO method;
- `InboundId`, `RequestId`, dan `BatchNum`;
- screenshot form atau hasil collection;
- process log;
- row counts dan reconciliation result;
- preview number serta debit/credit totals;
- expected result;
- actual result;
- status Pass/Fail/Blocked;
- defect atau catatan perbaikan.

## Entry and Exit Criteria

### Entry Criteria

- object yang diuji sudah dibuat di test tenant;
- mapping/master test tersedia;
- test data dan expected result sudah ditetapkan;
- user tester memiliki authorization yang benar;
- production posting dinonaktifkan.

### Exit Criteria PoC

- valid payload diterima tanpa data hilang;
- invalid payload menghasilkan error yang jelas;
- duplicate request tidak membuat batch ganda;
- source data tidak ditimpa;
- mapping dan quantity conversion benar;
- reconciliation sesuai;
- posting preview balance;
- retry dan audit trail dapat ditelusuri;
- belum ada actual posting yang dilakukan tanpa approval Finance/SyteLine.

## Test Data Policy

- Gunakan data sintetis, bukan data kartu/customer nyata.
- Jangan menyimpan Authorization header, token, password, PIN, CVV, full card number, atau secret.
- Test payload harus menggunakan nominal dan kode yang mudah dikenali.
- Data test production-like harus dimasking.
- Cleanup dilakukan melalui prosedur yang mempertahankan audit yang masih dibutuhkan.
