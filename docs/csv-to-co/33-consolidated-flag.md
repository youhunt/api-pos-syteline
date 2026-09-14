# Patch 17 — consolidate = 1 pada Customer Order header dan line

Tanggal: 14 September 2026

## Tenant finding

Query Select tenant mengonfirmasi field yang benar adalah:

```text
co_mst.consolidate      tinyint
coitem_mst.consolidate  tinyint
```

Jadi requirement tenant menggunakan `consolidate`, bukan `consolidated`.

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

File lama dengan nama `...consolidated-header-and-line.sql` sudah ditarik dari `main` agar tidak salah dipakai lagi.

## Revision history

### Rev.2

Memperbaiki error Apply Database:

```text
The data types bit and bit are incompatible in the add operator.
```

Guard partial-state sekarang mengubah BIT ke INT sebelum penjumlahan.

### Rev.3

Mengganti field yang salah `consolidated` menjadi tenant-confirmed field `consolidate`.

### Rev.4

Apply Database berikutnya berhenti pada:

```text
[PATCH-17] Header procedure tidak dapat dinormalisasi menjadi ALTER PROCEDURE.::211
```

Penyebabnya adalah normalisasi header procedure terlalu bergantung pada string object persis `dbo.SMK069ProcessCustomerOrderSp`. Definisi module tenant dapat menggunakan bracket atau variasi keyword, misalnya:

```text
ALTER PROCEDURE [dbo].[SMK069ProcessCustomerOrderSp]
ALTER PROC [dbo].[SMK069ProcessCustomerOrderSp]
CREATE PROCEDURE [dbo].[SMK069ProcessCustomerOrderSp]
```

Rev.4 hanya menormalisasi bagian keyword `CREATE/ALTER PROC/PROCEDURE` menjadi `ALTER PROCEDURE` dan tidak lagi bergantung pada format schema/object name. Patch tetap memverifikasi bahwa module definition mengandung `SMK069ProcessCustomerOrderSp` sebelum dieksekusi.

Patch Rev.4:

- memakai field `consolidate`;
- tetap membawa fix BIT + BIT;
- menerima CREATE/ALTER, PROC/PROCEDURE, dan bracketed object name;
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
co_mst.type             = B
co_mst.consolidate      = 1
coitem_mst.stat         = O
coitem_mst.consolidate  = 1
```
