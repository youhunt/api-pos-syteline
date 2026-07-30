# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                     : 30 July 2026
Initial user approval             : CONFIRMED
Later user direction              : RESUME CreateCoAndLines metadata discovery
Processing direction              : DEFERRED ALTERNATIVE
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Implementation status             : NOT STARTED
SQL created                       : NO
SQL executed                      : NO
```

The user previously confirmed that an earlier implementation used a stored procedure with direct inserts into `co_mst` and `coitem_mst`. This alternative remains documented, but it is no longer the active next step because the user subsequently instructed the project to continue metadata discovery for `SLCos.CreateCoAndLines`.

Active work continues in:

```text
implementation/18-discover-createcoandlines-call-sites.md
```

## Intended Alternative Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst staging
→ validate staging/customer/item/site/order state
→ controlled stored procedure transaction
→ insert dbo.co_mst header
→ insert dbo.coitem_mst lines
→ update staging process_status and processing metadata
→ expose errors through ue_SMK069APISalesErrorProcessing
```

## Mandatory Controls if Reactivated

```text
1. SET XACT_ABORT ON and explicit transaction control.
2. Idempotency protection for co_num + co_line + SiteRef.
3. Reprocess protection against duplicate header or line creation.
4. Validation that selected staging rows belong to one order/site.
5. Customer existence and active-state validation.
6. Item and item/site validation.
7. Cost retrieval from item_mst.
8. Header total derived from SUM(unit_price * qty_ordered).
9. Complete error capture and rollback on failure.
10. Maintain process_status, validation_msg, error_msg, retry_count, processed_date, and processed_by.
11. No partial header/line commit.
```

## Important Boundary

Direct inserts may bypass standard SyteLine business logic. This path is not considered safe merely because it is implemented inside a stored procedure.

## Current Boundary

```text
- Do not draft or execute direct-insert SQL now.
- Do not request the previous stored procedure as the current next step.
- Continue read-only CreateCoAndLines metadata discovery.
- Reactivate this document only after a later explicit user decision.
```