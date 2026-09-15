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
```

Patch deployment dibuat satu executable batch dan **tanpa `GO`** untuk tenant Apply Database.

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

Patch 14 memastikan `coitem_mst.stat` ditulis eksplisit `O`.
Patch 17 memastikan `consolidate` ditulis eksplisit `1` pada header dan line baru.
Patch 18 memastikan PO dengan quantity non-multiple ditolak sebelum CO processing.

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
```

## Next UAT

1. Apply Patch 14 bila belum.
2. Apply Patch 15.
3. Apply Patch 16.
4. Apply Patch 17 Rev.6.
5. Apply Patch 18.
6. Test valid quantity via direct JSON/Postman; CO harus tetap terbentuk.
7. Test invalid quantity/multiple; API harus `Success=false`, message `[POS-108]`, dan **tidak ada CO** untuk cust_po itu.
8. Test CSV invalid quantity; batch harus `E` untuk single invalid PO dan result message berisi `[POS-108]`.
9. Verifikasi root invalid line = POS-108, sibling line = POS-203, dan tidak ada temp `V` tersisa untuk rejected PO.
10. Verifikasi target normal tetap `co_mst.type = B`, `co_mst.consolidate = 1`, `coitem_mst.stat = O`, `coitem_mst.consolidate = 1`, dan `co_bln_mst.stat = O`.
