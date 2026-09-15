# Auto CO belum jalan — diagnostic gate

Tanggal: 2026-09-15

Gunakan dokumen ini ketika `SMK069ReceivePosSalesJsonSp` menerima request valid tetapi Blanket CO belum terbentuk.

## 1. Object readiness

Jalankan di Query Select:

```sql
SELECT
    OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp', N'P')         AS ReceiveSp,
    OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'P')     AS ReceiveCoreSp,
    OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp', N'P') AS ProcessBatchSp,
    OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp', N'P')        AS ProcessOrderSp,
    OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'V') AS MappingView,
    OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U')     AS InboundTable,
    OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U')            AS TempTable;
```

Semua harus NOT NULL.

## 2. Recent inbound result

```sql
SELECT TOP (30)
    i.SiteRef,
    i.source_system,
    i.batch_id,
    i.row_no,
    i.cust_po,
    i.item,
    i.qty_ordered,
    i.u_m,
    i.inbound_status,
    i.validation_msg,
    i.RecordDate
FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
WHERE i.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
ORDER BY i.RecordDate DESC, i.row_no DESC;
```

Untuk PO valid, setelah Core row harus sempat berada pada `inbound_status = 'T'`.

## 3. Mapping view — gate utama ProcessBatch

Ganti `<BATCH_ID>` dengan BatchId request API yang baru dites.

```sql
SELECT *
FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
WHERE v.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND v.batch_id = N'<BATCH_ID>'
ORDER BY v.co_num;
```

`SMK069ProcessBatchCustomerOrdersSp` hanya menemukan order bila view ini mengembalikan row dengan `co_num` tidak kosong.

Jika query ini 0 row atau `co_num` NULL/kosong sementara inbound valid, auto CO sebelumnya dapat menjadi silent no-op. Patch 20 mengubah kondisi ini menjadi `[POS-302]` supaya tidak lagi terlihat sebagai success tanpa CO.

## 4. Temp/staging

Ambil `co_num` dari mapping view lalu cek:

```sql
SELECT
    t.SiteRef,
    t.co_num,
    t.co_line,
    t.cust_num,
    t.cust_po,
    t.item,
    t.qty_ordered,
    t.u_m,
    t.process_status,
    t.validation_msg,
    t.error_msg,
    t.retry_count,
    t.RecordDate
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.co_num = N'<SOURCE_CO_NUM>'
ORDER BY t.co_line;
```

Interpretasi:

```text
V = siap diproses ke CO
E = pernah gagal proses dan boleh diretry setelah root cause diperbaiki
P = sudah diproses / CO seharusnya sudah ada
C = cancelled
```

## 5. Target CO lookup

Karena source/POS `co_num` disimpan ke `co_mst.cust_po`, cek:

```sql
SELECT
    c.site_ref,
    c.co_num,
    c.type,
    c.cust_num,
    c.cust_po,
    c.consolidate
FROM dbo.co_mst AS c
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.cust_po = N'<SOURCE_CO_NUM>';
```

Jika temp sudah `P` tetapi query ini kosong, itu adalah defect/idempotency mismatch yang harus ditelusuri di `SMK069ProcessCustomerOrderSp`.

## Patch 20

Apply Database:

```text
database/patches/csv-to-co/2026-09-15-smk069-20-fail-when-batch-has-no-co-mapping.sql
```

Patch ini tidak memperbaiki mapping data secara spekulatif. Ia memastikan kondisi `TransferredRows > 0` tetapi batch tidak mempunyai mapping order tidak lagi berakhir `ProcessedOrders=0 / ProcessErrors=0` secara diam-diam.

Expected diagnostic response bila mapping kosong:

```text
[POS-302] Auto CO tidak menemukan order mapping untuk batch ...
```

Setelah POS-302 muncul, perbaikan berikutnya harus berdasarkan output Mapping View dan Temp di atas, bukan membuat batch baru tanpa root cause.
