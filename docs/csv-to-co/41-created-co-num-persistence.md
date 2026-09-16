# Patch 26 — Persist `created_co_num` for Error Processing

**Date:** 16 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Problem

`SMK069ProcessCustomerOrderSp` already produces the actual SyteLine Customer Order number in `@CreatedCoNum`, but the dedicated staging column:

```text
dbo.ue_SMK069_temp_sales_mst.created_co_num
```

was not populated. The Error Processing form therefore showed a blank `SyteLine CO Number` column even when the CO existed.

## Fix

Patch:

```text
database/patches/csv-to-co/2026-09-16-smk069-26-persist-created-co-num.sql
```

The installed `dbo.SMK069ProcessCustomerOrderSp` is altered so that:

```text
existing/idempotent CO -> created_co_num = @ExistingCoNum
newly-created CO       -> created_co_num = @CreatedCoNum
```

Patch 26 also backfills historical staging rows in status `P` only when `SiteRef + customer + cust_po` resolves to exactly one Blanket CO.

## Form binding

```text
SyteLine CO Number -> object.created_co_num
CustPo             -> object.cust_po
```

## Verification

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
  AND cust_po IN
  (
      N'DEV4-233',
      N'DEV4-238',
      N'DEV4-238100'
  )
ORDER BY cust_po, co_line;
```

Expected successful rows:

```text
created_co_num = actual SyteLine CO number
process_status = P
```

For the current UAT example:

```text
cust_po        = DEV4-238100
created_co_num = P260916003
```

## Canonical-source note

Patch 26 is the deployable current-state delta for the installed procedure. Before final production baseline packaging, fold the same two `created_co_num` assignments into the canonical `database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql` source so production does not depend on replaying DEV/UAT patch history.
