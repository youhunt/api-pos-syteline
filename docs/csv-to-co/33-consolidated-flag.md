# Patch 17 — consolidate = 1 pada Customer Order header dan line

Tanggal: 14 September 2026

## Tenant finding

Apply Database membuktikan bahwa field `dbo.co_mst.consolidated` tidak ada. Requirement tenant menggunakan nama field:

```text
co_mst.consolidate
coitem_mst.consolidate
```

Karena itu Patch 17 Rev.3 menggunakan `consolidate`, bukan `consolidated`.

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

Gunakan file Rev.3:

```text
database/patches/csv-to-co/2026-09-14-smk069-17-consolidate-header-and-line.sql
```

File lama dengan nama `...consolidated-header-and-line.sql` sudah ditarik dari `main` agar tidak salah dipakai lagi.

Patch Rev.3:

- memakai field `consolidate`;
- tetap membawa perbaikan Rev.2 untuk operasi BIT + BIT dengan `CONVERT(INT, ...)`;
- memeriksa `co_mst.consolidate` dan `coitem_mst.consolidate` sebelum ALTER procedure;
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
co_mst.type        = B
co_mst.consolidate = 1
coitem_mst.stat    = O
coitem_mst.consolidate = 1
```

Jika Apply Database berhenti pada `[PATCH-17] Kolom dbo.coitem_mst.consolidate tidak ditemukan`, jangan memaksa ALTER. Itu berarti nama field line berbeda dan harus diverifikasi dari schema tenant terlebih dahulu.
