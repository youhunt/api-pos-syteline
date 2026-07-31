# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                     : 31 July 2026
Processing direction              : ACTIVE
Previous CreateCoAndLines path    : PAUSED
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Legacy header procedure           : dbo.TDI_PortalEMotor_InsertCO — PROVIDED
Legacy line insert mapping        : PROVIDED
Generated co_num handoff          : CONFIRMED THROUGH OUTPUT PARAMETER
Consolidated procedure            : DRAFTED AND REVISED
SQL file                          : database/procedures/SMK069ProcessCustomerOrderSp.sql
First tenant compile              : FAILED
Corrective revision               : COMMITTED
Corrected tenant compile          : PENDING
Procedure execution               : NOT STARTED
```

## Active Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst
→ dbo.SMK069ProcessCustomerOrderSp
→ validate one SiteRef + source co_num group
→ generate final SyteLine co_num once
→ insert dbo.co_mst
→ insert all dbo.coitem_mst rows with the same co_num
→ update staging to P
→ commit
```

Failure flow:

```text
validation or SQL failure
→ rollback header, lines, and success-status changes
→ update staging to E after rollback
→ store error_msg
→ increment retry_count
```

## Confirmed Relationship

```text
co_mst.co_num     = generated @CreatedCoNum
coitem_mst.co_num = the same @CreatedCoNum
```

The source/POS `co_num` remains in staging and is stored in `co_mst.cust_po` for idempotent reprocessing.

## Current Procedure Contract

```sql
CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   CoNumType,
    @Sparepart     ListYesNoType = 0,
    @CustSeq       CustSeqType = 0,
    @ProcessedBy   UsernameType = NULL,
    @CreatedCoNum  CoNumType OUTPUT,
    @Success       ListYesNoType OUTPUT,
    @Infobar       InfobarType OUTPUT
```

The complete SQL is stored in:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

## First Tenant Compile Result

The first compile attempt confirmed two corrections were required.

### Alias types in conversion expressions

These expressions failed:

```sql
CONVERT(CoNumType, ...)
CONVERT(InfobarType, ...)
```

The tenant accepts the alias types for procedure parameters and variables, but not as `CAST`/`CONVERT` target system types. The revised SQL now uses direct assignment or a system type such as `NVARCHAR`.

### Portal-only UDF columns absent

The following columns from the separate legacy portal implementation do not exist in this tenant:

```text
co_mst:
Uf_date_pengambilan
Uf_StartTime
Uf_EndTime

coitem_mst:
Uf_Item_price
Uf_net_price
Uf_price_aft_disc1
Uf_price_aft_disc2
Uf_price_aft_disc3
```

They were removed from the procedure. The related pickup-date/start-time/end-time procedure parameters were also removed.

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

## Implemented Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit TRY / TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. No trigger disable/enable.
4. No NOCHECK/CHECK constraint changes.
5. Staging rows locked with UPDLOCK + HOLDLOCK.
6. Customer, date, warehouse, terms, tax, item, quantity, price, and U/M validation.
7. Cost, material cost, description, and default U/M retrieved from item_mst.
8. Header price = SUM(unit_price * qty_ordered).
9. Concurrency-safe numbering through transaction-owned sp_getapplock.
10. Number patterns EMYYMM#### and EMPYYMM###.
11. Set-based insertion of all lines using one generated co_num.
12. Idempotent reprocess through site_ref + cust_num + cust_po.
13. Failure status written after rollback.
14. Output parameters return success, created co_num, and Infobar.
```

## Current Small Step

Compile the revised `database/procedures/SMK069ProcessCustomerOrderSp.sql` in DEV again.

Do not execute the procedure yet. First confirm that the revised `CREATE OR ALTER PROCEDURE` completes without compile errors. If another invalid column or object is returned, use that exact tenant error to revise the mapping.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
tests/evidence/2026-07-31-smk069-sp-first-compile-errors-and-fix.md
database/tables/SMK069_temp_sales_mst.md
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
