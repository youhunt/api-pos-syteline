# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                     : 31 July 2026
Processing direction              : ACTIVE
Previous CreateCoAndLines path    : PAUSED
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Header source procedure           : dbo.InsertCO — AVAILABLE, REFACTOR REQUIRED
Line insert mapping               : NOT YET PROVIDED
Implementation status             : STARTING
SQL executed                      : NO
```

The user explicitly stopped the `SL.SLCos.CreateCoAndLines` discovery path because the exact Base64 JSON contract remained undocumented and the delivery timeline had become more important.

## Active Flow

```text
POS/API data
→ dbo.ue_SMK069_temp_sales_mst staging
→ validate one order/site group
→ dbo.SMK069ProcessCustomerOrderSp
→ insert dbo.co_mst header
→ insert all dbo.coitem_mst lines
→ update staging process_status and processing metadata
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

## Non-Negotiable Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit BEGIN TRY / BEGIN TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. Triggers remain enabled.
4. Foreign keys and other constraints remain enabled.
5. No ALTER TABLE DISABLE TRIGGER.
6. No NOCHECK CONSTRAINT.
7. One order/site only per execution.
8. Header and all required lines succeed or none are committed.
9. Idempotency and reprocess protection for SiteRef + co_num + co_line.
10. Customer, customer sequence, warehouse, site, item, and item/site validation.
11. Cost retrieved from item/site or item master according to tenant rules.
12. Header total derived from SUM(unit_price * qty_ordered).
13. Maintain process_status, validation_msg, error_msg, retry_count, processed_date, and processed_by.
```

## Header Procedure Reuse

The existing `dbo.InsertCO` provides useful tenant-specific behavior:

```text
- EMYYMM#### / EMPYYMM### order-number pattern;
- customer contact and phone defaults;
- terms, tax code, end-user type, and include-tax defaults;
- warehouse, currency, site, pickup date, start time, and end time mappings.
```

The following statements must not be retained:

```sql
ALTER TABLE co_mst DISABLE TRIGGER ...
ALTER TABLE co_mst ENABLE TRIGGER ...
ALTER TABLE co_mst NOCHECK CONSTRAINT ...
ALTER TABLE co_mst CHECK CONSTRAINT ...
```

The header logic must run inside the same transaction as line insertion and staging-status updates.

## Current Missing Input

The project does not yet have the tenant-confirmed insert mapping for:

```text
dbo.coitem_mst
```

The fastest next input is one of:

```text
- the previous InsertCOItem/InsertCoLine stored procedure;
- the direct INSERT INTO coitem_mst code used by the prior integration;
- or a complete list of columns populated by a known-good Customer Order line.
```

## Current Small Step

Obtain the existing tenant-specific line insertion code. Do not draft the final processing procedure by guessing required `coitem_mst` fields.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
```
