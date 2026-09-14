# Patch 17 — consolidate = 1 pada Customer Order header dan line

Tanggal: 14 September 2026

## Tenant finding

Query Select tenant mengonfirmasi field yang benar adalah:

```text
co_mst.consolidate      tinyint
coitem_mst.consolidate  tinyint
```

Jadi requirement tenant menggunakan `consolidate`, bukan `consolidated`.

Query Select `OBJECT_DEFINITION` juga mengonfirmasi header procedure tenant yang sebenarnya:

```sql
CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp
```

Perhatikan ada **tiga spasi** antara `CREATE` dan `PROCEDURE`.

## Requirement

Untuk setiap Blanket Customer Order yang dibuat melalui alur POS/CSV:

```text
co_mst.consolidate     = 1
coitem_mst.consolidate = 1
```

Source processor:

```text
dbo.SMK069ProcessCustomerOrderSp
```

## Deployment

Gunakan file terbaru:

```text
database/patches/csv-to-co/2026-09-14-smk069-17-consolidate-header-and-line.sql
```

File lama dengan nama `...consolidated-header-and-line.sql` sudah ditarik dari `main`.

## Revision history

### Rev.2

Memperbaiki error Apply Database:

```text
The data types bit and bit are incompatible in the add operator.
```

Guard partial-state mengubah BIT ke INT sebelum penjumlahan.

### Rev.3

Mengganti field salah `consolidated` menjadi tenant-confirmed field `consolidate`.

### Rev.4

Header normalization masih terlalu bergantung pada phrase `CREATE/ALTER PROC/PROCEDURE`.

### Rev.5

Mencoba parsing struktural header berdasarkan `@SiteRef`, `PROC/PROCEDURE`, dan `CREATE/ALTER`.

### Rev.6

Setelah header aktual tenant diambil langsung dari `OBJECT_DEFINITION`, tidak ada lagi alasan untuk menebak format header.

Rev.6 memakai exact tenant-confirmed header:

```sql
CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp
```

Patch mensyaratkan header tersebut muncul tepat satu kali, kemudian menggantinya menjadi:

```sql
ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
```

Setelah itu definition yang sudah ditambah `consolidate = 1` dijalankan.

Rev.6 tetap:

- memeriksa `co_mst.consolidate` dan `coitem_mst.consolidate`;
- membawa fix BIT + BIT;
- menolak source match yang ambiguous/partial;
- satu executable batch;
- tanpa `GO`;
- tidak melakukan mass update transaksi lama.

## Expected mapping

```text
co_mst.type            = B
co_mst.consolidate     = 1

coitem_mst.stat        = O
coitem_mst.consolidate = 1
```

## Verification — Query Select

Header:

```sql
SELECT
    site_ref,
    co_num,
    type,
    cust_num,
    cust_po,
    consolidate
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>';
```

Line:

```sql
SELECT
    site_ref,
    co_num,
    co_line,
    item,
    qty_ordered,
    stat,
    consolidate
FROM dbo.coitem_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>'
ORDER BY co_line;
```

Expected:

```text
co_mst.type             = B
co_mst.consolidate      = 1
coitem_mst.stat         = O
coitem_mst.consolidate  = 1
```
