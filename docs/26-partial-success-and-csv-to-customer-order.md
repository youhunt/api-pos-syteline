# 26 — Partial Success and CSV → Customer Order in One Call

> **Date:** 4 September 2026
> **Repository:** `youhunt/api-pos-syteline`
> **Supersedes for this topic:** the "Customer Order belum dibuat; lanjutkan Process/Reprocess" behaviour described in `docs/23-smk069-development-recap-through-2026-08-31.md` §26.
> **Does not change:** `SMK069ReceivePosSalesJsonCoreSp`, `SMK069ProcessCustomerOrderSp`, `SMK069ImportCsvFileSp`, the POS inbound data contract, or the `POS-xxx` result-code vocabulary.

---

## 1. What this change delivers

Two things that were previously separate calls become one:

```text
CSV upload → parse → receive → validate → Customer Order
JSON POST  → receive → validate → Customer Order
```

and both run the same Process loop instead of two copies of it.

Failure granularity becomes **per Customer Order**. One bad `coline` fails only
the order that owns it. The rest of the batch still becomes Customer Orders.

---

## 2. Why this was mostly already true

`SMK069ReceivePosSalesJsonCoreSp` has always validated each atomic order
(`SiteRef` + `cust_po`) independently and transferred only the valid ones:

```sql
INSERT INTO dbo.ue_SMK069_temp_sales_mst (...)
SELECT ... FROM #MapView v
INNER JOIN ue_SMK069_pos_sales_inbound_mst i ON i.inbound_id = v.inbound_id
WHERE ... AND i.inbound_status = N'V';
```

and it commits that work before reporting a business failure:

```sql
IF @InitialTranCount = 0
    COMMIT TRANSACTION;

IF ISNULL(@ErrorOrders, 0) > 0
   OR ISNULL(@ValidOrders, 0) = 0
   OR ISNULL(@TransferredRows, 0) = 0
    RETURN 16;
```

`SMK069ProcessCustomerOrderSp` is likewise per-order: it opens its own
transaction, and on failure rolls back only its own order, stamps
`process_status = 'E'` with `retry_count + 1`, and returns `@Success = 0`
without throwing.

So both engines were already partial. Only the two wrappers were not.

---

## 3. The defect this fixes

Take a batch of ten orders where one fails validation.

| Step | What happened |
|---|---|
| 1 | Core validates per order — nine valid, one error |
| 2 | Core writes nine orders to `ue_SMK069_temp_sales_mst`, `process_status = 'V'`, `co_num` generated |
| 3 | Core **commits** |
| 4 | Core returns `16` because `@ErrorOrders > 0` |
| 5 | Wrapper sees `16` → `THROW 51070` (JSON) or `batch_status = 'E'` (CSV) |
| 6 | Process is never called |

The nine orders are **stranded**: committed, numbered, and unreachable.

They also poison later attempts:

- re-sending the same `batch_id` hits Core's idempotent replay branch, which
  recomputes the same counts and returns `16` again;
- re-sending under a **new** `batch_id` is rejected at Core step 7 with
  `[POS-204] cust_po sudah sedang/pernah diproses`, precisely because those
  `cust_po` values are already sitting in temp.

The only escape was calling `SMK069ProcessCustomerOrderSp` manually per order.

To find rows stranded by earlier runs:

```sql
SELECT t.co_num, t.cust_po, COUNT(*) AS lines, MIN(t.CreateDate) AS since
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.process_status = N'V'
GROUP BY t.co_num, t.cust_po
ORDER BY MIN(t.CreateDate);
```

Old `CreateDate` on a `'V'` row means the batch that created it reported failure
and walked away. After this change, re-running that batch picks them up.

---

## 4. The discriminator: `@TransferredRows`

Core returns `16` for two unrelated situations. They must not be treated alike:

| Situation | `@TransferredRows` | Correct handling |
|---|---|---|
| Total failure — bad Site, malformed JSON, `CATCH` | `0` | reject the batch, nothing landed |
| Partial — some orders invalid, others transferred | `> 0` | continue to Process |

Every wrapper gate is therefore reduced to:

```sql
IF ISNULL(@TransferredRows, 0) = 0     -- the only real failure
```

`@ValidationErrorOrders > 0` is no longer a batch-level rejection. It is a
count to report.

---

## 5. New object

### `dbo.SMK069ProcessBatchCustomerOrdersSp`

The order loop, lifted out of `SMK069ReceiveAndProcessPosSalesJsonSp` so the
JSON and CSV paths share one implementation.

| Parameter | Dir | Meaning |
|---|---|---|
| `SourceSystem` | In | normally `POS`; CSV passes its normalised value |
| `BatchId` | In | batch to process |
| `ProcessedBy` | In | integration identity |
| `ProcessedOrders` | Out | orders that became a Customer Order in this run |
| `ProcessErrors` | Out | orders that failed in this run |
| `SkippedOrders` | Out | orders already at `process_status = 'P'` |
| `FirstErrorCode` | Out | first `POS-xxx` seen, or `POS-301` |
| `ProcessDetail` | Out | `CO <num>: <message>` per failed order |
| `CreatedCoNums` | Out | comma-separated generated numbers |

Two behavioural differences from the old inline loop:

**Already-processed orders are skipped.** The old cursor took every order of the
batch. Because Process is idempotent the data stayed correct, but a retry that
fixed one order reported ten successes. The new loop only walks orders whose
temp rows are still `'V'` or `'E'`, and reports the rest as `SkippedOrders`.

**Created numbers are returned.** Previously the caller received counts but not
the `co_num` values, which is what an operator actually needs.

---

## 6. Result contract

| Outcome | ReturnValue | Infobar |
|---|---|---|
| Every order became a CO | `0` | `[POS-000] …` |
| Some orders failed validation or Process | `0` | `[POS-xxx] PARTIAL. …` |
| Nothing landed | `16` (CSV) / `THROW 51070` (JSON) | `[POS-xxx] … gagal.` |

**A caller must branch on `ValidationErrorOrders` and `ProcessErrors`, not on
`ReturnValue` alone.** This is a deliberate change to the stable contract: a
batch that is partly good now reports `0` where it previously reported failure.
The literal token `PARTIAL` is present in the Infobar so a partial batch is
never mistaken for a clean one in a log or a form message.

`THROW 51071` is removed. Per-order Process failures are already recorded in
`ue_SMK069_temp_sales_mst`; throwing aborted the T-SQL batch and discarded every
OUTPUT parameter, so the caller could not tell what succeeded.

`THROW 51070` is kept for total failure, preserving the hard-error behaviour any
existing caller may depend on.

---

## 7. `batch_status` gains `P`

`ue_SMK069_pos_csv_batch_mst.batch_status`:

| Code | Meaning |
|---|---|
| `R` | running |
| `C` | complete — every order became a Customer Order |
| `P` | **new** — partial; some orders failed, the rest are done |
| `E` | nothing landed |

`processed_orders` and `process_error_orders` were previously written as the
literals `0, 0`. They now carry the real numbers.

`ue_SMK069_pos_csv_upload_mst.upload_status` was one value stamped across the
whole batch. It is now per row: `'S'` when that row's `cust_po` reached
`inbound_status = 'T'`, otherwise `'E'`.

---

## 8. Retry

**Call the same procedure again with the same `batch_id`.**

Core takes its idempotent replay branch and writes nothing. The Process loop
then picks up only orders still at `'V'` or `'E'`. Orders already at `'P'` are
skipped and counted separately. `SMK069ProcessCustomerOrderSp` recognises an
existing Customer Order rather than creating a second one.

Consequences worth stating plainly:

- the operator does **not** need to cut the CSV down to the failed rows;
- a retry also rescues orders stranded by runs made before this change;
- validation failures are **not** fixed by retrying — the master data must be
  corrected first (item, U/M, warehouse, tax code, customer), or the source row
  corrected and re-uploaded as a new batch.

The alternative retry path remains available and unchanged: correct the master
data and press Reprocess on the `ue_SMK069APISalesErrorProcessing` form for
orders at `process_status = 'E'`.

---

## 9. Transaction requirement

**Every IDO method or form script that calls these procedures must remain
NOT Transactional.**

`SMK069ProcessCustomerOrderSp` issues an unqualified `ROLLBACK TRANSACTION` in
its `CATCH` block. Under an outer Mongoose transaction:

| Statement | Actual effect when nested |
|---|---|
| `BEGIN TRANSACTION` | `@@TRANCOUNT` 1 → 2 |
| `COMMIT TRANSACTION` | `@@TRANCOUNT` 2 → 1; **nothing is durably committed** |
| `ROLLBACK TRANSACTION` | straight to 0; **every earlier order is discarded** |

`ROLLBACK TRANSACTION` without a savepoint always unwinds to the outermost
transaction. Combined with `SET XACT_ABORT ON`, the first failure leaves
`XACT_STATE() = -1` and the remaining cursor iterations run on a dead
transaction. Order 7 failing would destroy orders 1–6 and corrupt 8–10.

`ue_SMK069TempSales.SMK069ReceiveAndProcessPosSalesJsonSp` was verified as
NOT Transactional on 4 September 2026.

---

## 10. Reconciliation impact

The batch is no longer atomic. Finance reconciliation must move from
"`BatchId` X landed completely or not at all" to per-order status:

```sql
SELECT
    t.process_status,
    COUNT(DISTINCT t.co_num) AS orders,
    COUNT(*)                 AS lines
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.co_num IN
  (
      SELECT DISTINCT CONVERT(NVARCHAR(60), v.co_num)
      FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
      WHERE v.SiteRef  = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
        AND v.batch_id = @BatchId
  )
GROUP BY t.process_status;
```

`P` = became a Customer Order. `V` = pending. `E` = failed, retryable.

---

## 11. Deliberately not done

**No scalar function for `POS-xxx` extraction.** The `CHARINDEX('[POS-')`
block is duplicated across Core, `ReceiveAndProcess` and `RunCsvTestBatch`.
Consolidating it would add a new object type to a production tenant for a
cosmetic gain, so the duplication stands. It is a candidate follow-up.

**No change to Core's return codes.** Core keeps returning `16` when
`@ErrorOrders > 0`. That signal is correct at its own level; only the wrappers'
interpretation of it was wrong.

**No `SkippedOrders` on the wrapper signatures.** It is reported inside
`@Infobar` instead, to avoid touching IDO method metadata more than necessary.

---

## 12. Open items

- Confirm no other procedure depends on `THROW 51071`:

  ```sql
  SELECT p.name
  FROM sys.sql_modules AS m
  JOIN sys.procedures AS p ON p.object_id = m.object_id
  WHERE m.definition LIKE '%SMK069ReceiveAndProcessPosSalesJsonSp%'
    AND p.name <> 'SMK069ReceiveAndProcessPosSalesJsonSp';
  ```

  `SMK069ReceivePosSalesJsonHttpSp` is the likely caller to check.

- Decide whether the CSV Test Console form should surface `batch_status = 'P'`
  differently from `C`.

- Postman collection has no request for the CSV path. Adding a
  "4. CSV to Customer Order" folder is pending.

- `docs/23` §26 role table still describes `SMK069RunCsvTestBatchSp` as
  "Build V2 JSON from parsed CSV and call Receive". Update it after UAT.
