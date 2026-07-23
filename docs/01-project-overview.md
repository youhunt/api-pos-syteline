# 01 — Project Overview

## Latar Belakang

Aplikasi POS Pizza Hut/RSC menghasilkan data transaksi penjualan yang perlu diterima dan diolah oleh Infor SyteLine. Data dapat dikirim untuk satu hari, satu minggu, atau periode bebas sesuai mekanisme sumber.

Integrasi tidak dibangun sebagai aplikasi independen. API, staging, validasi, pengolahan, monitoring, dan jalur posting dirancang di dalam SyteLine/Mongoose.

## Tujuan Bisnis

- Mengurangi proses input dan rekonsiliasi manual.
- Menyediakan satu sumber data staging yang dapat diaudit.
- Memastikan transaksi POS tervalidasi sebelum memengaruhi data finansial.
- Mendukung proses ulang tanpa duplikasi posting.
- Menghasilkan data yang dapat digunakan dalam laporan keuangan SyteLine.
- Menyediakan jejak proses dari request hingga referensi transaksi SyteLine.

## Ruang Lingkup PoC

### Termasuk

- Custom staging tables.
- Tabel mapping outlet dan item.
- Process log.
- IDO dan custom form monitoring.
- Stored procedure atau server-side IDO Method.
- REST API penerimaan batch.
- Validasi struktur, mapping, nilai, dan duplikasi.
- Posting preview.
- Pengujian menggunakan Postman.

### Belum Diputuskan

- Format payload resmi POS.
- Cara autentikasi API.
- Batas volume dan ukuran request.
- Mekanisme push/pull.
- Jalur posting final: GL, AR, Customer Order, Inventory, atau kombinasi.
- Treatment pajak, diskon, komisi aggregator, void, refund, dan settlement.

## Aktor

| Aktor | Peran |
|---|---|
| Tim POS | Menyediakan data, struktur payload, ID unik, dan aturan pengiriman |
| Tim SyteLine | Menyiapkan tabel, IDO, form, logic, API, dan proses posting |
| Tim Finance | Menentukan jurnal, akun, unit code, pajak, dan rekonsiliasi |
| Tim Infrastruktur/Security | Menentukan endpoint, authentication, whitelist, certificate, dan monitoring |
| Support/Operator | Memantau batch, memperbaiki mapping, menjalankan retry |

## Definisi Batch

Satu batch adalah satu kumpulan transaksi yang diterima dalam satu request atau satu proses import. Batch tidak harus identik dengan satu tanggal bisnis.

Contoh:

```text
Batch SMKPOS-20260723-000001
Source       : PIZZAHUT_POS
Outlet       : PH-SBY-001
Period Start : 2026-07-17
Period End   : 2026-07-23
Transactions : 8,450
```

## Prinsip Desain

1. **Staging first** — data tidak langsung memengaruhi tabel core.
2. **Idempotent** — request yang sama tidak boleh menghasilkan posting ganda.
3. **Traceable** — setiap batch dapat ditelusuri sampai request dan referensi SyteLine.
4. **Retryable** — data gagal dapat diproses ulang setelah masalah diperbaiki.
5. **Reconciliable** — total header, detail, payment, dan hasil posting dapat dibandingkan.
6. **Configurable mapping** — kode POS tidak di-hardcode di stored procedure.
7. **Preserve source data** — data asli POS tidak ditimpa oleh hasil mapping.
8. **Server-side business logic** — form hanya mengorkestrasi pemanggilan proses.

## Deliverable Bertahap

1. Data dictionary dan custom tables.
2. IDO dan relasi.
3. Form monitoring dan mapping.
4. Validation procedure.
5. Posting preview.
6. Receive API / IDO Method.
7. Postman test collection.
8. Posting aktual.
9. Runbook, deployment guide, dan test evidence.
