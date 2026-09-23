# Lineage-based cross-batch duplicate CustPO rejection

**Date:** 23 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Why Patch 32 was withdrawn

Patch 32 tried to distinguish original replay from cross-batch duplicate using
assumed inbound audit timestamps. Tenant schema proved those assumptions wrong.

Actual inbound schema includes:

```text
inbound_id
source_system
batch_id
row_no
SiteRef
cust_po
inbound_status
received_date
...
```

The replacement deliberately avoids timestamp heuristics.

## Proven original lineage

For:

```text
cust_po = DEV4-259
```

tenant data showed:

```text
batch_id          = DEV4-259
first_inbound_id  = 738
inbound_status    = T
CO                = P260922004
```

Therefore the original successful transport identity is available directly from
the earliest transferred inbound row.

## Final rule

For an existing CustPO:

```text
SELECT TOP (1)
  source_system,
  batch_id
FROM ue_SMK069_pos_sales_inbound_mst
WHERE SiteRef = <site>
  AND cust_po = <business cust po>
  AND inbound_status = 'T'
ORDER BY inbound_id
```

That row defines the original source + batch.

Behavior:

```text
same source_system + same original batch_id
→ idempotent replay allowed
→ no duplicate CO

different source_system or different batch_id
+ same CustPO already has co_mst row
→ POS-204
→ no new CO
```

No `CreateDate` or inbound `RecordDate` is used.

## Patch

```text
database/patches/csv-to-co/
2026-09-23-smk069-33-reject-cross-batch-duplicate-custpo-by-lineage.sql
```

Expected Apply Database output:

```text
[PATCH-33] SUCCESS - existing CustPO pada source/batch baru ditolak sebagai POS-204 memakai inbound_id lineage.
```

## UAT case

Existing:

```text
original batch = DEV4-259
cust_po        = DEV4-259
CO             = P260922004
```

Cross-batch replay:

```text
BatchId = DEV4-299
cust_po = DEV4-259
```

Expected:

```text
POS-204
Success=false
ProcessedOrders=0
no new CO
```

Original replay:

```text
BatchId = DEV4-259
cust_po = DEV4-259
```

Expected:

```text
idempotent replay
no duplicate CO
```
