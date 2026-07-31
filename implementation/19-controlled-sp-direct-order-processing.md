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
Consolidated procedure draft      : COMPLETED
SQL file                          : database/procedures/SMK069ProcessCustomerOrderSp.sql
SQL executed                      : NO
DEV verification                 : PENDING
```

## Active Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst staging
→ dbo.SMK069ProcessCustomerOrderSp
→ validate one SiteRef + source co_num group
→ generate final SyteLine co_num once
→ insert dbo.co_mst header
→ insert all dbo.coitem_mst lines with the same co_num
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

The source/POS `co_num` remains in staging and is stored in `co_mst.cust_po`. This provides idempotency without adding or overwriting a staging primary-key column.

On Reprocess, the procedure searches:

```text
site_ref + cust_num + cust_po(source co_num)
```

If a matching Customer Order already exists and its lines match staging, the procedure returns the existing SyteLine `co_num` and synchronizes staging to `P`. If the line count or line contents differ, processing fails safely instead of creating a duplicate.

## Implemented Procedure Contract

```sql
CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   CoNumType,
    @Sparepart     ListYesNoType = 0,
    @CustSeq       CustSeqType = 0,
    @PickupDate    DateType = NULL,
    @StartTime     NVARCHAR(8) = NULL,
    @EndTime       NVARCHAR(8) = NULL,
    @ProcessedBy   UsernameType = NULL,
    @CreatedCoNum  CoNumType OUTPUT,
    @Success       ListYesNoType OUTPUT,
    @Infobar       InfobarType OUTPUT
```

The complete SQL is stored in:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

## Implemented Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit TRY / TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. No trigger disable/enable.
4. No NOCHECK/CHECK constraint changes.
5. Staging rows locked with UPDLOCK + HOLDLOCK.
6. One customer, order date, warehouse, terms, and tax context per source order.
7. Customer/customer sequence validation.
8. Warehouse validation.
9. Default customer-currency validation.
10. Item and item-site validation.
11. Positive quantity and nonnegative price validation.
12. Missing line U/M falls back to item_mst.u_m.
13. Cost, material cost, and description retrieved from item_mst.
14. Header price = SUM(unit_price * qty_ordered).
15. Header cost and material cost calculated from item master times quantity.
16. Concurrency-safe numbering with transaction-owned sp_getapplock.
17. Normal number pattern EMYYMM####.
18. Spare-part number pattern EMPYYMM###.
19. Set-based insertion of all coitem_mst rows.
20. Header, lines, and staging success status commit together.
21. Failure status is written after rollback so it remains visible.
22. Output parameters return success, created co_num, and Infobar.
```

## Confirmed Header Mapping

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
Uf_date_pengambilan
Uf_StartTime
Uf_EndTime
```

## Confirmed Line Mapping

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
Uf_Item_price
Uf_net_price
Uf_price_aft_disc1
Uf_price_aft_disc2
Uf_price_aft_disc3
```

## Safety Boundary Before DEV Execution

The procedure has been drafted from tenant-confirmed staging and legacy mappings but has not been executed. Before the first controlled DEV call:

```text
1. Create/alter the procedure in DEV only.
2. Confirm item_mst exposes unit_cost, matl_cost, description, and u_m in this tenant.
3. Confirm customer_currency_mst contains the expected default currency row.
4. Confirm triggers accept the known header and line mappings while remaining enabled.
5. Select one disposable SiteRef + source co_num staging order.
6. Capture pre-test co_mst/coitem_mst counts.
7. Execute once and inspect @Success, @CreatedCoNum, and @Infobar.
8. Verify header and every line.
9. Test the same source order again to confirm idempotency.
10. Test an invalid item to confirm rollback and staging E status.
```

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
database/tables/SMK069_temp_sales_mst.md
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
