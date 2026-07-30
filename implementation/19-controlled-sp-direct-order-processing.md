# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Decision

```text
Decision date                     : 30 July 2026
User approval                     : CONFIRMED
CreateCoAndLines reverse-engineering: STOPPED
Processing direction              : CONTROLLED STORED PROCEDURE
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Implementation status             : NOT STARTED
Required input                    : previous working stored procedure
```

The user confirmed that a previous implementation successfully used a stored procedure with direct inserts into `co_mst` and `coitem_mst`. The project therefore stops further metadata discovery for `SLCos.CreateCoAndLines` and pivots to reviewing and adapting the previous stored procedure.

## Intended Flow

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

## Mandatory Controls

The stored procedure design must include, at minimum:

```text
1. SET XACT_ABORT ON and explicit transaction control.
2. Idempotency protection for co_num + co_line + SiteRef.
3. Reprocess protection against duplicate header or line creation.
4. Validation that the selected staging rows belong to one order/site.
5. Customer existence and active-state validation.
6. Item and item/site validation.
7. Cost retrieval from item_mst; cost is not stored in staging.
8. Header total derived from SUM(unit_price * qty_ordered).
9. Complete error capture and rollback on failure.
10. Staging status update:
    N = New
    V = Valid
    E = Error
    P = Processed
    C = Cancelled
11. Maintain retry_count, validation_msg, error_msg, processed_date, processed_by.
12. No partial header/line commit.
```

## Important Boundary

Direct inserts may bypass standard SyteLine business logic. The implementation is therefore not considered safe merely because it is inside a stored procedure. The previous procedure must be reviewed against the current tenant's required columns, defaults, validations, triggers, and downstream behavior before execution.

No SQL has been created or executed as part of this decision.

## Current Small Step

Obtain the previous working stored procedure from the user.

Review it before changing anything, specifically:

```text
- input parameters
- co_num generation
- required co_mst columns
- required coitem_mst columns
- default values and site handling
- customer and item validation
- transaction and rollback behavior
- duplicate prevention
- error handling
- staging status updates
```

Do not draft a replacement procedure from assumptions before the previous procedure is available.
