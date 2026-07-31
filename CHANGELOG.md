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
tests/evidence/2026-07-31-smk069-sp-first-compile-errors-and-fix.md
```

- Controlled Customer Order processing procedure:

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
- The direct stored-procedure implementation is active.
- The legacy portal proved that `@co_num OUTPUT` is generated once and reused for every `coitem_mst` line.
- Number patterns remain:

```text
normal    : EMYYMM####
sparepart : EMPYYMM###
```

- Added `dbo.SMK069ProcessCustomerOrderSp` with transaction control, validation, item-master cost retrieval, concurrency-safe numbering, set-based line insertion, idempotent reprocess, rollback, and staging status/error maintenance.
- The source/POS `co_num` is retained in staging and stored in `co_mst.cust_po` for reprocess lookup.
- The first tenant compile attempt failed before execution and confirmed these corrections:

```text
1. Alias types such as CoNumType, InfobarType, and UsernameType must not be used as CAST/CONVERT target system types.
2. Portal-only Uf_* columns are not present in the current tenant.
```

- Replaced alias-type conversion expressions with direct assignment or system-type conversion.
- Removed unavailable header columns:

```text
Uf_date_pengambilan
Uf_StartTime
Uf_EndTime
```

- Removed unavailable line columns:

```text
Uf_Item_price
Uf_net_price
Uf_price_aft_disc1
Uf_price_aft_disc2
Uf_price_aft_disc3
```

- Removed the unused pickup-date/start-time/end-time procedure parameters.
- Updated the example execution block to use system types for local output variables.

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
[FAILED] first stored-procedure compile attempt
[COMPLETED] corrective SQL revision for alias conversions and missing Uf_* columns
[NOT EXECUTED] Customer Order processing procedure
[NEXT] compile the corrected procedure in DEV
[PENDING] run one controlled valid-order test
[PENDING] verify triggers accept the mapping while remaining enabled
[PENDING] test idempotent reprocess
[PENDING] test invalid-item rollback and staging error update
[PENDING] connect Process/Reprocess button to the procedure
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
```

### Planned

- Compile the corrected `dbo.SMK069ProcessCustomerOrderSp` in DEV without executing it.
- Resolve only exact tenant compile errors if any remain.
- After successful compile, run one controlled valid staging order and verify `co_mst` plus all `coitem_mst` rows.
- Run the same source order again to verify idempotency.
- Run an invalid-item case to verify rollback and staging error persistence.
- Connect the verified method to Process/Reprocess.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
