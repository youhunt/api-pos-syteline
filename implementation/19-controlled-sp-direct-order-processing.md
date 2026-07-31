# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                     : 31 July 2026
Processing direction              : ACTIVE
Previous CreateCoAndLines path    : PAUSED
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Consolidated procedure            : COMPILED IN TENANT
SQL file                          : database/procedures/SMK069ProcessCustomerOrderSp.sql
Runtime 1                         : 50003 — staging group not found
Runtime 2                         : 50020 — dummy item not found
Runtime 3                         : 50000 — DeleteRemoteNotesSp replication rule missing
Customer Order rows created       : NOT CONFIRMED
Current blocker                   : standard SyteLine trigger/replication configuration
Next step                         : identify exact DeleteRemoteNotesSp caller and active session/site context
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
→ standard SyteLine trigger/replication logic
→ insert all dbo.coitem_mst rows using the same co_num
→ update staging to P
→ commit
```

Failure flow:

```text
validation, trigger, replication, or SQL failure
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
3. No global trigger disable/enable.
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
14. SQL session site context is supplied before standard table insert and restored afterward.
```

## Compile Corrections Confirmed

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

This confirmed execution reached item-master validation and stopped before header/line creation.

### Runtime 3 — standard replication path blocked

```text
Error 50000 pada dbo.RaiseErrorSp line 121:
Not one Replication Rule where Disabled is No and Target Site is DEFAULT exists
for Replication Category Object that has [Object Name: DeleteRemoteNotesSp].
```

This confirms execution progressed beyond staging and item validation into standard SyteLine trigger/replication logic during the direct `co_mst` insert. The standard path attempted to use `DeleteRemoteNotesSp` through Replication Category `Object`, targeting `DEFAULT`, but the database did not contain exactly one active matching rule.

This must not be resolved by globally disabling triggers or by inserting an unverified replication rule.

## Current Small Step

Identify the exact caller and current session context with read-only SQL:

```sql
SELECT
    OBJECT_SCHEMA_NAME(m.object_id) AS SchemaName,
    OBJECT_NAME(m.object_id) AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.sql_modules AS m
JOIN sys.objects AS o
  ON o.object_id = m.object_id
WHERE m.definition LIKE N'%DeleteRemoteNotesSp%'
ORDER BY ObjectType, SchemaName, ObjectName;

SELECT
    DB_NAME() AS CurrentDatabase,
    CONTEXT_INFO() AS ContextInfoBinary,
    CONVERT(VARCHAR(128), CONTEXT_INFO()) AS ContextInfoText;
```

Use the tenant result to determine whether `DEFAULT` is the intended site, an incomplete session fallback, or missing replication metadata in the backup database.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
tests/evidence/2026-07-31-smk069-sp-first-compile-errors-and-fix.md
tests/evidence/2026-07-31-smk069-sp-compile-success-and-missing-staging-test.md
tests/evidence/2026-07-31-smk069-invalid-item-runtime.md
tests/evidence/2026-07-31-smk069-replication-rule-delete-remote-notes-runtime.md
database/tables/SMK069_temp_sales_mst.md
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
