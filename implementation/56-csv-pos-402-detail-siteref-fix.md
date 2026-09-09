# SMK069 CSV -> CO: POS-402 detail SiteRef mismatch

Date: 2026-09-09

## Tenant evidence

CSV Test Console showed a successfully parsed batch with two visible detail rows:

```text
CSV V2 berhasil diparsing. Rows=2, FormatErrors=0.
```

But `SMK069RunCsvTestBatchSp` returned:

```text
[POS-402] Batch CSV belum memiliki detail transaksi.
```

The failing tenant batch also showed the CSV/business `siteref` value blank.

## SiteRef vs siteref

These are different concepts:

```text
SiteRef  = standard Mongoose site ownership column used by site-aware SQL.
siteref  = business/source field parsed from the CSV; it may be blank when the CSV
           does not provide site/site_ref/siteref.
```

The one-hit procedure uses the standard `SiteRef` column for tenant/site isolation.
Therefore a blank CSV/business `siteref` by itself is not the direct cause of POS-402.

## Root cause

The parser `SMK069ImportCsvFileSp` inserts parsed rows into
`dbo.ue_SMK069_pos_csv_upload_mst`, but the current repository revision does not
explicitly populate the standard Mongoose `SiteRef` column in that INSERT.

The one-hit procedure `SMK069RunCsvTestBatchSp`, after site-aware hardening,
requires detail rows using:

```sql
WHERE SiteRef = @Site
  AND batch_id = @BatchId
```

This allows detail rows to be visible on a form linked by `batch_id` but still be
invisible to the site-aware one-hit processor.

## Patch 13 Rev.3

Apply:

```text
database/patches/2026-09-09-smk069-13-fix-csv-detail-siteref-before-one-hit.sql
```

Patch 13 preserves the installed body of `SMK069RunCsvTestBatchSp` and injects a
small normalization immediately after current-site initialization. For a batch
header owned by the current site it updates detail rows for the same `batch_id`
so their standard `SiteRef` matches the active site before the existing preflight
runs.

### Rev.1 Apply Database error

The first revision failed with:

```text
Incorrect syntax near the keyword 'ELSE'
```

Cause: an effectively empty prefix-detection branch.

### Rev.2 Apply Database error

The second revision failed with:

```text
Prefix procedure tidak dikenali. Patch dihentikan untuk keamanan.
```

Cause: it still assumed the installed module began with one exact prefix shape
(`CREATE PROCEDURE`, `CREATE OR ALTER PROCEDURE`, or `ALTER PROCEDURE`). The
tenant definition can use `PROC` instead of `PROCEDURE`, different whitespace,
or another equivalent module header form.

### Rev.3 behavior

Rev.3 no longer depends on an exact starting prefix. It:

1. Finds `SMK069RunCsvTestBatchSp` inside the installed definition.
2. Locates the nearest `PROC` / `PROCEDURE` token before the object name.
3. Looks only in the nearby header for `CREATE` / `ALTER`.
4. Rewrites that header to `ALTER PROCEDURE`.
5. Executes the modified installed definition.

The patch is still one executable batch with no `GO`, suitable for Infor Apply Database.

## Verification query

```sql
SELECT
    batch_id,
    SiteRef,
    siteref,
    row_no,
    custnum,
    cust_po,
    whse,
    item,
    qty_ordered,
    u_m,
    upload_status,
    result_message
FROM dbo.ue_SMK069_pos_csv_upload_mst
WHERE batch_id = N'CSV-20260909-072038-835E3D'
ORDER BY row_no;
```

After Patch 13 Rev.3 and the next one-hit execution:

```text
SiteRef = active Mongoose site (tenant currently expected: Default)
siteref = may remain blank if CSV did not supply it
```

## UAT flow after patch

1. Apply Patch 13 Rev.3.
2. Refresh the CSV Test Console.
3. Click Import & Validate / one-hit CSV -> CO using the same batch.
4. Expected: POS-402 disappears.
5. If business validation passes, processing continues to `SMK069ProcessBatchCustomerOrdersSp` and `SMK069ProcessCustomerOrderSp`.
6. Verify the Blanket Customer Order in:
   - `co_mst`
   - `coitem_mst`
   - `co_bln_mst`

## Follow-up hardening

The parser source should eventually be revised so `SMK069ImportCsvFileSp`
explicitly sets the standard `SiteRef` during parse/persistence. Patch 13 remains
small so the currently installed one-hit procedure can be repaired without
replacing its full body.
