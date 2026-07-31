# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- Staging-table, IDO, Error Processing form, validation, Customer Order discovery, and controlled runtime-probe documentation.
- Controlled implementation documents:

```text
implementation/16-controlled-createcoandlines-runtime-probe.md
implementation/17-createcoandlines-nonbusiness-marker-probe.md
implementation/18-discover-createcoandlines-call-sites.md
implementation/19-controlled-sp-direct-order-processing.md
implementation/20-controlled-cloud-ui-pseudocode-discovery.md
```

- Direct-insert evidence:

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
```

- Complete controlled Customer Order processing procedure draft:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

### Changed

- Header total remains `SUM(unit_price * qty_ordered)`.
- Cost remains outside staging and is retrieved from `item_mst` during Customer Order processing.
- Standard `SiteRef` is used; no duplicate `site_ref` column.
- Standard Customer Order model remains:

```text
Header : SL.SLCos / dbo.co_mst
Lines  : SL.SLCoitems / dbo.coitem_mst
```

- `CreateCoAndLines` discovery is paused because its exact business JSON schema was not found within the delivery boundary.
- The direct stored-procedure implementation is now active.
- The legacy portal proved that `@co_num OUTPUT` is generated once and reused for every `coitem_mst` line.
- Confirmed number patterns:

```text
normal    : EMYYMM####
sparepart : EMPYYMM###
```

- Confirmed the legacy `co_mst` header mapping and 26-column `coitem_mst` line mapping.
- Added `dbo.SMK069ProcessCustomerOrderSp` with:

```text
- one SiteRef + source co_num per execution
- transaction-owned staging locks
- customer, warehouse, currency, item, quantity, price, and U/M validation
- cost/description retrieval from item_mst
- header totals calculated from staging and item master
- concurrency-safe final co_num generation using sp_getapplock
- set-based co_mst and coitem_mst creation
- no DISABLE TRIGGER
- no NOCHECK CONSTRAINT
- idempotent reprocess using co_mst.cust_po = source/POS co_num
- rollback of header and all lines on failure
- post-rollback staging E/error_msg/retry_count update
- @CreatedCoNum, @Success, and @Infobar outputs
```

- The source/POS `co_num` is not overwritten. It is stored in `co_mst.cust_po`, allowing reprocess lookup without adding a second staging order-number column.
- `implementation/19-controlled-sp-direct-order-processing.md` now documents the complete procedure contract, controls, and DEV test boundary.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] Error Processing base form and Preview
[COMPLETED] customer validation and tests
[CONFIRMED] Customer Order header model
[CONFIRMED] Customer Order line model
[PAUSED] CreateCoAndLines schema/call-site discovery
[ACTIVE] controlled stored-procedure/direct-insert implementation
[CONFIRMED] legacy header and line mappings
[COMPLETED] dbo.SMK069ProcessCustomerOrderSp SQL draft
[NOT EXECUTED] stored procedure deployment and DEV runtime test
[NEXT] create procedure in DEV and run one controlled valid-order test
[PENDING] verify triggers accept the mapping while remaining enabled
[PENDING] test idempotent reprocess
[PENDING] test invalid-item rollback and staging error update
[PENDING] connect Process/Reprocess button to the procedure
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
```

### Planned

- Deploy `dbo.SMK069ProcessCustomerOrderSp` to DEV only.
- Confirm tenant item/currency master columns used by the procedure.
- Run one controlled valid staging order and verify `co_mst` plus all `coitem_mst` rows.
- Run the same source order again to verify idempotency.
- Run an invalid-item case to verify rollback and staging error persistence.
- Connect the verified method to Process/Reprocess.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
