# 25 — Deploy Partial Success + CSV → Customer Order

> **Date:** 4 September 2026
> **Design:** `docs/26-partial-success-and-csv-to-customer-order.md`
> **Patches:**
> `database/patches/2026-09-04-smk069-01-create-process-batch-customer-orders.sql`
> `database/patches/2026-09-04-smk069-02-patch-receive-and-process.sql`
> `database/patches/2026-09-04-smk069-03-patch-run-csv-test-batch.sql`

Apply in that order. Patches 02 and 03 both depend on 01.

---

## 1. Pre-flight

### 1.1 Confirm the transaction flag

Open `IDOs` → `ue_SMK069TempSales` → Methods.

```text
SMK069ReceiveAndProcessPosSalesJsonSp
    Method Type   : Stored Procedure - Standard Method
    Transactional : MUST NOT be checked
```

Verified unchecked on 4 Sep 2026. If any future method calls these procedures,
it carries the same requirement — see `docs/26` §9 for what breaks otherwise.

### 1.2 Confirm the parameter list is complete

Scroll the Parameters grid to the end. `SMK069ReceiveAndProcessPosSalesJsonSp`
must show **12** parameters in this order:

```text
1  SourceSystem      7  ValidOrders
2  BatchId           8  ValidationErrors
3  PayloadJson       9  TransferredRows
4  ReceivedBy       10  ProcessedOrders
5  ReceivedRows     11  ProcessErrors
6  TotalOrders      12  Infobar
```

The metadata labels diverge from the SQL parameter names in places
(`ReceivedBy` vs `@RequestedBy`, `ValidationValidOrders` vs `@ValidOrders`).
Mongoose binds Stored Procedure methods **by position**, so this is cosmetic —
but if positions 10–12 are missing, `ProcessedOrders`, `ProcessErrors` and
`Infobar` will never reach the caller and the whole change will look broken.

### 1.3 Diff the parameter blocks before applying

Patches 02 and 03 are full `CREATE OR ALTER` statements. Compare their parameter
blocks against the tenant first:

```sql
SELECT
    p.name        AS procedure_name,
    pr.name       AS parameter_name,
    pr.parameter_id,
    TYPE_NAME(pr.user_type_id) AS data_type,
    pr.is_output
FROM sys.procedures AS p
JOIN sys.parameters AS pr ON pr.object_id = p.object_id
WHERE p.name IN
      (
          N'SMK069ReceiveAndProcessPosSalesJsonSp',
          N'SMK069RunCsvTestBatchSp'
      )
ORDER BY p.name, pr.parameter_id;
```

Positions 1–12 (patch 02) and 1–10 (patch 03) must be preserved exactly.
`@CreatedCoNums` is appended after them **with a default**, so existing method
metadata keeps binding without any change. Add it to the IDO method only when
you want the co_num list returned.

### 1.4 Record the current stranded rows

Capture this before deploying — after the change these rows get picked up, and
you want the before/after evidence:

```sql
SELECT t.co_num, t.cust_po, COUNT(*) AS lines, MIN(t.CreateDate) AS since
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.process_status = N'V'
GROUP BY t.co_num, t.cust_po
ORDER BY MIN(t.CreateDate);
```

### 1.5 Check for other callers of the removed THROW

```sql
SELECT p.name
FROM sys.sql_modules AS m
JOIN sys.procedures AS p ON p.object_id = m.object_id
WHERE m.definition LIKE '%SMK069ReceiveAndProcessPosSalesJsonSp%'
  AND p.name <> N'SMK069ReceiveAndProcessPosSalesJsonSp';
```

If `SMK069ReceivePosSalesJsonHttpSp` appears, read it before applying patch 02 —
it may translate `THROW 51071` into an HTTP status.

---

## 2. Apply

Run each file separately in **Apply Database**, in order. Apply Database reports
execution status only; it does not display `SELECT` grids. Use **Query
Execution** for every verification query in this document.

```text
01 → CREATE OR ALTER dbo.SMK069ProcessBatchCustomerOrdersSp
02 → CREATE OR ALTER dbo.SMK069ReceiveAndProcessPosSalesJsonSp
03 → CREATE OR ALTER dbo.SMK069RunCsvTestBatchSp
```

Expected after each: *Command completed successfully*.

Then confirm all three compiled and are Site-aware:

```sql
SELECT
    p.name,
    p.modify_date,
    CASE WHEN m.definition LIKE '%CONTEXT_INFO%' THEN 'YES' ELSE 'NO' END
        AS HasSiteContext
FROM sys.procedures AS p
JOIN sys.sql_modules AS m ON m.object_id = p.object_id
WHERE p.name IN
      (
          N'SMK069ProcessBatchCustomerOrdersSp',
          N'SMK069ReceiveAndProcessPosSalesJsonSp',
          N'SMK069RunCsvTestBatchSp'
      )
ORDER BY p.name;
```

`SMK069ProcessBatchCustomerOrdersSp` is called only from other procedures, so it
needs no IDO method of its own. No cache refresh is required unless you change
method metadata.

---

## 3. UAT matrix

Run in this order. Do not skip C01 — it is the regression guard for the stable
JSON path.

| # | Scenario | Expected |
|---|---|---|
| C01 | JSON batch, all orders valid | `ReturnValue 0`; `ProcessedOrders = TotalOrders`; `ProcessErrors 0`; Infobar starts `[POS-000]`, no `PARTIAL` |
| C02 | JSON batch, one order with an unmapped item | `ReturnValue 0`; Infobar contains `PARTIAL`; valid orders become COs; bad order stays `inbound_status = 'E'` |
| C03 | JSON batch, every order invalid | `THROW 51070`; nothing in temp for that batch |
| C04 | Re-run C02 with the same `batch_id`, master data still broken | `ProcessedOrders 0`; `SkippedOrders` = orders already done; no duplicate CO |
| C05 | Fix the master data, re-run C02 same `batch_id` | remaining order becomes a CO; `SkippedOrders` covers the earlier ones; still no duplicates |
| C06 | CSV batch, all rows valid | `batch_status = 'C'`; `processed_orders` filled; `upload_status = 'S'` on every row |
| C07 | CSV batch, one bad `coline` | `batch_status = 'P'`; good orders become COs; only the owning order's rows show `upload_status = 'E'` |
| C08 | CSV batch, all rows bad | `batch_status = 'E'`; `RETURN 16`; `processed_orders 0` |
| C09 | Pre-existing stranded batch from §1.4, re-run | stranded `'V'` orders become COs |
| C10 | Same `cust_po` under two different Sites | no cross-site collision |

### C07 sample CSV

```csv
custnum,order_date,cust_po,whse,coline,item,qty_ordered,u_m
DEV4,2026-09-04,DEV4-901,MAIN,1,AA00024C,10,CTN
DEV4,2026-09-04,DEV4-902,MAIN,1,AA00024C,5,CTN
DEV4,2026-09-04,DEV4-903,MAIN,1,ITEM-TIDAK-ADA,1,CTN
```

Expected: `DEV4-901` and `DEV4-902` become Customer Orders. `DEV4-903` stays
error. `batch_status = 'P'`, `processed_orders = 2`, `process_error_orders = 0`,
`validation_error_orders = 1`.

Note which counter moves: an unmapped item fails at **validation**, so it lands
in `validation_error_orders`, not `process_error_orders`. To exercise
`process_error_orders` you need an order that passes the mapping view but fails
inside `SMK069ProcessCustomerOrderSp` — for example a warehouse missing from
`whse_mst` for that Site.

### Verification after each run

```sql
-- per-order outcome
SELECT t.co_num, t.cust_po, t.process_status, t.retry_count,
       LEFT(t.error_msg, 200) AS error_msg
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
ORDER BY t.co_num, t.co_line;

-- CSV batch header
SELECT batch_id, batch_status, received_rows, total_orders,
       validation_valid_orders, validation_error_orders, transferred_rows,
       processed_orders, process_error_orders, LEFT(result_message, 500) AS msg
FROM dbo.ue_SMK069_pos_csv_batch_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
ORDER BY completed_date DESC;

-- created Customer Orders
SELECT c.co_num, c.cust_num, c.cust_po, c.[type], c.stat, c.order_date
FROM dbo.co_mst AS c
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.cust_po IN (N'DEV4-901', N'DEV4-902', N'DEV4-903');
```

---

## 4. Duplicate check for C04 and C05

The retry tests are the point of this change; verify no second Customer Order
was created:

```sql
SELECT c.cust_po, COUNT(*) AS header_count
FROM dbo.co_mst AS c
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.[type] = N'B'
  AND c.cust_po LIKE N'DEV4-9%'
GROUP BY c.cust_po
HAVING COUNT(*) > 1;
```

Must return zero rows.

---

## 5. Rollback

Each patch is a `CREATE OR ALTER`. To revert, re-apply the previous definitions
captured before deployment:

```sql
SELECT definition FROM sys.sql_modules
WHERE object_id = OBJECT_ID('dbo.SMK069ReceiveAndProcessPosSalesJsonSp');

SELECT definition FROM sys.sql_modules
WHERE object_id = OBJECT_ID('dbo.SMK069RunCsvTestBatchSp');
```

**Capture both before applying anything.** Save them under
`database/procedures/` so the repository finally holds the tenant truth — the
CHANGELOG has carried `[PENDING] synchronize exact final Cloud SP source into
repository SQL file` since August.

Reverting leaves `SMK069ProcessBatchCustomerOrdersSp` in place; it is inert once
nothing calls it, and can be dropped separately.

Rolling back does **not** undo Customer Orders already created. It only restores
the old wrapper behaviour, which means any partially-processed batch returns to
being stranded.

---

## 6. Stop point

Do not expose a new public API endpoint for the CSV path until:

```text
[ ] parameter positions verified per §1.2 and §1.3
[ ] previous SP definitions captured per §5
[ ] C01 passes — the stable JSON path is unchanged for a clean batch
[ ] C02, C04, C05 pass — partial and retry behave as designed
[ ] C06, C07, C08 pass — the CSV path reaches Customer Order
[ ] C09 confirms stranded rows are recovered
[ ] the caller (form script or API consumer) reads ProcessErrors and
    ValidationErrorOrders, not ReturnValue alone
```

The last line is the one most likely to be forgotten. A partial batch now
returns `0`, and a consumer that only checks `ReturnValue` will report a batch
with failed orders as a clean success.
