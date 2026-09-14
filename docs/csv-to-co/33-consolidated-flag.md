# Patch 17 — consolidated = 1 pada Customer Order header dan line

Tanggal: 14 September 2026

## Requirement

Untuk setiap Blanket Customer Order yang dibuat melalui alur POS/CSV, field berikut wajib bernilai `1`:

```text
co_mst.consolidated     = 1
coitem_mst.consolidated = 1
```

Source processor yang membuat header dan line adalah:

```text
dbo.SMK069ProcessCustomerOrderSp
```

Sebelum Patch 17, INSERT ke `co_mst` dan `coitem_mst` belum menulis `consolidated` secara eksplisit sehingga nilai mengikuti default tenant.

## Deployment

Apply Database:

```text
database/patches/csv-to-co/2026-09-14-smk069-17-consolidated-header-and-line.sql
```

Patch sengaja memeriksa keberadaan kolom `consolidated` di kedua tabel sebelum mengubah procedure. Jika salah satu kolom tidak ada, deployment berhenti tanpa memaksakan asumsi schema.

Patch adalah satu executable batch dan tidak menggunakan `GO`.

### Rev.2 — 14 Sep 2026

Apply Database pertama gagal dengan:

```text
The data types bit and bit are incompatible in the add operator.
```

Penyebabnya adalah guard partial-state menjumlahkan empat variable bertipe `BIT` secara langsung. SQL Server tidak mendukung operasi `BIT + BIT`.

Rev.2 mengubah guard tersebut menjadi penjumlahan setelah `CONVERT(INT, ...)`:

```sql
IF CONVERT(INT, @HasHdrColumn)
 + CONVERT(INT, @HasHdrValue)
 + CONVERT(INT, @HasLineColumn)
 + CONVERT(INT, @HasLineValue) > 0
```

Error terjadi sebelum procedure diubah, sehingga patch Rev.2 aman dijalankan ulang pada tenant yang gagal di Rev.1.

## Expected mapping

### co_mst

```text
consolidated = 1
```

### coitem_mst

```text
stat         = O
consolidated = 1
```

## Verification — Query Select

Gunakan CO baru yang dibuat setelah Patch 17:

```sql
SELECT
    site_ref,
    co_num,
    type,
    cust_num,
    cust_po,
    consolidated
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>';
```

Expected:

```text
type         = B
consolidated = 1
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
    consolidated
FROM dbo.coitem_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO_NUM>'
ORDER BY co_line;
```

Expected setiap line:

```text
stat         = O
consolidated = 1
```

## Existing Customer Orders

Patch 17 tidak melakukan mass update terhadap CO lama. Requirement ini berlaku untuk CO baru setelah patch di-apply. Existing transaction hanya diubah jika memang diputuskan secara terpisah untuk koreksi data UAT.
