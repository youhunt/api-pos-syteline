# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                     : 31 July 2026
Processing direction              : ACTIVE
Previous CreateCoAndLines path    : PAUSED
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Consolidated procedure            : COMPILED IN TENANT
SQL file                          : database/procedures/SMK069ProcessCustomerOrderSp.sql
First controlled execution        : COMPLETED
First execution result            : CONTROLLED ERROR 50003 — STAGING GROUP NOT FOUND
Second controlled execution       : COMPLETED
Second execution result           : CONTROLLED ERROR 50020 — ITEM NOT FOUND
Customer Order rows created       : NO
Next step                         : replace dummy item with an exact item_mst item from the same SiteRef
```

## Active Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst
→ dbo.SMK069ProcessCustomerOrderSp
→ validate one SiteRef + source co_num group
→ validate customer, warehouse, currency, and item master data
→ generate one final SyteLine co_num
→ insert dbo.co_mst
→ insert all dbo.coitem_mst rows using the same co_num
→ update staging to P
→ commit
```

Failure flow:

```text
validation or SQL failure
→ rollback header, lines, and success-status changes
→ update matching staging rows to E after rollback
→ store error_msg
→ increment retry_count
```

## Tenant-confirmed Procedure Contract

```sql
CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   CoNumType,
    @CustSeq       CustSeqType = 0,
    @ProcessedBy   UsernameType = NULL,
    @CreatedCoNum  CoNumType OUTPUT,
    @Success       ListYesNoType OUTPUT,
    @Infobar       InfobarType OUTPUT
```

Removed from the active contract:

```text
@Sparepart
@PickupDate
@StartTime
@EndTime
```

The active generated-number pattern is:

```text
COYYMM####
```

The source/POS order number stays in staging `co_num` and is stored in `co_mst.cust_po` for idempotent reprocessing.

## Header-to-Line Relationship

```text
co_mst.co_num     = generated @CreatedCoNum
coitem_mst.co_num = the same @CreatedCoNum
```

No identity lookup or follow-up query is needed.

## Current Header Mapping

```text
co_num
cust_num
cust_po                  ← source/POS co_num
cust_seq
whse
order_date
curr_code
site_ref
contact
phone
terms_code
tax_code1
end_user_type
orig_site
include_tax_in_price
cost
matl_cost_t
price
```

## Current Line Mapping

```text
co_num
co_line
item
qty_ordered
u_m
due_date
price
site_ref
whse
qty_ordered_conv
cust_seq
co_cust_num
ship_site
co_orig_site
description
cost
cgs_total
price_conv
matl_cost
cost_conv
matl_cost_conv
```

Portal-only unavailable `Uf_*` fields are not used.

## Implemented Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit TRY / TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. No trigger disable/enable.
4. No NOCHECK/CHECK constraint changes.
5. Staging group locked with UPDLOCK + HOLDLOCK.
6. Customer, date, warehouse, terms, tax, item, quantity, price, and U/M validation.
7. Cost, material cost, description, and fallback U/M retrieved from item_mst.
8. Header price = SUM(unit_price * qty_ordered).
9. Concurrency-safe numbering through transaction-owned sp_getapplock.
10. Set-based insertion of all lines using one generated co_num.
11. Idempotent reprocess through site_ref + cust_num + cust_po.
12. Failure status written after rollback when matching staging rows exist.
13. Output parameters return success, generated co_num, and Infobar.
```

## Compile Corrections Confirmed

The following tenant compile problems were resolved:

```text
- Alias types cannot be CAST/CONVERT targets in this environment.
- Portal-only Uf_* columns do not exist in this tenant.
```

System types such as `NVARCHAR` are used for conversions, while SyteLine alias types remain valid for procedure parameters and variables.

## Controlled Runtime Results

### Runtime 1 — staging group not found

```text
Success      : 0
CreatedCoNum : NULL
Infobar      : Error 50003 pada line 72: Data staging untuk SiteRef dan source co_num tersebut tidak ditemukan.
```

No `co_mst` or `coitem_mst` row was created.

### Runtime 2 — invalid item

```text
Success      : 0
CreatedCoNum : NULL
Infobar      : Error 50020 pada line 259: Item tidak ditemukan pada item_mst: TEST-ITEM-001
```

This proves the selected staging group now exists and execution reached item-master validation. `TEST-ITEM-001` is not a valid `item_mst` item for the same staging `SiteRef`. Processing stopped before header or line insertion.

## Current Small Step

Read actual item candidates from `item_mst` for the exact staging site:

```sql
DECLARE @SiteRef SiteType = N'<EXACT_STAGING_SITE>';

SELECT TOP (20)
    site_ref,
    LTRIM(RTRIM(item)) AS item,
    description,
    u_m,
    unit_cost,
    matl_cost
FROM dbo.item_mst
WHERE site_ref = @SiteRef
  AND NULLIF(LTRIM(RTRIM(item)), N'') IS NOT NULL
ORDER BY item;
```

Choose one exact returned item and update only the dummy staging line before running the procedure again. Do not remove the item validation.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
tests/evidence/2026-07-31-smk069-sp-first-compile-errors-and-fix.md
tests/evidence/2026-07-31-smk069-sp-compile-success-and-missing-staging-test.md
tests/evidence/2026-07-31-smk069-invalid-item-runtime.md
database/tables/SMK069_temp_sales_mst.md
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
