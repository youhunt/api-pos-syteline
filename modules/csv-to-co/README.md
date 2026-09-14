# CSV / POS Inbound → Blanket Customer Order

## Scope

Modul ini hanya menangani inbound POS/CSV sampai menjadi **Blanket Customer Order type `B`** di SyteLine.

Shipment outbound, DN retry, TaskMan Shipment, dan endpoint Shipment berada di workstream `shipment` dan tidak boleh dicampur ke sini kecuali ada dependency nyata yang sedang didiagnosis.

## Arsitektur aktif — 14 Sep 2026

Keputusan terbaru: **single canonical business entry point** adalah:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Flow final:

```text
POS JSON ------------------------------┐
                                       │
CSV -> parsed detail -> build JSON ----┼-> SMK069ReceivePosSalesJsonSp
                                       │          ↓
                                       │   SMK069ReceivePosSalesJsonCoreSp
                                       │          ↓
                                       │   ue_SMK069_temp_sales_mst
                                       │          ↓
                                       │   SMK069ProcessBatchCustomerOrdersSp
                                       │          ↓
                                       └------> SMK069ProcessCustomerOrderSp
                                                  ↓
                                      co_mst + coitem_mst + co_bln_mst
```

### Public JSON/Postman

Gunakan:

```text
SMK069ReceivePosSalesJsonSp
```

Procedure ini sekarang tidak berhenti di Receive/Validate. Bila ada valid rows, procedure melanjutkan proses sampai Customer Order.

Parameter 1–10 tetap sama untuk backward compatibility. Patch 15 hanya append parameter defaulted:

```text
11 ProcessedOrders OUT
12 ProcessErrors OUT
13 CreatedCoNums OUT
14 ThrowOnBusinessError = 1
```

Default `ThrowOnBusinessError = 1` menjaga behavior public API lama: business failure tetap `THROW 51069` / `Success=false`.

### CSV

CSV tetap masuk melalui:

```text
SMK069RunCsvTestBatchSp
```

Tetapi mulai Patch 16 procedure ini **tidak lagi** memanggil Receive Core dan Process Batch secara langsung.

Tanggung jawab CSV wrapper sekarang hanya:

```text
parsed CSV detail
→ normalize SiteRef
→ build POS PayloadJson
→ SMK069ReceivePosSalesJsonSp (@ThrowOnBusinessError = 0)
→ persist CSV batch/detail result
```

Jadi Receive/Validate/Process-to-CO hanya memiliki satu business engine.

## Deployment terbaru

Apply Database dengan urutan:

```text
1. database/patches/csv-to-co/2026-09-14-smk069-14-coitem-status-open.sql
   (jika belum terpasang)

2. database/patches/csv-to-co/2026-09-14-smk069-15-canonical-receive-to-co.sql

3. database/patches/csv-to-co/2026-09-14-smk069-16-route-csv-through-public-receive.sql

4. database/patches/csv-to-co/2026-09-14-smk069-17-consolidate-header-and-line.sql
   (gunakan Rev.5 terbaru)
```

Patch deployment dibuat satu executable batch dan **tanpa `GO`** untuk tenant Apply Database.

Patch 17 Rev.5 memakai field tenant yang sudah dikonfirmasi:

```text
co_mst.consolidate      tinyint
coitem_mst.consolidate  tinyint
```

Rev.5 juga memperbaiki normalisasi header `SMK069ProcessCustomerOrderSp` agar tahan terhadap whitespace/tab/line-break pada `OBJECT_DEFINITION` tenant. Error Rev.4 yang berbunyi `Keyword header CREATE/ALTER PROC/PROCEDURE tidak ditemukan` tidak boleh lagi ditangani dengan exact phrase matching.

## Canonical source

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
```

Shared process loop:

```text
database/patches/csv-to-co/2026-09-04-smk069-01-create-process-batch-customer-orders.sql
```

## Target result

Header:

```text
co_mst.type        = B
co_mst.consolidate = 1
```

CO line:

```text
coitem_mst.stat        = O
coitem_mst.consolidate = 1
```

Blanket line:

```text
co_bln_mst.stat = O
co_bln_mst.allow_on_pick_list = 0
```

Patch 14 memastikan `coitem_mst.stat` ditulis eksplisit `O`; jangan mengandalkan default tenant.

Patch 17 memastikan `consolidate` ditulis eksplisit `1` pada header dan line baru.

## Partial success

`SMK069ReceivePosSalesJsonSp` memproses valid rows selama:

```text
TransferredRows > 0
```

Sehingga satu invalid order tidak lagi membuat valid order yang sudah masuk temp tertahan di `V`.

Public/API default tetap dapat mengembalikan business failure setelah valid rows selesai diproses agar contract integrator tidak berubah.

CSV memakai `ThrowOnBusinessError = 0` supaya counts tetap bisa diterima dan batch dapat disimpan sebagai:

```text
C = complete
P = partial
E = failed/nothing landed
R = running
```

## Transaction rule

IDO method yang menjalankan proses ini harus:

```text
Transactional = False
```

`SMK069ProcessCustomerOrderSp` memiliki transaction per order sendiri.

## Retry/idempotency

- Retry aman memakai **BatchId yang sama** bila sumber batch tidak berubah.
- Jangan membuat batch baru hanya untuk mengulang error yang sudah diperbaiki.
- `SMK069ProcessBatchCustomerOrdersSp` hanya memproses temp order `V/E`.
- Temp order yang sudah `P` di-skip.
- `SMK069ProcessCustomerOrderSp` tetap idempotent melalui existing Customer Order lookup.

## Legacy compatibility

Procedure berikut belum dihapus agar caller lama tidak putus:

```text
SMK069ReceiveAndProcessPosSalesJsonSp
```

Namun **jangan gunakan sebagai entry point baru**. Development baru harus menuju:

```text
SMK069ReceivePosSalesJsonSp
```

## Form CSV

Form tenant tetap dapat memakai `SMK069RunCsvTestBatchSp` untuk tombol `Process to Blanket CO` / alur CSV-to-CO.

Percobaan export form one-hit yang nested file picker sebelumnya sudah ditarik dari repository karena Web Client menghasilkan error `primaryaction ... choices`. Jangan gunakan export one-hit lama dari repo sebagai source aktif.

## Dokumentasi operasional

```text
docs/csv-to-co/30-csv-to-customer-order-one-hit.md
docs/csv-to-co/31-patch13-rerun-uat.md
docs/csv-to-co/32-canonical-receive-pos-sales-json-to-co.md
docs/csv-to-co/33-consolidated-flag.md
```

Dokumen `32-...` adalah handoff utama untuk Patch 15–16. Dokumen `33-...` mencatat requirement `consolidate = 1` dan histori Patch 17 sampai Rev.5.

## Next UAT

1. Apply Patch 14 bila belum.
2. Apply Patch 15.
3. Apply Patch 16.
4. Apply Patch 17 Rev.5.
5. Test direct JSON/Postman menggunakan **`SMK069ReceivePosSalesJsonSp`** dengan BatchId baru; pastikan CO langsung terbentuk.
6. Test CSV baru melalui `SMK069RunCsvTestBatchSp`; pastikan result menunjukkan `ProcessedOrders`, `ProcessErrors`, dan `CreatedCoNums`.
7. Verifikasi `co_mst`, `coitem_mst`, dan `co_bln_mst`.
8. Pastikan `co_mst.type = B`, `co_mst.consolidate = 1`, `coitem_mst.stat = O`, `coitem_mst.consolidate = 1`, dan `co_bln_mst.stat = O`.
