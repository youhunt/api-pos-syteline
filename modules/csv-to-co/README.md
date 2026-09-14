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

### Form one-hit — pilih CSV sampai Blanket CO

Form aktif:

```text
ue_SMK069PosCsvBatchConsole
```

Export form yang sudah ditambah fungsi satu-jalan:

```text
forms/csv-to-co/ue_SMK069PosCsvBatchConsole_CSV_TO_CO_ONE_HIT.XML
```

Tombol baru:

```text
CSV to Blanket CO (One Hit)
```

Orkestrasi event form:

```text
SMK069CsvToCoOneHit
→ SMK069NewCsvBatch
→ SMK069UploadCsv
→ SMK069ParseCsv
→ SMK069RunCsvFullProcess
→ SMK069RunCsvTestBatchSp
→ Blanket Customer Order
```

Tombol ini ditujukan untuk **file CSV baru**: satu klik membuat batch baru, membuka pemilihan/upload CSV, parse, lalu menjalankan proses sampai Customer Order.

Tombol manual lama tetap dipertahankan untuk diagnosis/retry. Caption tombol `Import && Validate` diubah menjadi:

```text
Process to Blanket CO
```

karena event tersebut sekarang memang memanggil `SMK069RunCsvTestBatchSp` dan melanjutkan proses sampai CO.

**Penting untuk retry/idempotency:** batch lama yang aman untuk diproses ulang tidak boleh dipaksa melalui tombol one-hit baru karena tombol tersebut membuat BatchId baru. Pilih batch existing dan gunakan `Process to Blanket CO`.

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

Untuk line Customer Order hasil integrasi, status harus langsung Open:

```text
coitem_mst.stat = O
```

Jangan mengandalkan default schema/tenant untuk `coitem_mst.stat`. `SMK069ProcessCustomerOrderSp` harus menulis `O` secara eksplisit pada saat INSERT.

## Patch 14 — coitem_mst status Open

Tanggal: 14 Sep 2026.

Temuan dari UAT form Blanket Customer Order: line hasil integrasi tampil **Planned** karena procedure `SMK069ProcessCustomerOrderSp` belum menyertakan kolom `coitem_mst.stat` pada INSERT.

Patch deployment:

```text
database/patches/csv-to-co/2026-09-14-smk069-14-coitem-status-open.sql
```

Canonical source:

```text
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
```

Perubahan inti:

```sql
INSERT INTO dbo.coitem_mst
(
    ...,
    matl_cost_conv,
    stat
)
SELECT
    ...,
    ISNULL(i.matl_cost, 0),
    N'O'
```

Patch 14 hanya mengubah default untuk **CO line baru** yang dibuat setelah patch di-apply. Existing line yang sebelumnya sudah tersimpan sebagai Planned tidak diubah massal oleh deployment patch.

## Status UAT terakhir — 14 Sep 2026

Batch sebelumnya yang dipakai:

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

Patch 13 Rev.3 sebelumnya sudah memperbaiki standard Mongoose `SiteRef` pada detail CSV sebelum one-hit. Patch terbaru untuk workstream ini sekarang adalah Patch 14 yang memaksa `coitem_mst.stat = O` saat Customer Order line dibuat.

## Source utama setelah pemisahan repo

```text
database/patches/csv-to-co/
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
database/stored-procedures/csv-to-co/
database/tables/csv-to-co/
extension-classes/csv-to-co/SMKRSCPosIntegrationExtension.cs
forms/csv-to-co/01-SMKRSCPosImportCenter.md
forms/csv-to-co/ue_SMK069PosCsvBatchConsole_CSV_TO_CO_ONE_HIT.XML
ido/csv-to-co/
docs/csv-to-co/
implementation/csv-to-co/
templates/csv-to-co/
```

Dokumen operasional utama:

```text
docs/csv-to-co/30-csv-to-customer-order-one-hit.md
docs/csv-to-co/31-patch13-rerun-uat.md
```

## Aturan tenant SyteLine

- `Apply Database` bukan SSMS. Tulis patch agar dapat dijalankan sebagai satu executable batch dan jangan gunakan `GO`.
- Verification `SELECT` dijalankan terpisah melalui Query Select.
- Jangan menggabungkan beberapa verification query dengan deployment patch bila UI tenant tidak mendukungnya.
- Untuk retry, pertahankan idempotency; jangan membuat BatchId baru hanya untuk mengulang error yang sudah diperbaiki.

## Next test

1. Apply `database/patches/csv-to-co/2026-09-14-smk069-14-coitem-status-open.sql` melalui **Apply Database**.
2. Jalankan CSV baru sampai membentuk Customer Order baru.
3. Query `coitem_mst` untuk Customer Order yang baru dibuat dan pastikan seluruh line memiliki `stat = 'O'`.
4. Buka Customer Order/Blanket Line form dan pastikan Status sudah tampil **Ordered/Open**, bukan Planned.
