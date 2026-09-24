# Production Baseline Deployment — CSV / POS Inbound → Blanket CO

**Date:** 24 September 2026  
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

## Canonical Receive Core source captured

The working DEV definition of:

```text
dbo.SMK069ReceivePosSalesJsonCoreSp
```

is now stored canonically at:

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonCoreSp.sql
```

The canonical Core includes the 23 Sep Peak Season ordering fix: payload
`is_peak_season` is persisted to inbound before the mapping view is
materialized.

For production, use the consolidated current-state package:

```text
deployment/csv-to-co/prod/
```

Do not replay the numbered DEV/UAT patch history for a fresh PROD baseline.

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

Peak Season / POS U/M configuration additionally depends on Mongoose UET metadata:

```text
Uf_SMK069_is_peak_season
Uf_SMK069_pos_um
SMK069_CL_itemcust
itemcust_mst extension
```

See:

```text
docs/csv-to-co/44-uet-itemcust-peak-season-pos-um.md
```

The external/public IDO method must remain:

```text
Transactional = False
```

because the per-order Customer Order processor owns its own transaction.

## Production rule

### Existing DEV/UAT tenant

Use numbered patches only when upgrading an older installed object to the current state.

### Fresh production baseline

Do **not** replay Patch 01 → Patch 35. Use `deployment/csv-to-co/prod/02-deploy-canonical-runtime.sql` after metadata/schema preflight.

Deploy the final canonical object definitions in dependency order, plus the required table/view/IDO/form baseline.

Historical data-repair behavior contained in a migration patch is not needed on a clean production database unless production is receiving migrated historical integration rows.

## Pre-production gate

Production baseline is ready only when all of the following are true:

```text
[x] canonical Receive Core source captured in repo
[ ] canonical public Receive source current
[ ] canonical Batch processor current
[ ] canonical per-order processor current
[ ] canonical CSV runner current
[ ] required tables/views exist
[ ] required IDO methods/forms are packaged
[ ] UET user fields Uf_SMK069_is_peak_season and Uf_SMK069_pos_um are packaged
[ ] UET class SMK069_CL_itemcust and itemcust_mst extension are packaged
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


## Current PROD package — 24 Sep 2026

Primary migration directory:

```text
deployment/csv-to-co/prod/
```

Use in this order:

```text
00-capture-dev-baseline.sql      (DEV / Query Select)
01-preflight.sql                 (PROD / pre-deploy)
02-deploy-canonical-runtime.sql  (PROD / Apply Database)
03-post-deploy-verify.sql        (PROD / Query Select)
04-mongoose-metadata-checklist.md
05-prod-uat-checklist.md
```

Latest current-state runtime includes:

```text
Patch 26 behavior  : created_co_num persistence
Patch 27 behavior  : Peak Season plumbing
Patch 28 behavior  : ValidationStatus=N atomic rejection
Patch 29 behavior  : Peak-aware quantity validation
Patch 31 behavior  : clear POS-204 message
Patch 33 behavior  : cross-batch duplicate CustPO lineage
Patch 34 behavior  : preserve POS-204 on reused BatchId payload mismatch
Patch 35 behavior  : set Peak flag before mapping-view snapshot
```

Patch 32 remains WITHDRAWN and is not part of production deployment.

### External migration gate

The exact working DEV definition of:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

is owned by Eva/SMK and must be migrated separately. The repository does not
create a competing definition.

### Mongoose migration gate

Export/import the verified DEV UET/IDO/Form metadata before runtime cutover.
In particular:

```text
Uf_SMK069_is_peak_season
Uf_SMK069_pos_um
SMK069_CL_itemcust
itemcust_mst extension
ue_SMK069TempSales
ue_SMK069PosCsvUpload
ue_SMK069APISalesErrorProcessing
ue_SMK069PosCsvBatchConsole
public Receive IDO method (Transactional=False)
```
