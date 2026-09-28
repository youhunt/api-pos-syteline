# SMK069 PROD Migration Package

**Date:** 24 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order only

This directory is the production migration entry point.

## Main decision

For a fresh/current-state PROD environment:

> **Do not replay Patch 01 → Patch 35 one by one.**

The numbered patches are DEV/UAT migration history. PROD uses the latest canonical object definitions plus the required Mongoose/UET/table/view metadata.

Patch 32 is explicitly **WITHDRAWN / DO NOT APPLY**.

## Package contents

```text
00-capture-dev-baseline.sql
01-preflight.sql
02-deploy-canonical-runtime.sql
03-post-deploy-verify.sql
04-mongoose-metadata-checklist.md
05-prod-uat-checklist.md
```

## Canonical SQL deployed by 02-deploy-canonical-runtime.sql

The consolidated one-batch deployment installs the current repository versions of:

```text
dbo.SMK069CsvSplitLine
dbo.SMK069ImportCsvFileSp
dbo.SMK069ValidateCustomerSp
dbo.SMK069ProcessCustomerOrderSp
dbo.SMK069ProcessBatchCustomerOrdersSp
dbo.SMK069ReceivePosSalesJsonCoreSp
dbo.SMK069ReceivePosSalesJsonSp
dbo.SMK069RunCsvTestBatchSp
```

The deployment is generated from these canonical repository sources:

```text
database/stored-procedures/csv-to-co/SMK069ImportCsvFileSp.sql
database/stored-procedures/csv-to-co/SMK069ValidateCustomerSp.sql
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonCoreSp.sql
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
```

## Final runtime contract

```text
POS JSON / CSV
→ dbo.SMK069ReceivePosSalesJsonSp
→ dbo.SMK069ReceivePosSalesJsonCoreSp
→ raw inbound + is_peak_season
→ dbo.ue_SMK069_pos_sales_inbound_mapping_view
→ ValidationStatus / Peak-aware mapping
→ dbo.ue_SMK069_temp_sales_mst
→ dbo.SMK069ProcessBatchCustomerOrdersSp
→ dbo.SMK069ProcessCustomerOrderSp
→ co_mst + coitem_mst + co_bln_mst
```

Target result:

```text
CO number                 = PYYMMDD###
co_mst.type               = B
co_mst.cust_po            = business CustPO
co_mst.consolidate        = 1
coitem_mst.stat           = O
coitem_mst.consolidate    = 1
coitem_mst.release_date   = co_mst.order_date
co_bln_mst.stat           = O
co_bln_mst.allow_on_pick_list = 0
temp.created_co_num       = actual SyteLine CO
temp.process_status       = P
```

## Peak Season final behavior

Payload:

```json
"is_peak_season": 1
```

is persisted into inbound **before the mapping view is materialized**.

This is important. Patch 35 fixed the DEV defect where Core evaluated the mapping view while inbound still held default `is_peak_season = 0`.

Final sequence:

```text
raw_json
→ inbound.is_peak_season
→ mapping view
→ #MapView
→ temp
→ CO
```

## Mapping view

The exact working DEV definition supplied for:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

is now captured canonically at:

```text
database/views/csv-to-co/ue_SMK069_pos_sales_inbound_mapping_view.sql
```

and is deployed by:

```text
02-deploy-canonical-runtime.sql
```

It exposes at minimum:

```text
inbound_id
source_system
batch_id
row_no
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
is_peak_season
ValidationStatus
```

DEV evidence hash remains recorded for audit. Because the repository deploys a normalized `CREATE OR ALTER VIEW` canonical source, functional/source verification is performed by `03-post-deploy-verify.sql`; the historical DEV SHA-256 is retained as a reference, not a byte-for-byte gate for the normalized deployment text.

### Mongoose metadata

SQL deployment does not replace Mongoose metadata migration.

Migrate/export from the verified TRN configuration:

```text
UET/User Fields
IDO/table metadata
IDO methods + parameter order
forms/events/components
generated table triggers / Impact Schema result
```

See `04-mongoose-metadata-checklist.md`.

## Deployment order

### A. Before maintenance window

1. Freeze relevant DEV changes.
2. Run `00-capture-dev-baseline.sql` in DEV and save the outputs.
3. Export the Mongoose/UET/IDO/Form metadata listed in the metadata checklist.
4. Keep the DEV mapping-view baseline/hash as rollback/audit evidence; the canonical view is now included in the SQL package.
5. Take a PROD backup / metadata export appropriate for the tenant.

### B. PROD physical tables first

1. Ensure standard SyteLine UDTs exist.
2. Run `00c-create-core-physical-tables.sql` in Apply Database.
3. Import the verified UET metadata for `SMK069_CL_itemcust`.
4. Run **UET Impact Schema**.
5. Optionally verify the two physical itemcust fields with
   `00f-verify-itemcust-uet-physical.sql`.
6. Import remaining IDO/Form metadata.
7. Refresh metadata/cache.
8. Run `01-preflight.sql` in **Apply Database**. It is read-only, but it is a
   multi-statement validation batch and therefore is not suitable for the tenant
   Query Select screen.
9. The final mapping view is created/altered by
   `02-deploy-canonical-runtime.sql`.

`00e-ensure-itemcust-peak-posum-physical.sql` is **fallback only** and is not
part of the normal PROD cutover when UET Impact Schema is available.

Do not continue when preflight fails.

### C. PROD runtime SQL

Run only:

```text
02-deploy-canonical-runtime.sql
```

in Apply Database.

It is one executable batch and contains **no GO**.

Do not separately apply numbered DEV patches 14–35 after this consolidated runtime deployment.

### D. Verification

1. Run `03-post-deploy-verify.sql` in Query Select. The file is intentionally
   exactly **one SELECT statement** and returns one consolidated verification grid.
2. Verify IDO methods/forms manually.
3. Execute `05-prod-uat-checklist.md`.

## Critical IDO contract

The external/public method that invokes:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

must remain:

```text
Transactional = False
```

The per-order processor owns its transaction boundaries.

Public Receive parameter order must remain:

```text
 1 SourceSystem
 2 BatchId
 3 PayloadJson
 4 ReceivedBy
 5 ReceivedRows OUT
 6 TotalOrders OUT
 7 ValidOrders OUT
 8 ErrorOrders OUT
 9 TransferredRows OUT
10 Infobar OUT
11 ProcessedOrders OUT
12 ProcessErrors OUT
13 CreatedCoNums OUT
14 ThrowOnBusinessError
```

## Idempotency contract

```text
cust_po  = business idempotency key
batch_id = request/transport identity
```

Rules:

```text
same original BatchId + same payload
→ idempotent replay
→ no duplicate CO

new/different BatchId + existing CustPO
→ POS-204
→ Success=false
→ no new CO

new transaction
→ new BatchId + new CustPO
```

## Error contracts that must survive migration

```text
POS-108 = quantity not according to allowed U/M multiple
POS-109 = mapping-view ValidationStatus=N; reject whole CustPO
POS-203 = sibling line rejected because same CustPO has a real invalid line
POS-204 = existing/conflicting CustPO
POS-302 = no canonical business order mapping for batch; no silent success
```

## Rollback

The consolidated runtime deployment does not mass-update historical PROD integration rows.

Rollback strategy:

1. Reapply the pre-deployment PROD object definitions captured before cutover.
2. Restore the exported Mongoose metadata if metadata rollback is required.
3. Do not delete or rewrite Customer Orders created during UAT without business approval.
4. Do not attempt to roll back by replaying old numbered patches in reverse.

## Cutover gate

Production is ready only when all items below pass:

```text
[ ] DEV baseline captured
[ ] Exact SMK mapping view migrated
[ ] UET Peak Season / POS U/M migrated
[ ] custom tables + generated triggers aligned
[ ] IDOs and methods migrated
[ ] forms/events migrated
[ ] public Receive method Transactional=False
[ ] 01-preflight.sql PASS
[ ] 02 canonical deployment SUCCESS
[ ] 03 post-deploy verification PASS
[ ] normal order UAT PASS
[ ] peak order UAT PASS
[ ] non-peak order UAT PASS
[ ] POS-108 negative UAT PASS
[ ] POS-109 atomic rejection UAT PASS
[ ] POS-204 duplicate UAT PASS
[ ] original BatchId replay UAT PASS
[ ] CSV one-hit UAT PASS
[ ] Error Processing display UAT PASS
```


## Core physical tables — captured from DEV

The five core/config tables are now scripted directly from the DEV
column/key/index metadata captured on 28 Sep 2026:

```text
dbo.ue_SMK069_pos_sales_inbound_mst
dbo.ue_SMK069_temp_sales_mst
dbo.ue_SMK069_pos_csv_batch_mst
dbo.ue_SMK069_pos_csv_upload_mst
dbo.ue_SMK069_pos_field_map_mst
```

Apply:

```text
deployment/csv-to-co/prod/00c-create-core-physical-tables.sql
```

This script is one executable batch with no `GO`, includes captured
identity/PK/unique/index/FK definitions, and is safe to rerun because existing
tables are left unchanged.


## DEV UET verification — 28 Sep 2026

Verified in DEV:

```text
User Field: Uf_SMK069_is_peak_season
  User Data Type = int
  Decimals       = 0
  Initial Value  = blank in UET metadata

User Field: Uf_SMK069_pos_um
  User Data Type = UMType
  Physical Type  = nvarchar(3)
  Initial Value  = blank in UET metadata

Class: SMK069_CL_itemcust
  Uf_SMK069_is_peak_season
  Uf_SMK069_pos_um

Table/Class:
  itemcust_mst -> SMK069_CL_itemcust
  Active = 1
  Extend All Records = 1
```

UET Impact Schema completed successfully in DEV.

Shipment UET fields/classes shown in the same DEV UET export are outside this
CSV/POS inbound migration scope and are not part of this package.


## Field-map seed — verified DEV

The TRN rows for:

```text
dbo.ue_SMK069_pos_field_map_mst
```

have been captured and embedded directly into:

```text
00c-create-core-physical-tables.sql
```

The package now seeds 36 active `POS` mappings, including canonical names and
accepted aliases for customer, order, line, item, quantity, warehouse, U/M,
terms, tax, price, exchange rate, due date and SiteRef.

The seed is idempotent: existing rows are updated by the table primary key
`source_system + source_field`; missing rows are inserted.

The captured TRN rows used:

```text
SiteRef = Default
source_system = POS
```

The PROD seed does **not** copy the TRN SiteRef or TRN RowPointer values.
`00c-create-core-physical-tables.sql` resolves the target active site from
`CONTEXT_INFO()` and generates fresh RowPointers, while preserving the verified
36 business mappings. Receive Core continues to filter by
`m.SiteRef = @Site`.
