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

This allows a detail row to be visible on a form linked by `batch_id` but still
be invisible to the site-aware one-hit processor.

## Patch

Apply:

```text
database/patches/2026-09-09-smk069-13-fix-csv-detail-siteref-before-one-hit.sql
```

Patch 13 preserves the installed body of `SMK069RunCsvTestBatchSp` and injects a
small normalization immediately after current-site initialization. For a batch
header owned by the current site it updates detail rows for the same `batch_id`
so their standard `SiteRef` matches the active site before the existing preflight
runs.

The patch is one executable batch and contains no `GO`, so it is suitable for
Infor Apply Database.

## Verification query

For the failing batch:

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

After Patch 13 and the next one-hit execution, `SiteRef` must match the active
site, while the CSV/business `siteref` field may remain whatever the CSV parser
captured.

## UAT flow after patch

1. Apply Patch 13.
2. Refresh the CSV Test Console.
3. Click Import & Validate / the one-hit CSV -> CO action again using the same batch.
4. Expected: POS-402 disappears.
5. If business validation passes, the procedure continues to `SMK069ProcessBatchCustomerOrdersSp` and then `SMK069ProcessCustomerOrderSp`.
6. Verify created Blanket Customer Order in:
   - `co_mst`
   - `coitem_mst`
   - `co_bln_mst`

## Follow-up hardening

The parser source should eventually be revised so `SMK069ImportCsvFileSp`
explicitly sets and filters standard `SiteRef` itself. Patch 13 is deliberately
compatible with the current tenant and repairs both existing and future parsed
batches at one-hit execution time without replacing the full parser definition.
