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
Implementation status             : READY FOR CONSOLIDATION
SQL executed                      : NO
```

The user supplied the complete legacy portal flow used to create Customer Orders. The portal:

```text
1. Calls dbo.TDI_PortalEMotor_InsertCO.
2. Receives the generated @co_num OUTPUT value.
3. Inserts every line into dbo.coitem_mst using that same co_num.
```

The header-to-line relationship is therefore already known:

```text
co_mst.co_num = generated @co_num
coitem_mst.co_num = the same generated @co_num
```

No identity lookup or secondary query is required.

## Active Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst staging
→ validate one source order/site group
→ dbo.SMK069ProcessCustomerOrderSp
→ generate final @co_num once
→ insert dbo.co_mst header
→ insert all dbo.coitem_mst lines using @co_num
→ update staging process_status and generated order reference
→ commit
```

Failure flow:

```text
any validation or SQL failure
→ rollback header, lines, and staging success changes
→ update staging to E in controlled error handling
→ store error_msg
→ increment retry_count
```

## Confirmed Legacy Header Mapping

The supplied `dbo.TDI_PortalEMotor_InsertCO` populates:

```text
co_num
cust_num
cust_po
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

Tenant-specific number patterns:

```text
normal    : EMYYMM####
sparepart : EMPYYMM###
```

## Confirmed Legacy Line Mapping

The portal inserts these `dbo.coitem_mst` fields:

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

The legacy application correctly reads the output value after executing the header procedure:

```csharp
co_num = Convert.ToString(cmd.Parameters["@co_num"].Value);
```

It then uses that value for every line.

## Required Consolidation

The fastest safe implementation is one server-side transaction:

```text
BEGIN TRANSACTION
→ validate customer, site, warehouse, items, and source order
→ generate @co_num once under a concurrency-safe lock
→ insert co_mst
→ insert all coitem_mst rows set-wise from staging using @co_num
→ update staging status and generated order reference
→ COMMIT
```

This avoids sending line inserts one by one from the client and guarantees that header and all lines either succeed together or fail together.

## Non-Negotiable Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit BEGIN TRY / BEGIN TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. Triggers remain enabled.
4. Foreign keys and other constraints remain enabled.
5. No ALTER TABLE DISABLE TRIGGER.
6. No NOCHECK CONSTRAINT.
7. One source order/site only per execution.
8. Header and every required line succeed or none are committed.
9. Idempotency and reprocess protection.
10. Customer, sequence, warehouse, site, item, and item/site validation.
11. Cost retrieved from tenant master data where required.
12. Header total derived from SUM(unit_price * qty_ordered).
13. Parameterized or set-based SQL only; no SQL string concatenation.
14. Concurrency-safe order-number generation; do not use an unlocked MAX + 1.
15. Maintain process_status, validation_msg, error_msg, retry_count, processed_date, and processed_by.
```

## Legacy Statements Not Retained

```sql
ALTER TABLE co_mst DISABLE TRIGGER ...
ALTER TABLE co_mst ENABLE TRIGGER ...
ALTER TABLE co_mst NOCHECK CONSTRAINT ...
ALTER TABLE co_mst CHECK CONSTRAINT ...
```

The legacy application-side string-built `INSERT INTO coitem_mst` is also not retained in its current form. Its confirmed column mapping will be reused inside parameterized/set-based SQL.

## Generated Number Persistence

The generated `@co_num` exists in the processing procedure and is directly reused for line insertion.

For Process/Reprocess traceability, the final SyteLine order number should also be persisted on staging. If the current staging `co_num` field contains the external/POS order number, it must not be overwritten; use a distinct generated-order field such as:

```text
created_co_num
```

The exact staging field name remains a design decision and must be confirmed before tenant metadata is changed.

## Current Small Step

Draft `dbo.SMK069ProcessCustomerOrderSp` using the confirmed header and line mappings. The procedure should read one source order from staging, generate one `@co_num`, insert header and all lines in one transaction, and return the generated number plus an error/message output.

Do not execute the procedure until the staging-to-line field mapping and generated-order staging field are confirmed.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
```
