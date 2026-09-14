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

Apply Database berhenti pada:

```text
[PATCH-17] Header procedure tidak dapat dinormalisasi menjadi ALTER PROCEDURE.::211
```

Rev.4 menghapus ketergantungan pada object name persis dan mencoba mengenali variasi CREATE/ALTER + PROC/PROCEDURE.

Namun tenant berikutnya menghasilkan:

```text
[PATCH-17] Keyword header CREATE/ALTER PROC/PROCEDURE tidak ditemukan pada module definition.::240
```

Ini menunjukkan `OBJECT_DEFINITION` tenant memiliki whitespace/tab/line-break di antara keyword sehingga pencarian phrase persis masih terlalu ketat.

### Rev.5

Rev.5 tidak lagi mencari phrase persis seperti `CREATE PROCEDURE` atau `ALTER PROC`.

Normalisasi dilakukan secara struktural:

1. menemukan parameter pertama `@SiteRef`;
2. mencari token `PROCEDURE`/`PROC` terdekat sebelum parameter tersebut;
3. mencari `CREATE`/`ALTER` dalam window header sebelum token procedure;
4. jika bentuknya `CREATE OR ALTER`, seluruh sequence dinormalisasi;
5. mengganti hanya bagian declaration keyword menjadi `ALTER PROCEDURE`.

Dengan pendekatan ini variasi berikut tetap didukung:

```text
CREATE OR ALTER PROCEDURE dbo.X
CREATE OR ALTER\nPROCEDURE [dbo].[X]
CREATE\tPROC [dbo].[X]
ALTER\nPROCEDURE dbo.X
ALTER PROC [dbo].[X]
```

Patch Rev.5 tetap:

- memakai field `consolidate`;
- membawa fix BIT + BIT;
- memeriksa `co_mst.consolidate` dan `coitem_mst.consolidate` sebelum ALTER procedure;
- tidak mengubah procedure jika state source ambiguous/partial;
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
