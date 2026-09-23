# POS-204 fallback when BatchId is reused with a different payload

**Date:** 23 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Proven UAT response

A request failed with:

```text
[POS-000] Request ditolak...
Success=false
ProcessedOrders=0
SkippedOrders=0
```

This was contradictory.

## Why it happened

`DEV4-299` had already been persisted earlier with a different CustPO.

A later request reused:

```text
BatchId = DEV4-299
payload cust_po = DEV4-259
```

Core treated `DEV4-299` as an idempotent replay of its already-persisted batch.
Patch 33 independently inspected the new payload and correctly detected that
`DEV4-259` already belonged to the original batch `DEV4-259`.

Because the persisted rows of batch `DEV4-299` do not contain
`cust_po=DEV4-259`, there was no matching inbound Error row for the error
composer. It therefore fell back to Core's receive message `POS-000`.

## Patch 34

Patch 34 preserves the business error independently of the current batch's
stored inbound rows.

When Patch 33 detects a duplicate CustPO and there is no matching inbound E row:

```text
ErrorCode = POS-204
ErrorList = generated from the payload CustPO
```

Expected public result:

```text
[POS-204] Request ditolak...
Success=false
```

The message also explains that the BatchId already has different inbound data
or is not the original batch of that CustPO.

## Important test rule

A BatchId is a request identity. Do not reuse an already-used BatchId with a
different payload when testing a new transaction.

For a clean cross-batch duplicate test use:

```text
unused BatchId + existing CustPO
```

For example:

```text
BatchId = DEV4-300
cust_po = DEV4-259
```

Expected:

```text
POS-204
Success=false
no new CO
```

## Deployment

Apply:

```text
database/patches/csv-to-co/
2026-09-23-smk069-34-preserve-pos204-on-reused-batch.sql
```

Expected:

```text
[PATCH-34] SUCCESS - duplicate CustPO pada reused BatchId tetap menghasilkan POS-204, bukan POS-000.
```
