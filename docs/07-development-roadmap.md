# 07 — Development Roadmap

## Phase 0 — Discovery

- Dapatkan flow resmi POS → SyteLine.
- Dapatkan contoh payload/file aktual.
- Konfirmasi volume transaksi dan frekuensi pengiriman.
- Konfirmasi versi SyteLine/Mongoose dan fasilitas REST/IDO.
- Workshop Finance untuk jalur posting.
- Tentukan security dan network path.

**Exit criteria:** format sumber, ownership, dan target proses disetujui.

## Phase 1 — Staging Data Model

- Buat Batch.
- Buat Transaction Header.
- Buat Transaction Line.
- Buat Payment.
- Buat Process Log.
- Buat Outlet Map.
- Buat Item Map.
- Verifikasi physical table `ue_...` pada Cloud.
- Verifikasi standard columns, primary key, index, dan view.

**Exit criteria:** seluruh tabel dapat diakses dan diuji CRUD dasar.

## Phase 2 — Mapping Model

- Buat Payment Map.
- Buat Tax Map.
- Buat Revenue Map.
- Tentukan unit code mapping.
- Tambahkan effective/expiration date rules.
- Siapkan seed/sample mapping.

**Exit criteria:** seluruh data PoC dapat termapping tanpa hardcode.

## Phase 3 — IDO dan Form

- Buat IDO untuk tabel staging.
- Buat IDO untuk mapping.
- Definisikan primary property dan subcollection.
- Buat form Batch Monitor.
- Tambahkan tab Transaction, Line, Payment, Log.
- Buat form mapping.
- Tambahkan tombol Validate, Preview, Process, Retry, Cancel.

**Exit criteria:** user dapat melihat dan mengelola data PoC melalui SyteLine.

## Phase 4 — Validation Engine

Candidate methods/procedures:

```text
SMKRSCPosValidateBatchSp
SMKRSCPosValidateTransactionSp
SMKRSCPosBuildPreviewSp
```

Validasi:

- duplikasi;
- parent-child existence;
- outlet mapping;
- item/U-M mapping;
- payment mapping;
- tax/revenue mapping;
- period dan accounting date;
- total header/detail/payment;
- void/refund reference;
- debit-credit preview balance.

**Exit criteria:** batch valid menjadi `V`; masalah menghasilkan error yang dapat ditindaklanjuti.

## Phase 5 — API Receive

- Buat custom IDO Method.
- Definisikan parameter payload dan output.
- Implement idempotency.
- Implement correlation ID.
- Simpan batch/transaction/line/payment.
- Catat process log.
- Expose melalui REST.
- Buat Postman collection.

**Exit criteria:** payload PoC dapat dikirim dan terlihat di form SyteLine.

## Phase 6 — Posting Preview

- Buat tabel/view preview.
- Rekap per outlet/date/account/unit code.
- Hitung debit-credit.
- Tampilkan source totals dan posting totals.
- Tambahkan approval/review bila dibutuhkan.

**Exit criteria:** Finance menyetujui hasil preview untuk sample resmi.

## Phase 7 — Actual Posting

- Pilih GL/AR/Order/Inventory route.
- Gunakan proses standard SyteLine sebisa mungkin.
- Simpan document/journal reference.
- Handle rollback/reversal.
- Jalankan via background task untuk volume besar.

**Exit criteria:** transaksi uji berhasil muncul pada modul dan laporan target.

## Phase 8 — Testing

- Unit test procedure/method.
- API positive/negative test.
- Duplicate and retry test.
- Large-volume test.
- Financial reconciliation.
- Closed-period test.
- Void/refund test.
- Security test.
- User acceptance test.

**Exit criteria:** UAT sign-off dan defect kritis selesai.

## Phase 9 — Deployment and Operations

- Deployment checklist.
- Parameter/environment configuration.
- Service account/security setup.
- Monitoring query/dashboard.
- Error and retry runbook.
- Backup/retention policy.
- Support handover.
- Production smoke test.

## Definition of Done per Object

Setiap object dianggap selesai bila:

- tujuan dan owner jelas;
- metadata/DDL terdokumentasi;
- dependency tercatat;
- naming mengikuti Cloud;
- test case tersedia;
- hasil test tercatat;
- deployment step tersedia;
- rollback note tersedia;
- perubahan masuk development history dan changelog.
