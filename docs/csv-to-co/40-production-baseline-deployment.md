# Production Baseline Deployment — CSV / POS Inbound → Blanket CO

**Date:** 16 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order only

## Decision

The numbered files under `database/patches/csv-to-co/` are the **incremental DEV/UAT migration history**. They are useful to upgrade an already-running tenant from an older state, but they are **not the desired production deployment method for a fresh environment**.

For production, deploy the **latest canonical/current-state objects**. Do not replay Patch 01 → Patch 25 one by one when the production environment is being installed from a clean baseline.

## Canonical procedures already rebased to the final design

### `SMK069ProcessCustomerOrderSp.sql`

Path:

```text
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
```

This canonical source already contains the final behavior introduced across the later patches:

```text
cust_po = canonical downstream business key
idempotency = customer + cust_po
new CO number = PYYMMDD###
co_mst.type = B
co_mst.consolidate = 1
coitem_mst.stat = O
coitem_mst.consolidate = 1
coitem_mst.release_date = order_date
co_bln_mst rows created for every line
co_bln_mst.stat = O
co_bln_mst.allow_on_pick_list = 0
temp.co_num = actual SyteLine CO after success
legacy R... accepted only as compatibility input when needed
```

This folds the active runtime behavior of Patch 14, 17, 21, 22, 24, and 25 into the canonical per-order source.

### `SMK069ProcessBatchCustomerOrdersSp.sql`

Path:

```text
database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql
```

Canonical source contains:

```text
POS-302 no-silent-success protection
batch discovery by cust_po
pending detection by cust_po
batch cursor by cust_po
Batch -> per-order call using cust_po
CreatedCoNums aggregation
```

This folds the final active behavior of Patch 19, 20, 24, and 25 into the canonical batch processor.

### `SMK069ReceivePosSalesJsonSp.sql`

Path:

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
```

Canonical public entry point already routes valid data through receive/validation → quantity-multiple validation → batch CO processing and contains the POS-108 / POS-203 rule introduced by the active receive patches.

### `SMK069RunCsvTestBatchSp.sql`

Path:

```text
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
```

Canonical CSV runner already routes CSV-built JSON through `SMK069ReceivePosSalesJsonSp` instead of maintaining a separate CO-processing path.

## Important production prerequisite gap

`dbo.SMK069ReceivePosSalesJsonSp` depends on:

```text
dbo.SMK069ReceivePosSalesJsonCoreSp
```

As of this audit, the repository contains references to this Core procedure but **does not contain a canonical source file for `SMK069ReceivePosSalesJsonCoreSp` under the current canonical procedure directories**.

Therefore the production package must **not** yet be described as "copy the four canonical SP files and production is complete".

Before production deployment:

1. export the exact working DEV definition of `dbo.SMK069ReceivePosSalesJsonCoreSp`;
2. audit it against the current DEV/UAT behavior;
3. commit it as a canonical source file in the repository;
4. include it in the production baseline deployment order.

Suggested tenant query to capture the exact definition:

```sql
SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')) AS ProcedureDefinition;
```

Do not reconstruct or guess this Core procedure from old patch history when a working DEV definition is available.

## Supporting objects are separate from SP patch history

A fresh production environment must also already have or deploy the required supporting objects, including the applicable custom tables/views, CSV import objects, IDO method metadata, and forms used by this workstream.

At minimum the runtime flow expects objects such as:

```text
ue_SMK069_pos_sales_inbound_mst
ue_SMK069_pos_sales_inbound_mapping_view
ue_SMK069_temp_sales_mst
SMK069ReceivePosSalesJsonCoreSp
SMK069ReceivePosSalesJsonSp
SMK069ProcessBatchCustomerOrdersSp
SMK069ProcessCustomerOrderSp
```

CSV operation additionally depends on its CSV batch/upload/import objects and `SMK069RunCsvTestBatchSp`.

The external/public IDO method must remain:

```text
Transactional = False
```

because the per-order Customer Order processor owns its own transaction.

## Production rule

### Existing DEV/UAT tenant

Use numbered patches only when upgrading an older installed object to the current state.

### Fresh production baseline

Do **not** replay Patch 01 → 25.

Deploy the final canonical object definitions in dependency order, plus the required table/view/IDO/form baseline.

Historical data-repair behavior contained in a migration patch is not needed on a clean production database unless production is receiving migrated historical integration rows.

## Pre-production gate

Production baseline is ready only when all of the following are true:

```text
[ ] canonical Receive Core source captured in repo
[ ] canonical public Receive source current
[ ] canonical Batch processor current
[ ] canonical per-order processor current
[ ] canonical CSV runner current
[ ] required tables/views exist
[ ] required IDO methods/forms are packaged
[ ] public method Transactional = False
[ ] clean UAT proves PYYMMDD### numbering
[ ] clean UAT proves temp.co_num = actual CO
[ ] clean UAT proves cust_po linkage
[ ] clean UAT proves type B + consolidate
[ ] clean UAT proves co_bln_mst
[ ] clean UAT proves release_date = order_date without manual edit
[ ] replay/idempotency test passes
[ ] POS-108 quantity rejection test passes
```
