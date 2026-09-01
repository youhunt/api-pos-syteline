# SMK069 Mapping View as Single Business Source

**Date:** 1 September 2026

## Decision

All business/mapped values for POS inbound and Customer Order processing now come from:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

`dbo.ue_SMK069_pos_sales_inbound_mst` remains the raw landing/audit table because the mapping view is built from those rows. It is not the mapped business source for customer, customer sequence, item, U/M, price, warehouse, terms, tax, quantity, dates, or CO-line values.

The stored procedures must not duplicate customer/item/price mapping against:

```text
custaddr_mst
itemcust_mst
itemcustprice_mst
```

Those mappings are owned by the mapping view.

## Final flow

### JSON / Postman

```text
JSON
-> SMK069ReceivePosSalesJsonSp
-> ue_SMK069_pos_sales_inbound_mst       (RAW landing/audit only)
-> ue_SMK069_pos_sales_inbound_mapping_view
-> ue_SMK069_temp_sales_mst
-> SMK069ProcessCustomerOrderSp
-> co_mst type B
-> coitem_mst
-> co_bln_mst
```

### CSV

```text
CSV
-> SMK069ImportCsvFileSp                  (RAW parser only)
-> ue_SMK069_pos_csv_upload_mst
-> SMK069RunCsvTestBatchSp
-> raw JSON
-> SMK069ReceivePosSalesJsonSp
-> mapping view
-> temp
-> Process/Reprocess
-> SMK069ProcessCustomerOrderSp
-> co_mst / coitem_mst / co_bln_mst
```

## SP revisions prepared

```text
SMK069ReceivePosSalesJsonSp
  V2.4 - Mapping View Is Business Source

SMK069RunCsvTestBatchSp
  V2.5 - Mapping View Is Business Source

SMK069ProcessCustomerOrderSp
  V2.8 - Mapping View Is Business Source

SMK069ReceiveAndProcessPosSalesJsonSp
  V1.0 - optional end-to-end JSON/Postman wrapper
```

`SMK069ImportCsvFileSp` remains the current V2 raw CSV parser. It must not contain business mapping logic.

## Mapping-view contract

The mapping view must expose the final business values used downstream:

```text
SiteRef
cust_num
cust_seq
cust_po
order_date
co_num
co_line
item
qty_ordered
unit_price
whse
due_date
u_m
terms_code
tax_code1
exch_rate
```

The value exposed as `item` must be the final SyteLine item expected by `coitem_mst.item` and `co_bln_mst.item`. Stored procedures will no longer remap that field through `itemcust_mst`.

## Important implementation detail

Receive still writes raw values and generated `co_num` to `ue_SMK069_pos_sales_inbound_mst` because the canonical view itself selects from that landing table. This does not make inbound_mst the business source. After landing, validation, temp transfer, and CO creation consume the mapping-view values.

## UAT sequence

1. Apply Receive V2.4.
2. Apply RunCsv V2.5.
3. Apply Process V2.8.
4. Optionally apply ReceiveAndProcess wrapper.
5. Use a new BatchId for every changed mapping/view UAT.
6. Verify the mapping view first.
7. Verify temp values equal the view.
8. Process the generated CO.
9. Verify `co_mst.type='B'`, `coitem_mst`, and `co_bln_mst` all use the mapping-view values.


---

## Addendum - Release Date and CO Prefix

### Release Date

UAT on Blanket Customer Order `R260822007` showed the Customer Order line
`Release Date` was blank even though the CO header had an `order_date`.

The processing rule is now:

```text
coitem_mst.release_date = co_mst.order_date
```

For new CO creation, `SMK069ProcessCustomerOrderSp` inserts
`coitem_mst.release_date` from the resolved header `@OrderDate`.

For an already existing matching CO, Process/Reprocess also repairs
`coitem_mst.release_date` when it is NULL, using the existing
`co_mst.order_date`.

### CO Prefix

The current numbering format is unchanged:

```text
R + YYMM + 5-digit running
example: R260900001
```

The Receive procedure now isolates the business prefix in one variable:

```sql
@OrderPrefix = N'R'
```

and builds the period prefix from that value. This makes a future controlled
single-prefix change localized to the Receive number-generation block.

The generated CO length is guarded so a future longer prefix is not silently
truncated. A format change that increases the total CO number length must first
be checked against the tenant `CoNumType`/physical column length.


---

## Addendum - API HTTP Status and Idempotent Error Replay

### Problem

A business-validation failure can still appear as a technically successful
Mongoose IDO invocation:

```text
HTTP 200
Success = true
ErrorOrders = 1
TransferredRows = 0
```

This happens because the stored procedure can return normally even though the
business order failed validation.

A retry of the same `BatchId` also previously added wording such as:

```text
sudah pernah diterima; tidak diproses ulang
```

which made an idempotent retry look like a second/new error.

### Core Receive revision

`SMK069ReceivePosSalesJsonSp V2.4.2` now:

- keeps raw inbound + validation results persisted;
- returns `16` when business validation fails;
- returns `0` only when the order is valid and transferred;
- returns the same business result on an idempotent replay;
- removes the extra "already received/not processed again" wording from the
  replay response.

This is the safe core behavior for CSV/internal callers.

### Non-200 REST wrapper

A separate wrapper is prepared:

```text
dbo.SMK069ReceivePosSalesJsonHttpSp
```

The wrapper calls the core Receive and raises an unhandled SQL exception when
the returned business result is failure.

**Important:** expose this wrapper as a **NON-TRANSACTIONAL IDO method**. Infor
Mongoose can run IDO methods transactionally or non-transactionally; using the
non-transactional setting allows the core Receive to persist/commit the inbound
error result before the wrapper raises the REST/IDO exception. If the wrapper
is configured Transactional, the outer IDO transaction may roll back those
persisted error rows when the exception is raised.

The expected result is a non-200 REST invocation failure instead of
`HTTP 200 / Success=true`.

For a specific semantic HTTP code such as `422 Unprocessable Entity`, a custom
REST/API gateway layer is required; the standard stored-procedure/IDO invoke
path does not directly control arbitrary HTTP status codes.
