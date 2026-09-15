# CSV / POS Inbound → Blanket Customer Order

## Scope

Modul ini hanya menangani inbound POS/CSV sampai menjadi **Blanket Customer Order type `B`** di SyteLine.

Shipment outbound, DN retry, TaskMan Shipment, dan endpoint Shipment berada di workstream `shipment` dan tidak boleh dicampur ke sini kecuali ada dependency nyata yang sedang didiagnosis.

## Arsitektur aktif — 15 Sep 2026

Single canonical business entry point:

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
                                       │   quantity multiple validation
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

Procedure ini menerima/validasi lalu melanjutkan sampai Customer Order untuk PO yang valid.

Parameter 1–10 tetap sama untuk backward compatibility. Patch 15 append parameter defaulted:

```text
11 ProcessedOrders OUT
12 ProcessErrors OUT
13 CreatedCoNums OUT
14 ThrowOnBusinessError = 1
```

Default `ThrowOnBusinessError = 1` menjaga behavior public API: business failure tetap `THROW 51069` / `Success=false`.

### CSV

CSV tetap masuk melalui:

```text
SMK069RunCsvTestBatchSp
```

Mulai Patch 16 procedure ini tidak lagi memanggil Receive Core dan Process Batch secara langsung.

Tanggung jawab CSV wrapper:

```text
parsed CSV detail
→ normalize SiteRef
→ build POS PayloadJson
→ SMK069ReceivePosSalesJsonSp (@ThrowOnBusinessError = 0)
→ persist CSV batch/detail result
```

## Quantity multiple rule — Patch 18

Business rule terbaru: **PO harus ditolak bila quantity setelah dikonversi ke base U/M tidak merupakan bilangan bulat/kelipatan yang valid**.

Formula tenant/business:

```text
SMK030_UomConvQty2(
    qty_ordered,
    Getumcf(u_m, mapped item, '', ''),
    'To Base'
)
```

Invalid when:

```text
converted_base_qty <> FLOOR(converted_base_qty)
```

Result:

```text
root offending line -> [POS-108] Quantity tidak sesuai kelipatan U/M.
sibling same cust_po -> [POS-203] Order ditolak karena terdapat line lain yang tidak valid.
```

Granularity tetap **per `cust_po`**. Satu invalid line menolak seluruh PO sebelum CO dibuat.

Current POS operational assumption: satu API hit mengirim satu PO. Jadi POS-108 berarti API hit tersebut gagal dan tidak ada Customer Order yang dibuat.

Jika kelak satu hit berisi beberapa PO, PO valid tetap dapat menjadi CO sedangkan PO invalid ditolak; response public API tetap business failure/partial sesuai contract invocation-level yang sekarang.

## Tenant incident 15 Sep 2026 — missing batch processor

Pada UAT setelah Patch 18, request PO dengan quantity valid melewati quantity validation tetapi gagal saat masuk tahap CO dengan response:

```text
Could not find stored procedure 'dbo.SMK069ProcessBatchCustomerOrdersSp'.
```

Fix deployment:

```text
database/patches/csv-to-co/2026-09-15-smk069-19-ensure-process-batch-customer-orders.sql
```

Patch 19 menggunakan `CREATE OR ALTER PROCEDURE`, satu executable batch dan tanpa `GO`. Tidak ada perubahan IDO/API signature.

## Auto CO silent no-op hardening — Patch 20

Audit source menemukan gap berikut pada `SMK069ProcessBatchCustomerOrdersSp`:

```text
Receive/Validate transferred rows > 0
mapping view tidak menghasilkan order dengan co_num
→ ProcessedOrders = 0
→ ProcessErrors   = 0
→ SkippedOrders   = 0
→ caller dapat terlihat sukses walaupun CO tidak dibuat
```

ProcessBatch bergantung pada:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

untuk mendapatkan `SiteRef + source_system + batch_id + co_num + cust_seq`, kemudian mencocokkan `co_num` tersebut dengan staging `ue_SMK069_temp_sales_mst` berstatus `V/E`.

Patch 20 mengubah zero-order mapping menjadi explicit error:

```text
POS-302 = Auto CO tidak menemukan order mapping untuk batch
```

Deployment:

```text
database/patches/csv-to-co/2026-09-15-smk069-20-fail-when-batch-has-no-co-mapping.sql
```

Diagnostic gate:

```text
docs/csv-to-co/35-auto-co-not-running-diagnostic.md
```

Patch 20 **tidak menebak atau memalsukan mapping**. Jika POS-302 muncul, perbaikan selanjutnya harus berdasarkan isi mapping view dan row temp aktual pada batch tersebut.

## Deployment terbaru

Apply Database dengan urutan:

```text
1. database/patches/csv-to-co/2026-09-14-smk069-14-coitem-status-open.sql
   (jika belum terpasang)

2. database/patches/csv-to-co/2026-09-14-smk069-15-canonical-receive-to-co.sql

3. database/patches/csv-to-co/2026-09-14-smk069-16-route-csv-through-public-receive.sql

4. database/patches/csv-to-co/2026-09-14-smk069-17-consolidate-header-and-line.sql
   (gunakan Rev.6 terbaru)

5. database/patches/csv-to-co/2026-09-15-smk069-18-reject-non-multiple-qty-per-po.sql

6. database/patches/csv-to-co/2026-09-15-smk069-19-ensure-process-batch-customer-orders.sql
   (wajib untuk tenant yang belum memiliki SMK069ProcessBatchCustomerOrdersSp)

7. database/patches/csv-to-co/2026-09-15-smk069-20-fail-when-batch-has-no-co-mapping.sql
```

Patch deployment aktif dibuat satu executable batch dan **tanpa `GO`** untuk tenant Apply Database.

Patch 17 memakai field tenant yang sudah dikonfirmasi:

```text
co_mst.consolidate      tinyint
coitem_mst.consolidate  tinyint
```

Header `SMK069ProcessCustomerOrderSp` yang dikonfirmasi langsung dari tenant adalah:

```sql
CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp
```

Rev.6 menormalisasikan header tersebut menjadi `ALTER PROCEDURE` sebelum memasang `consolidate = 1`.

## Canonical source

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
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

Patch 14 memastikan `coitem_mst.stat` ditulis eksplisit `O`.
Patch 17 memastikan `consolidate` ditulis eksplisit `1` pada header dan line baru.
Patch 18 memastikan PO dengan quantity non-multiple ditolak sebelum CO processing.
Patch 19 memastikan shared batch CO processor tersedia di tenant.
Patch 20 memastikan missing batch/order mapping tidak lagi gagal diam-diam.

## Partial success

`SMK069ReceivePosSalesJsonSp` memproses PO valid selama masih ada `TransferredRows > 0`.

Public/API default tetap dapat mengembalikan business failure setelah PO valid selesai diproses agar contract integrator tidak berubah.

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

- Retry aman memakai **BatchId yang sama** untuk process error/master-data correction yang tidak mengubah source payload.
- Untuk **POS-108 quantity source salah**, kirim quantity yang sudah diperbaiki sebagai **batch/request baru**.
- Jangan membuat batch baru hanya untuk mengulang process error yang source-nya tidak berubah.
- `SMK069ProcessBatchCustomerOrdersSp` hanya memproses temp order `V/E`.
- Temp order yang sudah `P` di-skip.
- `SMK069ProcessCustomerOrderSp` tetap idempotent melalui existing Customer Order lookup.

## Legacy compatibility

Procedure berikut belum dihapus agar caller lama tidak putus:

```text
SMK069ReceiveAndProcessPosSalesJsonSp
```

Namun jangan gunakan sebagai entry point baru. Development baru harus menuju:

```text
SMK069ReceivePosSalesJsonSp
```

## Form CSV

Form tenant tetap dapat memakai `SMK069RunCsvTestBatchSp` untuk tombol `Retry / Process CO` / alur CSV-to-CO.

Quantity rule Patch 18 berada di canonical receive procedure, sehingga form CSV tidak memerlukan event baru untuk memakai POS-108.

## Dokumentasi operasional

```text
docs/csv-to-co/30-csv-to-customer-order-one-hit.md
docs/csv-to-co/31-patch13-rerun-uat.md
docs/csv-to-co/32-canonical-receive-pos-sales-json-to-co.md
docs/csv-to-co/33-consolidated-flag.md
docs/csv-to-co/34-pos-108-qty-multiple-rejection.md
docs/csv-to-co/35-auto-co-not-running-diagnostic.md
```

## Next UAT

1. Pastikan Patch 19 sudah sukses dan `OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp', N'P')` NOT NULL.
2. Apply Patch 20.
3. Hit ulang satu PO dengan quantity valid menggunakan BatchId yang aman/retryable.
4. Jika keluar `[POS-302]`, Query Select mapping view untuk BatchId yang sama; kirim hasil mapping view + temp rows sebelum patch berikutnya.
5. Jika mapping ada dan temp `V/E`, ProcessCustomerOrderSp harus dipanggil; gunakan `ProcessDetail` sebagai error berikutnya bila gagal.
6. Test quantity invalid: API harus `Success=false`, `[POS-108]`, tanpa CO.
7. Verifikasi target normal: `co_mst.type = B`, `co_mst.consolidate = 1`, `coitem_mst.stat = O`, `coitem_mst.consolidate = 1`, `co_bln_mst.stat = O`.
