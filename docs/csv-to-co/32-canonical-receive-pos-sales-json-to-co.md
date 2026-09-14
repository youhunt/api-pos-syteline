# Patch 15–16 — `SMK069ReceivePosSalesJsonSp` sebagai Canonical CSV/POS → Blanket CO

Tanggal: 14 Sep 2026

## Keputusan arsitektur

Entry point bisnis utama sekarang adalah:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Target flow:

```text
POS JSON ------------------------------┐
                                       │
CSV -> parsed detail -> build JSON ----┼-> SMK069ReceivePosSalesJsonSp
                                       │          |
                                       │          v
                                       │   SMK069ReceivePosSalesJsonCoreSp
                                       │          |
                                       │          v
                                       │   ue_SMK069_temp_sales_mst
                                       │          |
                                       │          v
                                       │   SMK069ProcessBatchCustomerOrdersSp
                                       │          |
                                       │          v
                                       └------> SMK069ProcessCustomerOrderSp
                                                  |
                                                  v
                                      co_mst + coitem_mst + co_bln_mst
```

CSV tidak lagi memiliki orchestration Receive Core + Process Batch sendiri. `SMK069RunCsvTestBatchSp` hanya melakukan preflight CSV, normalisasi `SiteRef`, membentuk payload JSON, memanggil `SMK069ReceivePosSalesJsonSp`, lalu menyimpan hasil ke batch/detail CSV.

## Patch deployment

Apply melalui **Apply Database** dengan urutan:

```text
1. database/patches/csv-to-co/2026-09-14-smk069-15-canonical-receive-to-co.sql
2. database/patches/csv-to-co/2026-09-14-smk069-16-route-csv-through-public-receive.sql
```

Jika Patch 14 status line belum diterapkan, apply lebih dulu:

```text
database/patches/csv-to-co/2026-09-14-smk069-14-coitem-status-open.sql
```

Semua deployment patch di atas adalah satu executable batch dan tidak menggunakan `GO`.

## Compatibility `SMK069ReceivePosSalesJsonSp`

Parameter 1–10 dipertahankan pada posisi lama:

```text
1  SourceSystem
2  BatchId
3  PayloadJson
4  ReceivedBy
5  ReceivedRows OUT
6  TotalOrders OUT
7  ValidOrders OUT
8  ErrorOrders OUT
9  TransferredRows OUT
10 Infobar OUT
```

Patch 15 menambahkan parameter defaulted:

```text
11 ProcessedOrders OUT
12 ProcessErrors OUT
13 CreatedCoNums OUT
14 ThrowOnBusinessError = 1
```

Karena semuanya ditambahkan di belakang dengan default, IDO/Postman lama yang masih mengirim 10 parameter tidak perlu langsung diubah.

Default `ThrowOnBusinessError = 1` menjaga perilaku public API lama: business error tetap `THROW 51069` / `Success=false`.

CSV memanggil procedure yang sama dengan:

```text
ThrowOnBusinessError = 0
```

agar wrapper CSV tetap memperoleh counts dan dapat menyimpan status `C/P/E`.

## Partial success

Valid order tidak boleh tertahan hanya karena order lain gagal validasi.

Patch 15 menjalankan `SMK069ProcessBatchCustomerOrdersSp` selama:

```text
TransferredRows > 0
```

Dengan demikian valid rows tetap lanjut menjadi CO. Untuk public API default, hasil keseluruhan tetap dapat dikembalikan sebagai business error agar contract integrator tidak berubah. Untuk CSV, partial result dikembalikan sebagai counts/Infobar dan batch diberi status `P`.

## IDO transaction setting

Method yang memanggil proses ini harus tetap:

```text
Transactional = False
```

`SMK069ProcessCustomerOrderSp` memiliki transaction per order sendiri.

## UAT 1 — direct JSON lama

Gunakan IDO method `SMK069ReceivePosSalesJsonSp` dengan kontrak 10 parameter lama dan **BatchId baru**.

Expected untuk payload valid:

```text
Success = true
ReturnValue = 0
TransferredRows > 0
Infobar mengandung ProcessedOrders=...
Blanket CO terbentuk
```

Verifikasi target:

```sql
SELECT site_ref, co_num, type, cust_num, cust_po, order_date, whse
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po = N'<SOURCE_CUST_PO>';
```

Required:

```text
type = B
```

## UAT 2 — CSV melalui procedure yang sama

Upload/parse CSV seperti biasa, lalu jalankan `SMK069RunCsvTestBatchSp`.

Expected clean success:

```text
ReturnValue           = 0
ValidationErrorOrders = 0
ProcessErrorOrders    = 0
ProcessedOrders       >= 1
CreatedCoNums         terisi untuk CO baru
batch_status          = C
```

`SMK069RunCsvTestBatchSp` pada Patch 16 harus hanya memiliki satu canonical call:

```text
EXEC dbo.SMK069ReceivePosSalesJsonSp ... @ThrowOnBusinessError = 0
```

Tidak boleh lagi ada direct call CSV ke:

```text
SMK069ReceivePosSalesJsonCoreSp
SMK069ProcessBatchCustomerOrdersSp
```

## UAT 3 — target tables

Untuk setiap CO baru:

```sql
SELECT site_ref, co_num, type, cust_num, cust_po
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>';
```

```sql
SELECT site_ref, co_num, co_line, item, qty_ordered, u_m, whse, stat
FROM dbo.coitem_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>'
ORDER BY co_line;
```

```sql
SELECT site_ref, co_num, co_line, item, blanket_qty, u_m, stat, whse, allow_on_pick_list
FROM dbo.co_bln_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>'
ORDER BY co_line;
```

Required:

```text
co_mst.type = B
coitem_mst.stat = O
co_bln_mst.stat = O
co_bln_mst.allow_on_pick_list = 0
```

## Retry/idempotency

Gunakan BatchId yang sama untuk retry bila batch tersebut masih aman. Jangan membuat batch baru hanya untuk mengulang kegagalan yang sudah diperbaiki.

`SMK069ProcessBatchCustomerOrdersSp` hanya mengambil temp order yang masih `V/E`; order yang sudah `P` di-skip.

## Legacy procedure

`SMK069ReceiveAndProcessPosSalesJsonSp` belum dihapus pada Patch 15–16 untuk menjaga kompatibilitas caller lama. Namun untuk development baru, canonical path adalah `SMK069ReceivePosSalesJsonSp`.
