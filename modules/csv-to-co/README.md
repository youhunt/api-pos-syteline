# CSV / POS Inbound → Blanket Customer Order

## Scope

Modul ini hanya menangani data inbound POS/CSV sampai menjadi **Blanket Customer Order type `B`** di SyteLine.

```text
CSV / POS JSON
→ Receive / Validate
→ ue_SMK069_temp_sales_mst
→ SMK069ProcessBatchCustomerOrdersSp
→ SMK069ProcessCustomerOrderSp
→ co_mst + coitem_mst + co_bln_mst
```

Shipment outbound, endpoint POS Shipment, DN retry queue, dan TaskMan Shipment berada di modul `shipment` dan tidak boleh dibawa ke sini kecuali ada dependency nyata yang sedang didiagnosis.

## Entry point aktif

### JSON / Postman one-hit

```text
SMK069ReceiveAndProcessPosSalesJsonSp
```

Digunakan ketika satu request JSON harus lanjut dari Receive/Validate sampai Customer Order processing.

### CSV one-hit

```text
SMK069RunCsvTestBatchSp
```

CSV harus sudah di-upload/parsing ke tabel batch/detail. Procedure ini melanjutkan detail yang sudah ada ke Receive Core lalu proses Customer Order.

## Hasil akhir

Customer Order yang dibuat adalah:

```text
co_mst.type = B
```

Verifikasi pada tiga tabel:

```text
co_mst
coitem_mst
co_bln_mst
```

## Status UAT terakhir — 9 Sep 2026

Batch yang sedang dipakai:

```text
CSV-20260909-072038-835E3D
```

Detail hasil parse:

```text
Row 1: DEV4 | cust_po DEV4-216 | PLG | AC20002B | 375 PCS
Row 2: DEV4 | cust_po DEV4-216 | PLG | AC20003B | 120 PCS
```

Parser sudah menghasilkan:

```text
Rows=2, FormatErrors=0
```

Sebelumnya one-hit mengembalikan:

```text
[POS-402] Batch CSV belum memiliki detail transaksi.
```

Akar masalahnya adalah standard Mongoose `SiteRef` pada detail, bukan business field CSV `siteref`. `siteref` boleh kosong jika CSV tidak mengirim field site.

Patch terakhir:

```text
database/patches/csv-to-co/2026-09-09-smk069-13-fix-csv-detail-siteref-before-one-hit.sql
```

Patch 13 Rev.3 sudah berhasil di-apply di tenant. Batch yang sama **boleh langsung dijalankan ulang**. Tidak perlu New Batch atau Re-Parse selama file CSV tidak berubah.

## Source utama setelah pemisahan repo

```text
database/patches/csv-to-co/
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
database/stored-procedures/csv-to-co/
database/tables/csv-to-co/
extension-classes/csv-to-co/SMKRSCPosIntegrationExtension.cs
forms/csv-to-co/01-SMKRSCPosImportCenter.md
ido/csv-to-co/
docs/csv-to-co/
implementation/csv-to-co/
templates/csv-to-co/
```

Dokumen operasional utama:

```text
docs/csv-to-co/30-csv-to-customer-order-one-hit.md
```

## Aturan tenant SyteLine

- `Apply Database` bukan SSMS. Tulis patch agar dapat dijalankan sebagai satu executable batch dan jangan gunakan `GO`.
- Verification `SELECT` dijalankan terpisah melalui Query Select.
- Jangan menggabungkan beberapa verification query dengan deployment patch bila UI tenant tidak mendukungnya.
- Untuk retry, pertahankan idempotency; jangan membuat BatchId baru hanya untuk mengulang error yang sudah diperbaiki.

## Next test

Lanjutkan batch `CSV-20260909-072038-835E3D` melalui one-hit CSV → CO, lalu periksa `CreatedCoNums` dan ketiga tabel Blanket CO.
