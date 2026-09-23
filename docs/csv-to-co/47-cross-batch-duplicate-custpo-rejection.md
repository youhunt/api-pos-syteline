# Cross-batch duplicate CustPO rejection

**Date:** 23 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Proven defect

Existing transaction:

```text
cust_po = DEV4-259
CO      = P260922004
```

Database state:

```text
co_mst:
P260922004 / DEV4-259 / type B

temp:
created_co_num = P260922004
process_status = P
```

The same business CustPO was then submitted under:

```text
BatchId = DEV4-299
cust_po = DEV4-259
```

A replay returned:

```text
Success          = true
POS-000
ProcessedOrders  = 0
ProcessErrors    = 0
SkippedOrders    = 1
CreatedCoNums    = <none>
```

No second CO was created, so data idempotency was preserved. However the public result was wrong: a **new/different BatchId** made an already-existing CustPO look like a clean new success.

## Final contract

```text
cust_po = business idempotency key
batch_id = transport/request identity
```

Rules:

```text
same original successful BatchId + same CustPO
→ may replay idempotently
→ no duplicate CO

different/new BatchId + already-created CustPO
→ POS-204
→ Success=false for API
→ no new CO
```

For multi-order payloads, a duplicate CustPO is rejected atomically while unrelated valid CustPOs may continue.

## Distinguishing original replay vs cross-batch duplicate

The current schema does not persist `batch_id` on the created CO or temp row. Patch 32 therefore uses persisted timestamps that already exist:

```text
co_mst.RecordDate
ue_SMK069_pos_sales_inbound_mst.CreateDate
```

Interpretation:

```text
current BatchId has inbound rows created before/equal to CO RecordDate
→ original batch / legitimate replay

current BatchId has no prior inbound row, or its inbound CreateDate is after CO RecordDate
→ cross-batch duplicate
→ POS-204
```

This also repairs UAT batches created by the previous behavior, such as `DEV4-299`, whose inbound rows were created after `P260922004` already existed.

## Patch

```text
database/patches/csv-to-co/
2026-09-23-smk069-32-reject-cross-batch-duplicate-custpo.sql
```

Expected Apply Database message:

```text
[PATCH-32] SUCCESS - existing CustPO pada BatchId baru ditolak sebagai POS-204; original-batch replay tetap idempotent.
```

## UAT

### A. Cross-batch duplicate

Use:

```text
BatchId = DEV4-299
CustPO  = DEV4-259
```

Expected:

```text
POS-204
Success=false
ProcessedOrders=0
no new CO
```

### B. Original successful batch replay

Replay the exact original successful request using its original BatchId.

Expected:

```text
no duplicate CO
idempotent skip/reuse is allowed
```

### C. New business transaction

Use both a new BatchId and a new CustPO.

Expected:

```text
normal validation and processing
new PYYMMDD### CO when valid
```
