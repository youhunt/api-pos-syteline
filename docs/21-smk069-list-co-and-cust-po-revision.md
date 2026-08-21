# SMK069 — List of Customer Orders and `cust_po` Revision

## Status

This document records the API-contract revision identified after the CSV-to-Blanket-Customer-Order documentation was completed.

The revision adds two requirements:

1. One Receive payload may contain a **list of multiple source/POS Customer Orders**, not only multiple lines for one order.
2. A new business field/column named **`cust_po`** must be carried separately from the source/POS order number (`conum`).

This document supplements `docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md` until the master document and runtime SQL are synchronized.

---

## 1. Three identifiers must remain separate

| Identifier | Example | Meaning / target |
|---|---|---|
| `BatchId` | `BATCH-20260807-001` | Receive idempotency key for one inbound batch. |
| `conum` / SourceCoNum | `S01V000001` | Source/POS order identifier. Used to group lines and drive Process once per source order. Stored in inbound/temp `co_num`. |
| `cust_po` | `PO-CUST-00001` | Customer purchase-order business reference. Target mapping: `co_mst.cust_po`. |
| `CreatedCoNum` | `CO26080017` | Generated/existing SyteLine Customer Order number used by `co_mst`, `coitem_mst`, and `co_bln_mst`. |

Critical rule:

```text
conum != cust_po != CreatedCoNum
```

Do not overload `cust_po` with SourceCoNum after the new field is enabled.

---

## 2. Natural POS payload: list of multiple Customer Orders

One Receive call can contain several different `conum` values.

```json
[
  {
    "custnum": "C000001",
    "order_date": "2026-08-03",
    "conum": "S01V000001",
    "cust_po": "PO-CUST-00001",
    "coline": 1,
    "item": "AA00001",
    "qty_ordered": 1,
    "unit_price": 10000
  },
  {
    "custnum": "C000004",
    "order_date": "2026-08-03",
    "conum": "S02V000001",
    "cust_po": "PO-CUST-00002",
    "coline": 1,
    "item": "AA00005-TI",
    "qty_ordered": 1,
    "unit_price": 12000
  }
]
```

For this example:

```text
ReceivedRows = 2
TotalOrders  = 2
```

If both source orders pass validation:

```text
1 x Receive POS Sales Batch
2 x Process Customer Order

Process call 1 -> SourceCoNum S01V000001
Process call 2 -> SourceCoNum S02V000001
```

The number of Process calls is based on the number of distinct valid `SiteRef + conum`, not the number of rows.

---

## 3. CSV contract revision

Recommended CSV column order:

```text
custnum,
order_date,
conum,
cust_po,
coline,
item,
qty_ordered,
unit_price,
siteref,
whse,
due_date,
u_m,
terms_code,
tax_code1,
exch_rate
```

One-line form:

```csv
custnum,order_date,conum,cust_po,coline,item,qty_ordered,unit_price,siteref,whse,due_date,u_m,terms_code,tax_code1,exch_rate
```

`cust_po` is independent from `conum`.

---

## 4. Required data propagation for `cust_po`

The new field must be carried end-to-end through the custom layer:

```text
CSV / JSON payload cust_po
-> CSV detail cust_po
-> inbound canonical cust_po
-> temp staging cust_po
-> ProcessCustomerOrder
-> co_mst.cust_po
```

`conum` continues to flow independently:

```text
CSV / JSON conum
-> inbound co_num
-> temp staging co_num
-> SourceCoNum Process parameter
```

Generated SyteLine CO continues to flow independently:

```text
CreatedCoNum
-> co_mst.co_num
-> coitem_mst.co_num
-> co_bln_mst.co_num
-> temp.created_co_num
```

---

## 5. `co_mst` mapping change

Previous temporary design:

```text
co_mst.cust_po = SourceCoNum
```

New target design:

```text
co_mst.cust_po = staging.cust_po / payload cust_po
```

SourceCoNum remains the technical source-order identifier in the custom integration layer.

---

## 6. Idempotency impact — important

The existing Process implementation previously used `co_mst.cust_po = SourceCoNum` as part of existing-CO detection.

That logic is no longer valid when `cust_po` is a real independent business field.

New rule:

```text
Technical source order key = SiteRef + SourceCoNum
Business customer PO       = cust_po
SyteLine order key         = CreatedCoNum
```

Recommended reprocess behavior:

1. If staging `created_co_num` is already populated, use it to verify/reuse the existing SyteLine CO.
2. Receive continues to reject a source order that is already present in processing temp.
3. If staging can later be purged/archive-deleted, long-term cross-batch idempotency needs a dedicated persisted source-order mapping or UET field. Do not use `cust_po` for that technical purpose.

This is an implementation-impact item; documentation has been updated first, but the runtime SQL must also be revised before the new `cust_po` contract is considered production-ready.

---

## 7. Required runtime objects to update

Before enabling `cust_po` in production, synchronize all of the following:

```text
1. CSV detail table / IDO
   - add CustPo property/column

2. inbound table / mapping
   - canonical target_field cust_po
   - source aliases as agreed

3. temp staging table / IDO
   - add cust_po / CustPo

4. SMK069ImportCsvFileSp
   - parse cust_po column

5. SMK069RunCsvTestBatchSp
   - include cust_po when building canonical JSON

6. SMK069ReceivePosSalesJsonSp
   - normalize/preserve cust_po
   - transfer cust_po to temp

7. SMK069ProcessCustomerOrderSp
   - map staging cust_po to co_mst.cust_po
   - remove SourceCoNum-as-CustPo idempotency dependency

8. Error Processing form
   - optionally display Customer PO separately from Source/POS CO Number

9. API documentation
   - include list-of-orders payload
   - include cust_po contract
```

---

## 8. Acceptance checks for the revision

```text
[ ] One Receive payload can contain more than one distinct conum
[ ] TotalOrders counts distinct source orders correctly
[ ] Valid source orders are processed once each
[ ] cust_po is preserved separately from conum
[ ] staging contains both CoNum and CustPo
[ ] co_mst.cust_po equals payload/staging cust_po
[ ] co_mst.co_num uses CreatedCoNum
[ ] coitem_mst.co_num uses CreatedCoNum
[ ] co_bln_mst.co_num uses CreatedCoNum
[ ] reprocess does not rely on co_mst.cust_po = SourceCoNum
[ ] no duplicate CO is created for an unchanged reprocess
```

---

## 9. Example final result

Input:

```text
SourceCoNum = S01V000001
CustPo      = PO-CUST-00001
```

After Process:

```text
co_mst.co_num       = CO26080017
co_mst.cust_po      = PO-CUST-00001
coitem_mst.co_num   = CO26080017
co_bln_mst.co_num   = CO26080017
staging.co_num      = S01V000001
staging.cust_po     = PO-CUST-00001
staging.created_co_num = CO26080017
```

The source order, Customer PO, and SyteLine Customer Order number remain traceable without being conflated.