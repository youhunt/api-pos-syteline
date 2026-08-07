# Evidence — SMK069 U/M Validation and Blanket Order Corrections

## Date

6–7 August 2026

## Context

During UAT on `SMK API SALES ERROR PROCESSING`, a row was shown as `Valid`, but `Process/Reprocess` failed with:

```text
Uncommittable transaction is detected at the end of the batch.
The transaction is rolled back.
```

The business user confirmed that the test data was intentionally incorrect at U/M level. The U/M did not match the item base U/M and did not have a valid conversion.

## Root Cause

The previous Receive validation only checked whether `u_m` was blank. It did not check whether:

```text
inbound U/M = item_mst.u_m
```

or whether an applicable conversion existed in:

```text
dbo.u_m_conv_mst
```

The invalid row therefore reached temporary staging as `V` and failed later inside Customer Order processing/standard table logic.

## Corrected Validation Rule

```text
1. Blank U/M defaults from item_mst.u_m.
2. U/M equal to item_mst.u_m is valid.
3. Different U/M requires Global, Item, or Customer conversion.
4. Vendor conversion is excluded.
5. One invalid line makes the entire SiteRef + source co_num invalid.
```

Example expected message:

```text
u_m GR tidak valid untuk item AA00005;
base u_m item adalah KG dan U/M Conversion tidak ditemukan
```

Expected result:

```text
inbound_status = E
TransferredRows = 0 for the invalid order
no Customer Order process call for that order
```

## Blanket Order Requirement Change

The Customer Order header must be created as:

```text
co_mst.type = B
```

Each staging line must be inserted into both:

```text
dbo.coitem_mst
dbo.co_bln_mst
```

The source/POS order remains in:

```text
staging.co_num
co_mst.cust_po
```

The generated SyteLine order number is used by:

```text
co_mst.co_num
coitem_mst.co_num
co_bln_mst.co_num
staging.created_co_num
```

## `co_bln_mst` NOT NULL Correction

The first blanket-line attempt failed with:

```text
Cannot insert the value NULL into column 'allow_on_pick_list',
table 'dbo.co_bln_mst'; column does not allow nulls.
```

Correction:

```text
co_bln_mst.allow_on_pick_list = 0
```

## Mongoose Transaction Correction

A previous error also showed:

```text
Transaction count after EXECUTE indicates a mismatching number of
BEGIN and COMMIT statements. Previous count = 1, current count = 0.
```

Root cause:

```text
Mongoose owned an outer transaction, but the procedure performed a full rollback.
```

Corrected pattern:

```text
- capture @@TRANCOUNT;
- start a transaction only when none exists;
- otherwise create a savepoint;
- commit only a procedure-owned transaction;
- rollback to savepoint for a committable caller transaction;
- rethrow when the caller transaction is uncommittable.
```

## Final Processing Result Definition

For one valid source order with N staging lines:

```text
1 co_mst row, type B
N coitem_mst rows
N co_bln_mst rows
N temp rows updated to process_status P
all temp rows receive the same created_co_num
```

## Related Source Files

```text
database/procedures/SMK069ReceivePosSalesJsonSp.sql
database/procedures/SMK069ProcessCustomerOrderSp.sql
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```
