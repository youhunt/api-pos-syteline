# Auto CO — Blanket type B dan business Cust PO

Tanggal: 15 Sep 2026

## Tenant evidence

UAT source/POS order:

```text
Source/POS Order No : R260904065
Business CustPo     : DEV4-231
Generated CO        : CO26090002
```

Query tenant menunjukkan:

```text
co_mst.co_num       = CO26090002
co_mst.type         = R
co_mst.cust_po      = R260904065
co_mst.consolidate  = 1
```

Form Customer Orders juga menampilkan **Order Type = Regular** dan **Cust PO = R260904065**.

## Root cause

`SMK069ProcessCustomerOrderSp` memakai `@SourceCoNum` sebagai `co_mst.cust_po` dan tidak menulis `co_mst.type` secara eksplisit. Karena itu:

- source/POS technical order number masuk ke field business Cust PO;
- SyteLine memberi default order type Regular (`R`).

## Correct mapping

Mulai Patch 21:

```text
@SourceCoNum                -> tetap technical staging/source key
staging cust_po             -> co_mst.cust_po
co_mst.type                 -> B
co_mst.consolidate          -> 1 (Patch 17 tetap dipertahankan)
coitem_mst.stat             -> O
coitem_mst.consolidate      -> 1
```

Contoh yang benar:

```text
Source/POS order : R260904065
Cust PO          : DEV4-231
Generated CO     : CO2609xxxx
Order Type       : Blanket (B)
```

Idempotency lookup juga menggunakan business `cust_po`, bukan lagi Source/POS order number.

## Deployment

Apply Database:

```text
database/patches/csv-to-co/2026-09-15-smk069-21-fix-blanket-type-and-cust-po.sql
```

Patch dibuat satu executable batch dan tanpa `GO`.

Patch 21 tidak melakukan mass update terhadap CO lama yang sudah salah. UAT sesudah patch harus memakai source/PO baru agar hasil baru dapat diverifikasi tanpa mencampur data CO yang sudah dibuat sebelum patch.

## Verification

Setelah hit PO baru yang valid:

```sql
SELECT
    co_num,
    type,
    cust_num,
    cust_seq,
    cust_po,
    consolidate
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po = N'<BUSINESS_CUST_PO>';
```

Expected:

```text
type        = B
cust_po     = business PO, contoh DEV4-232
consolidate = 1
```

Kemudian:

```sql
SELECT co_num, co_line, item, qty_ordered, stat, consolidate
FROM dbo.coitem_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<GENERATED_CO>'
ORDER BY co_line;
```

Expected setiap line:

```text
stat        = O
consolidate = 1
```

## Blanket-line follow-up gate

Target arsitektur tetap memerlukan verifikasi `co_bln_mst`. Patch 21 hanya memperbaiki dua defect yang sudah terbukti pada header Auto CO (`cust_po` dan `type`). Jangan mengarang schema/insert `co_bln_mst` tanpa bukti tenant.

Sesudah UAT CO baru type B, jalankan:

```sql
SELECT *
FROM dbo.co_bln_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<GENERATED_CO>'
ORDER BY co_line;
```

Jika tidak ada row, lakukan audit schema `co_bln_mst` dan patch blanket-line berdasarkan tenant aktual.
