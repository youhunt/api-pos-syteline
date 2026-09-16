# Patch 24 — Final CO Number, Cust PO Linkage, and Release Date

**Date:** 16 September 2026

## Business decision

Stakeholder requested three changes:

```text
1. Nomor CO baru = P + YYMMDD + 3 digit running
2. Nomor CO yang terlihat di staging/form harus sama dengan CO yang benar-benar terbentuk di SyteLine
3. Released Date harus sama dengan Order Date
```

Business linkage juga ditegaskan memakai:

```text
cust_po
```

bukan lagi nomor teknis `R...` sebagai identifier yang dibawa ke proses bisnis.

## Final numbering format

```text
PYYMMDD###
```

Example:

```text
Order Date : 2026-09-16
CO #1      : P260916001
CO #2      : P260916002
```

Karena tanggal menjadi bagian prefix, running 3 digit reset secara natural untuk setiap tanggal.

Total panjang = 10 karakter dan Patch 24 melakukan guard terhadap panjang `co_mst.co_num` dan staging `co_num` sebelum mengubah procedure.

## Temp `co_num`

Keputusan final:

```text
sebelum success  : co_num dapat masih berisi transient legacy selector R...
setelah success  : co_num = actual SyteLine CO number
```

Contoh:

```text
cust_po = DEV4-233
before  = R260904069   (transient)
after   = CO lama yang sudah terbuat, atau PYYMMDD### untuk CO baru
```

Existing standard CO tidak pernah direnumber oleh Patch 24. Untuk historical Processed staging, Patch 24 hanya mengganti staging `co_num` ke existing Blanket CO bila `SiteRef + customer + cust_po` menghasilkan tepat satu target CO.

## Business linkage

`cust_po` menjadi business key untuk:

```text
- idempotency Customer Order
- pending match batch processing
- operator/error messages
- historical relink staging -> actual CO
```

Legacy `R...` tetap dipertahankan hanya sebagai transient selector untuk row yang belum sukses, karena receive Core lama masih menghasilkan key tersebut. Setelah sukses, staging key diganti dengan actual CO.

## Release Date

Rule final:

```text
coitem_mst.release_date = co_mst.order_date
```

Untuk CO baru, `release_date` ditulis langsung saat insert `coitem_mst`.

Untuk existing matching Blanket CO yang sedang direprocess, Patch 24 memperbaiki `release_date` yang NULL atau berbeda dari `order_date`.

Patch juga melakukan safe historical repair untuk matching Processed integration rows.

## Patch

Apply melalui Infor Apply Database:

```text
database/patches/csv-to-co/2026-09-16-smk069-24-co-number-custpo-release-date.sql
```

Patch adalah satu executable batch dan tidak memakai `GO`.

Patch 23 tidak diperlukan dan sudah ditarik dari active patch set.

## Verification — current historical rows

Setelah apply, cari berdasarkan business Cust PO, bukan R-number:

```sql
SELECT
    t.SiteRef,
    t.co_num,
    t.cust_po,
    t.order_date,
    t.process_status,
    c.type,
    c.order_date AS co_order_date
FROM dbo.ue_SMK069_temp_sales_mst AS t
LEFT JOIN dbo.co_mst AS c
    ON c.site_ref = t.SiteRef
   AND c.co_num = t.co_num
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.cust_po IN (N'DEV4-233', N'DEV4-238')
ORDER BY t.cust_po, t.co_line;
```

Expected:

```text
t.co_num = actual existing SyteLine CO
c.type   = B
```

Release Date:

```sql
SELECT
    c.co_num,
    c.cust_po,
    c.order_date,
    ci.co_line,
    ci.item,
    ci.release_date
FROM dbo.co_mst AS c
INNER JOIN dbo.coitem_mst AS ci
    ON ci.site_ref = c.site_ref
   AND ci.co_num = c.co_num
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.cust_po IN (N'DEV4-233', N'DEV4-238')
ORDER BY c.cust_po, ci.co_line;
```

Expected:

```text
ci.release_date = c.order_date
```

## Verification — new CO

Send one new valid PO after Patch 24.

Expected:

```text
co_mst.co_num       = PYYMMDD###
staging.co_num      = same PYYMMDD###
co_mst.cust_po      = payload/staging cust_po
co_mst.type         = B
coitem.release_date = co_mst.order_date
```
