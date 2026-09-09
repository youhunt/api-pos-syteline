# 31 — Patch 13 Rev.3 Rerun UAT Gate: CSV → Blanket Customer Order

**Date:** 9 September 2026  
**Workstream:** CSV / POS Inbound → Blanket Customer Order only  
**Batch:** `CSV-20260909-072038-835E3D`

## Purpose

Continue the existing parsed CSV batch after Patch 13 Rev.3 without creating a new batch and without re-parsing an unchanged file.

Target flow:

```text
CSV detail
→ SMK069RunCsvTestBatchSp
→ SMK069ReceivePosSalesJsonCoreSp
→ ue_SMK069_temp_sales_mst
→ SMK069ProcessBatchCustomerOrdersSp
→ SMK069ProcessCustomerOrderSp
→ co_mst + coitem_mst + co_bln_mst
```

Success means the generated Customer Order is a Blanket Customer Order:

```text
co_mst.type = B
```

and matching rows exist in both `coitem_mst` and `co_bln_mst`.

## Locked UAT source rows

Do not New Batch or Re-Parse while the CSV file is unchanged.

```text
Row 1: DEV4 | cust_po DEV4-216 | PLG | AC20002B | 375 PCS
Row 2: DEV4 | cust_po DEV4-216 | PLG | AC20003B | 120 PCS
```

Parser result already confirmed:

```text
Rows=2, FormatErrors=0
```

Patch 13 Rev.3 has already been applied and normalizes the standard Mongoose `SiteRef` on parsed detail rows before the one-hit preflight. The source/business field `siteref` is not required to be present in the CSV.

---

## 1. Optional pre-run Query Select — confirm Patch 13 effect

Run this as a Query Select, not inside Apply Database:

```sql
SELECT
    d.SiteRef,
    d.batch_id,
    d.row_no,
    d.custnum,
    d.cust_po,
    d.whse,
    d.coline,
    d.item,
    d.qty_ordered,
    d.u_m,
    d.upload_status,
    d.result_message
FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
WHERE d.batch_id = N'CSV-20260909-072038-835E3D'
ORDER BY d.row_no;
```

Expected before/after the one-hit call:

- exactly 2 rows;
- `SiteRef` aligned to the active site after `SMK069RunCsvTestBatchSp` starts;
- the business CSV field `siteref` may remain blank and is not the Patch 13 acceptance criterion.

---

## 2. Execute the existing batch through CSV one-hit

IDO method:

```text
ue_SMK069TempSales.SMK069RunCsvTestBatchSp
```

REST invoke:

```text
POST /IDORequestService/ido/invoke/ue_SMK069TempSales?method=SMK069RunCsvTestBatchSp
```

When method metadata exposes all 11 parameters, use:

```json
[
  "CSV-20260909-072038-835E3D",
  "POS_API",
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null
]
```

If the tenant still exposes the older 10-parameter metadata, omit only the final `null` for `CreatedCoNums`.

The method must remain **NOT Transactional** because the per-order Customer Order processor owns its own transaction boundary.

---

## 3. Success gate from the method response

Capture these outputs exactly:

```text
ReturnValue
ReceivedRows
TotalOrders
ValidationValidOrders
ValidationErrorOrders
TransferredRows
ProcessedOrders
ProcessErrorOrders
Infobar
CreatedCoNums
```

Clean success should normally show:

```text
ReturnValue          = 0
ReceivedRows         = 2
TotalOrders          = 1
ValidationValidOrders= 1
ValidationErrorOrders= 0
TransferredRows      = 2
ProcessedOrders      = 1
ProcessErrorOrders   = 0
CreatedCoNums        = CO26....
```

For an idempotent retry after a prior partial run, `SkippedOrders` may appear inside `Infobar`. Do not create a new batch only because a retry reports already-processed work.

If the response is not clean success, preserve the entire `Infobar` and all output counts before applying any further patch.

---

## 4. Verify staging after one-hit

Use Query Select:

```sql
SELECT
    t.SiteRef,
    t.co_num,
    t.cust_num,
    t.cust_po,
    t.co_line,
    t.item,
    t.qty_ordered,
    t.u_m,
    t.process_status,
    t.validation_msg,
    t.error_msg,
    t.retry_count,
    t.processed_date
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND
  (
      t.cust_po = N'DEV4-216'
      OR t.co_num IN
         (
             SELECT DISTINCT CONVERT(NVARCHAR(60), v.co_num)
             FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
             WHERE v.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
               AND v.batch_id = N'CSV-20260909-072038-835E3D'
         )
  )
ORDER BY t.co_num, t.co_line;
```

Desired state for the order is:

```text
process_status = P
```

If it remains `V` or becomes `E`, the staging message is the next diagnostic input; do not New Batch.

---

## 5. Verify the generated Blanket Customer Order

Replace `<CREATED_CO_NUM>` with the exact value returned in `CreatedCoNums`.

### Header — `co_mst`

```sql
SELECT
    c.site_ref,
    c.co_num,
    c.type,
    c.cust_num,
    c.cust_po,
    c.order_date,
    c.whse,
    c.terms_code,
    c.curr_code,
    c.price
FROM dbo.co_mst AS c
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.co_num = N'<CREATED_CO_NUM>';
```

Required:

```text
1 row
co_mst.type = B
```

### Standard CO lines — `coitem_mst`

```sql
SELECT
    i.site_ref,
    i.co_num,
    i.co_line,
    i.item,
    i.qty_ordered,
    i.u_m,
    i.whse,
    i.price
FROM dbo.coitem_mst AS i
WHERE i.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND i.co_num = N'<CREATED_CO_NUM>'
ORDER BY i.co_line;
```

Expected from this UAT source:

```text
2 lines
AC20002B = 375 PCS
AC20003B = 120 PCS
```

### Blanket lines — `co_bln_mst`

```sql
SELECT
    b.site_ref,
    b.co_num,
    b.co_line,
    b.item,
    b.blanket_qty,
    b.u_m,
    b.cont_price,
    b.stat,
    b.whse,
    b.ship_site,
    b.allow_on_pick_list
FROM dbo.co_bln_mst AS b
WHERE b.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND b.co_num = N'<CREATED_CO_NUM>'
ORDER BY b.co_line;
```

Required:

```text
2 matching blanket lines
stat = O
allow_on_pick_list = 0
```

---

## 6. Batch result snapshot

After the run:

```sql
SELECT
    b.SiteRef,
    b.batch_id,
    b.batch_status,
    b.received_rows,
    b.total_orders,
    b.validation_valid_orders,
    b.validation_error_orders,
    b.transferred_rows,
    b.processed_orders,
    b.process_error_orders,
    b.result_message,
    b.started_date,
    b.completed_date
FROM dbo.ue_SMK069_pos_csv_batch_mst AS b
WHERE b.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND b.batch_id = N'CSV-20260909-072038-835E3D';
```

Interpretation:

```text
C = complete
P = partial
E = failed / run did not complete
R = running
```

## Next decision

- If `CreatedCoNums` is returned and all three target tables match, record UAT evidence and close the CSV → Blanket CO functional gate.
- If validation fails, fix only the proven master/source issue; preserve the same batch when idempotent retry is valid.
- If Process fails after staging reaches `V`/`E`, patch the proven failure in the CSV-to-CO workstream only.
- Do not mix Shipment changes into this UAT.
