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
Customer Order rows created       : NO
Next step                         : select an exact existing staging SiteRef + co_num
```

## Active Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst
→ dbo.SMK069ProcessCustomerOrderSp
→ validate one SiteRef + source co_num group
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

The active generated-number pattern is now:

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

## First Controlled Runtime Result

The procedure returned:

```text
Success      : 0
CreatedCoNum : NULL
Infobar      : Error 50003 pada line 72: Data staging untuk SiteRef dan source co_num tersebut tidak ditemukan.
```

The `co_mst` and `coitem_mst` verification grids were empty. This confirms a controlled validation failure with no partial Customer Order creation.

The cause is an execution pair that did not match:

```sql
SiteRef = @SiteRef
AND LTRIM(RTRIM(co_num)) = @SourceCoNum
```

## Current Small Step

Run only this read query:

```sql
SELECT
    SiteRef,
    LTRIM(RTRIM(co_num)) AS SourceCoNum,
    COUNT(*) AS LineCount,
    MIN(process_status) AS MinStatus,
    MAX(process_status) AS MaxStatus
FROM dbo.ue_SMK069_temp_sales_mst
GROUP BY SiteRef, LTRIM(RTRIM(co_num))
ORDER BY SiteRef, SourceCoNum;
```

Use one exact returned pair for the next procedure execution. If it returns no row, the staging table is empty in the current database and must be populated before the Customer Order test.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
tests/evidence/2026-07-31-smk069-sp-first-compile-errors-and-fix.md
tests/evidence/2026-07-31-smk069-sp-compile-success-and-missing-staging-test.md
database/tables/SMK069_temp_sales_mst.md
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
