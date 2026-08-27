# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### 2026-08-27 — POS Contract V2 Receive and Blanket CO UAT

#### Changed

- POS payload no longer supplies `conum` or `unit_price`.
- Added mandatory `cust_po` (CustPOType / nvarchar(25)), mandatory `whse`, and mandatory `u_m` to the POS contract.
- Receive groups atomic orders by `SiteRef + cust_po`.
- Receive generates final Customer Order number using `R + YYMM + 5-digit running number`.
- Receive resolves price from the latest effective `itemcustprice_mst` row; `cont_price` is preferred, with quantity-break fallback when contract price is zero.
- U/M validation now follows the explicit item-specific rule: base item U/M or `u_m_conv_mst.item = item` with matching `from_u_m`/`to_u_m`.
- Warehouse is mandatory and validated against `whse_mst`.
- Process V2 reuses the Receive-generated `co_num`; it does not generate a second order number.
- `co_mst.cust_po` now stores the POS `cust_po` business value.
- Error Processing standard Create/New/Copy/Delete operations are disabled/required-disabled to protect staging integrity.

#### Confirmed UAT

```text
BatchId          BATCH-20260827-002
cust_po          POS08270002
generated co_num R260822003
lines            2
unit_price       80000
u_m              CTN
whse             MAIN
Receive           1 valid / 0 error / 2 transferred
Process           Blanket Customer Order success / Processed
```

#### Documentation

- Added `docs/22-smk069-pos-contract-v2-20260827.md`.
- Added `tests/evidence/2026-08-27-smk069-pos-contract-v2-receive-process-success.md`.
- Updated temp staging and Error Processing form documentation to V2 semantics.
- Marked the intermediate `docs/21-smk069-list-co-and-cust-po-revision.md` as superseded.

### 2026-08-07 — CSV-to-Blanket-Customer-Order End-to-End Synchronization

#### Added

- Complete end-to-end technical documentation:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

- UAT incident/correction evidence:

```text
tests/evidence/2026-08-06-smk069-um-validation-and-blanket-order-corrections.md
```

- Final CSV receive/validation wrapper source:

```text
database/procedures/SMK069RunCsvTestBatchSp.sql
```

#### Changed

- Final tenant `SMK069ProcessCustomerOrderSp` creates a Blanket Customer Order:

```text
co_mst.type = B
```

- Every valid staging line is inserted into both:

```text
coitem_mst
co_bln_mst
```

- `co_bln_mst.co_num` uses the generated SyteLine order number, not the source/POS order number.
- `co_bln_mst.allow_on_pick_list` is explicitly set to `0` because the tenant column is `NOT NULL`.
- Existing-order idempotency validates both `coitem_mst` and `co_bln_mst` line counts/details.
- Temporary staging records store the generated order number in `created_co_num`.
- Caller-safe transaction handling uses `@@TRANCOUNT`, savepoints, and original-error rethrow when an outer Mongoose transaction is uncommittable.
- Final tenant `SMK069ReceivePosSalesJsonSp` validates U/M against `item_mst.u_m` or an applicable Global/Item/Customer conversion in `u_m_conv_mst`; vendor conversion is excluded.
- One invalid U/M line marks the entire source order invalid and prevents transfer to temp.
- `SMK069RunCsvTestBatchSp` is receive/validate only and no longer creates Customer Orders.
- CSV Console documentation now reflects hidden File Name, upload-to-parse behavior, and separation between Import & Validate and Process/Reprocess.
- Error Processing documentation now reflects `created_co_num`, Blanket CO output, `coitem_mst`, and `co_bln_mst`.

#### Fixed

- Prevented invalid U/M data from being shown as valid and failing only during Customer Order processing.
- Fixed Mongoose transaction-count mismatch caused by rolling back the caller-owned transaction.
- Fixed `co_bln_mst` insert failure caused by a `NULL allow_on_pick_list` value.
- Final tenant parser checks downstream key widths:

```text
custnum <= 7
conum   <= 10
item    <= 30
```

#### Current Flow

```text
CSV upload
→ parse rows
→ Import & Validate
→ inbound raw/mapping/U-M validation
→ temp status V
→ Process/Reprocess per source order
→ co_mst type B
→ coitem_mst
→ co_bln_mst
→ temp status P + created_co_num
```

### Earlier SMK069 Customer Order Work

#### Added

- Controlled Customer Order procedure:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

- Cloud runtime evidence:

```text
tests/evidence/2026-08-03-smk069-cloud-e2e-customer-order-success.md
tests/evidence/2026-08-03-smk069-cloud-idempotent-reprocess-success.md
```

- Supporting tax, site-context, and standard-trigger evidence under `tests/evidence` and `database/patches`.

#### Historical Cloud End-to-End Result — 2026-08-03

The earlier regular Customer Order path was confirmed before the Blanket Order requirement was introduced:

```text
REST additem
→ TEST000002 inserted with status N
→ ue_SMK069ValidateCustomerSp returned 0
→ staging changed to V
→ SMK069ProcessCustomerOrderSp returned Success = 1
→ generated Customer Order CO26080001
→ staging changed to P
→ SLCos header verified
→ SLCoitems line verified
```

Confirmed header at that historical checkpoint:

```text
CoNum      : CO26080001
CustNum    : C000001
CustPo     : TEST000002
Whse       : MAIN
TermsCode  : CBD
TaxCode1   : PPN11%
Stat       : P
Price      : 11100.00000000
```

Confirmed line:

```text
CoNum       : CO26080001
CoLine      : 1
Item        : AA00001
QtyOrdered  : 1.00000000
UM          : KG
Price       : 10000.00000000
Whse        : MAIN
```

This evidence remains useful historically, but the current target is a Blanket Customer Order with additional `co_bln_mst` rows.

#### Historical Idempotency Result — 2026-08-03

```text
SiteRef     : DEFAULT
SourceCoNum : TEST000002
```

Confirmed response:

```text
ReturnValue  : 0
CreatedCoNum : CO26080001
Success      : 1
Infobar      : Customer Order CO26080001 sudah pernah dibuat; staging disinkronkan menjadi Processed.
```

The current Blanket implementation extends this check to `co_bln_mst` and requires `type = B`.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] created_co_num design and processing logic
[COMPLETED] ue_SMK069TempSales IDO base
[COMPLETED] Error Processing form and Preview
[COMPLETED] CSV binary upload and parser
[COMMITTED] CSV Import & Validate only wrapper
[IMPLEMENTED IN TENANT] controlled Receive API procedure
[COMPLETED] raw inbound preservation and field mapping
[COMPLETED] customer/item/warehouse/basic validation
[IMPLEMENTED IN TENANT] U/M base/conversion validation
[COMPLETED] atomic-order validation
[IMPLEMENTED IN TENANT] Blanket CO header type B
[IMPLEMENTED IN TENANT] coitem_mst line creation
[IMPLEMENTED IN TENANT] co_bln_mst line creation
[IMPLEMENTED IN TENANT] caller-safe transaction handling
[IMPLEMENTED IN TENANT] idempotent existing Blanket CO synchronization
[PENDING REPOSITORY SYNC] exact final parser, Receive, and Process SQL source
[PENDING EVIDENCE] CreatedCoNum property/grid verification in tenant
[PENDING EVIDENCE] 100-row/25-order formal UAT record
[PENDING REVIEW] conversion-factor handling for converted quantity and price
[PENDING] final external POS REST URL/security contract
[PENDING] functional confirmation of release/shipment/invoice lifecycle
```

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
