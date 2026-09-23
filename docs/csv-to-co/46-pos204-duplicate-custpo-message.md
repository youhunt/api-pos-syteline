# POS-204 — Duplicate / existing CustPO message

**Date:** 23 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Proven UAT case

Request:

```text
BatchId = DEV4-299
cust_po = DEV4-259
```

The tenant returned:

```text
[POS-204] Data payload tidak terdaftar atau tidak sesuai di Infor ...
```

That wording was misleading.

Database verification proved:

```text
inbound:
DEV4-259 / line 1 / T
DEV4-259 / line 2 / T

co_mst:
P260922004 / cust_po DEV4-259 / type B

temp:
P260922004 / created_co_num P260922004 / cust_po DEV4-259 / process_status P
```

Therefore the request was rejected because the business CustPO already existed/was processed, not because item/U/M/warehouse were unregistered.

## Business identity

```text
cust_po = business idempotency key
batch_id = transport/request batch identity
```

Changing only `batch_id` does not create a new business order when `cust_po` is unchanged.

## Patch 31 message

Patch 31 changes only the public diagnostic text.

New POS-204 message:

```text
CustPO sudah terdaftar pada proses sebelumnya.
BatchId baru tidak membuat CustPO menjadi transaksi baru
[cust_po=<...>, coline=<...>].
Jika transaksi baru gunakan cust_po baru;
jika retry gunakan request/batch original tanpa mengubah data.
```

No business/idempotency rule is changed.

## Deployment

Apply:

```text
database/patches/csv-to-co/
2026-09-23-smk069-31-explicit-pos204-duplicate-custpo-message.sql
```

Expected:

```text
[PATCH-31] SUCCESS - pesan POS-204 sekarang menjelaskan duplicate/existing CustPO dan idempotency.
```
