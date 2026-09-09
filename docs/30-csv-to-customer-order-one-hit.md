# SMK069 CSV to Customer Order — One-Hit Flow

**Updated:** 9 September 2026  
**Repository:** `youhunt/api-pos-syteline`

## Purpose

Document the current stable CSV -> Customer Order path used by `SMK069RunCsvTestBatchSp`.

The CSV runner processes one CSV batch that has already been parsed into the SMK069 CSV staging tables and creates SyteLine Customer Orders for all valid atomic orders in the batch.

```text
CSV file
  -> ue_SMK069_pos_csv_batch_mst / ue_SMK069_pos_csv_upload_mst
  -> SMK069RunCsvTestBatchSp
  -> SMK069ReceivePosSalesJsonCoreSp
  -> ue_SMK069_temp_sales_mst
  -> SMK069ProcessBatchCustomerOrdersSp
  -> SMK069ProcessCustomerOrderSp
  -> co_mst / coitem_mst / co_bln_mst
```

> `SMK069RunCsvTestBatchSp` does not receive the binary `.csv` file directly. The CSV must already be parsed/loaded into `ue_SMK069_pos_csv_batch_mst` and `ue_SMK069_pos_csv_upload_mst`.

## Entry Point

Stored procedure:

```text
SMK069RunCsvTestBatchSp
```

Typical Mongoose IDO method:

```text
ue_SMK069TempSales.SMK069RunCsvTestBatchSp
```

REST invoke example:

```text
POST /IDORequestService/ido/invoke/ue_SMK069TempSales?method=SMK069RunCsvTestBatchSp
```

## Parameter Contract

| Seq | Parameter | Direction | Type | Required | Meaning |
|---:|---|---|---|---|---|
| 1 | `BatchId` | IN | `NVARCHAR(100)` | Yes | Existing CSV batch id / idempotency key |
| 2 | `RequestedBy` | IN | `NVARCHAR(128)` | No | Integration identity, e.g. `POS_API` |
| 3 | `ReceivedRows` | OUT | `INT` | No | CSV detail rows received by Core |
| 4 | `TotalOrders` | OUT | `INT` | No | Distinct atomic orders |
| 5 | `ValidationValidOrders` | OUT | `INT` | No | Orders that passed validation |
| 6 | `ValidationErrorOrders` | OUT | `INT` | No | Orders rejected by validation |
| 7 | `TransferredRows` | OUT | `INT` | No | Valid lines transferred to processing temp |
| 8 | `ProcessedOrders` | OUT | `INT` | No | Orders successfully processed to Customer Order |
| 9 | `ProcessErrorOrders` | OUT | `INT` | No | Orders that failed Customer Order processing |
| 10 | `Infobar` | OUT | `NVARCHAR(4000)` | No | Batch result / partial-success detail |
| 11 | `CreatedCoNums` | OUT | `NVARCHAR(MAX)` | No | Customer Order numbers returned by the processing loop; defaulted for backward-compatible 10-parameter metadata |

## Postman Request Body

When IDO metadata exposes all 11 parameters:

```json
[
  "CSV-UAT-20260909-001",
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

If the tenant still uses the older 10-parameter metadata, omit the final `null` for `CreatedCoNums`.

Headers:

```text
Content-Type: application/json
Authorization: <Mongoose security token>
```

## Required CSV Contract V2 Fields

Every CSV detail row must already contain:

```text
custnum
order_date
cust_po
whse
coline
item
qty_ordered
u_m
```

Optional supported fields:

```text
due_date
terms_code
tax_code1
exch_rate
```

## Result Status

| Condition | Batch Status | Meaning |
|---|---|---|
| Running | `R` | Batch is currently executing |
| All orders processed | `C` | Every valid order reached Customer Order processing successfully |
| Partial success | `P` | At least one order succeeded while another failed validation or processing |
| Nothing landed | `E` | No valid rows reached processing temp / no Customer Order could be created |

## Retry / Idempotency

- Re-run the same `BatchId`; a new batch id is not required for retry.
- Receive is idempotent and does not duplicate already accepted source data.
- Orders already at `process_status = 'P'` are skipped.
- Only orders still at `V` or `E` are picked up for processing.
- Each order is processed independently through `SMK069ProcessCustomerOrderSp`; one failed order does not invalidate Customer Orders already created for other orders in the same batch.
- The calling IDO method must **NOT** be marked Transactional because `SMK069ProcessCustomerOrderSp` owns its own transaction boundary.

## Verification

Use `CreatedCoNums`, then verify the resulting Customer Orders through:

```text
GET /json/SLCos/adv
GET /json/SLCoitems/adv
```

Confirm the expected rows exist in:

```text
co_mst
coitem_mst
co_bln_mst
```

## Source Implementation

Primary implementation artifacts:

```text
database/patches/2026-09-04-smk069-03-patch-run-csv-test-batch.sql
database/patches/2026-09-04-smk069-01-create-process-batch-customer-orders.sql
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
