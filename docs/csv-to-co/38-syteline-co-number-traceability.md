# Patch 23 — Persist SyteLine CO Number for Error Processing

## Tenant finding — 16 Sep 2026

Rows such as:

```text
R260904069 / DEV4-233
R260904070 / DEV4-238
```

were already shown as:

```text
Status       = Processed
Processed By = POS_API
```

but the Error Processing grid column **SyteLine CO Number** remained blank.

## Root cause

The staging table historically stores the source/POS order in `co_num` plus process status/audit fields. It had no dedicated target/generated Customer Order column.

`SMK069ProcessCustomerOrderSp` correctly returns the generated target number through `@CreatedCoNum`, and `SMK069ProcessBatchCustomerOrdersSp` aggregates it into `@CreatedCoNums`, but that generated number was not persisted back to `ue_SMK069_temp_sales_mst`.

Therefore a row could legitimately be `Processed` while the Error Processing form had no persisted target value to display.

## Patch

Apply:

```text
database/patches/csv-to-co/2026-09-16-smk069-23-persist-syteline-co-number.sql
```

Patch 23:

```text
adds ue_SMK069_temp_sales_mst.syteline_co_num nvarchar(10) NULL
persists @CreatedCoNum after every successful batch-order process
keeps source/POS co_num unchanged
keeps business cust_po unchanged
backfills historical Processed rows only when exactly one Blanket CO matches
  SiteRef + customer + business cust_po
skips ambiguous historical matches
```

No standard SyteLine table schema is changed.

## Mongoose metadata / form step

Adding the SQL column does not guarantee that an already-created entity IDO automatically exposes a new property.

After Apply Database:

```text
SQL Table metadata : SMK069_temp_sales_mst
IDO                : ue_SMK069TempSales
Property            : syteline_co_num
Suggested type      : CoNumType / NVARCHAR(10)
Read-only in form   : Yes
```

Refresh/resynchronize the SQL Table and IDO metadata as required by the tenant, then bind the existing **SyteLine CO Number** grid component to:

```text
object.syteline_co_num
```

The repository does not currently contain the tenant XML export for `ue_SMK069APISalesErrorProcessing`, so the exact existing component name/binding cannot be safely rewritten from repository evidence alone.

## Verification

For the current source orders:

```sql
SELECT
    t.SiteRef,
    t.co_num AS SourcePosOrderNo,
    t.cust_po,
    t.syteline_co_num AS SyteLineCoNumber,
    t.process_status,
    c.type,
    c.consolidate
FROM dbo.ue_SMK069_temp_sales_mst AS t
LEFT JOIN dbo.co_mst AS c
    ON c.site_ref = t.SiteRef
   AND c.co_num   = t.syteline_co_num
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.co_num IN (N'R260904069', N'R260904070')
ORDER BY t.co_num, t.co_line;
```

Expected after Patch 23 when the business Cust PO uniquely maps to one Blanket CO:

```text
process_status    = P
syteline_co_num   = CO...
type              = B
consolidate       = 1
```

## Important distinction

```text
co_num            = technical Source/POS Order No (R...)
syteline_co_num   = generated SyteLine Customer Order No (CO...)
cust_po           = business customer PO (DEV4-...)
```

These three values must remain separate.