# SMK API SALES ERROR PROCESSING — Final Grid Binding

**Date:** 16 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Proven UI issue

The Error Processing form has a dedicated `SyteLine CO Number` field/property backed by:

```text
ue_SMK069_temp_sales_mst.created_co_num
```

The Auto CO processor previously returned the actual CO number through `@CreatedCoNum`, but did not persist that value into `created_co_num`. As a result, the grid column was blank even though a Customer Order had been created.

Observed example:

```text
cust_po         = DEV4-238100
actual CO       = P260916003
created_co_num  = NULL   <- wrong
```

## Backend fix — Patch 26

Apply:

```text
database/patches/csv-to-co/2026-09-16-smk069-26-persist-created-co-num.sql
```

Final behavior:

```text
new CO success:
created_co_num = @CreatedCoNum

existing/idempotent CO:
created_co_num = @ExistingCoNum
```

Patch 26 also safely backfills historical `Processed` staging rows when `SiteRef + customer + cust_po` resolves to exactly one Blanket CO.

## Final form semantics

Use these bindings:

```text
SyteLine CO Number  -> object.created_co_num
CustPo              -> object.cust_po
```

`co_num` remains controlled by the active staging/process design and must not be used as the dedicated display property for the `SyteLine CO Number` column when `created_co_num` exists specifically for that purpose.

## Recommended grid layout

```text
Site
Order Date
SyteLine CO Number   = object.created_co_num
Source/POS Order No  = object.co_num   (only if the business still wants it shown)
Line
Customer
CustSeq
Name
CustPo               = object.cust_po
Item
Quantity
U/M
Unit Price
Warehouse
Due Date
Terms
Tax Code
...
```

## Top filter

If the top `CO Number` filter is intended to search the actual SyteLine CO, it should filter:

```text
created_co_num
```

so values such as `P260916003` locate the row directly.

## Verification

After Patch 26:

```sql
SELECT
    SiteRef,
    co_num,
    cust_po,
    created_co_num,
    process_status,
    processed_date,
    processed_by
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po IN (N'DEV4-233', N'DEV4-238', N'DEV4-238100')
ORDER BY cust_po, co_line;
```

Expected for successful rows:

```text
created_co_num = actual SyteLine CO number
process_status = P
```
