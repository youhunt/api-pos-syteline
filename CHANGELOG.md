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
tests/evidence/2026-07-31-smk069-sp-compile-success-and-missing-staging-test.md
tests/evidence/2026-07-31-smk069-invalid-item-runtime.md
```

- Controlled Customer Order processing procedure:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

### Changed

- Header total remains `SUM(unit_price * qty_ordered)`.
- Cost remains outside staging and is retrieved from `item_mst` during Customer Order processing.
- Standard `SiteRef` is used; no duplicate `site_ref` column.
- Customer Order model remains:

```text
Header : SL.SLCos / dbo.co_mst
Lines  : SL.SLCoitems / dbo.coitem_mst
```

- `CreateCoAndLines` discovery remains paused; controlled direct stored-procedure processing is active.
- The active procedure contract excludes `@Sparepart`, pickup-date, start-time, and end-time parameters.
- The active generated Customer Order pattern is `COYYMM####`.
- Portal-only unavailable `Uf_*` columns remain excluded.
- Alias types remain valid for procedure parameters and variables, while system types such as `NVARCHAR` are used as `CAST`/`CONVERT` targets.
- `dbo.SMK069ProcessCustomerOrderSp` compiled successfully in the tenant.
- First runtime validation returned error `50003` because the supplied `SiteRef + source co_num` group was not found. No Customer Order rows were created.
- A subsequent execution used an existing staging group and returned:

```text
Success      : 0
CreatedCoNum : NULL
Error        : 50020 — Item tidak ditemukan pada item_mst: TEST-ITEM-001
```

- The invalid-item result confirms execution reached item-master validation and stopped before `co_mst` or `coitem_mst` insertion.
- The item validation remains required; the next test must replace the dummy item with an exact `item_mst` item from the same staging `SiteRef`.

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
[COMPILED] dbo.SMK069ProcessCustomerOrderSp in tenant
[COMPLETED] staging-group-not-found controlled test
[COMPLETED] invalid-item controlled test
[SAFE FAILURE] TEST-ITEM-001 rejected before Customer Order insertion
[NEXT] select an exact item_mst item for the same SiteRef and update the dummy staging item
[PENDING] execute one valid staging order
[PENDING] verify trigger-compatible header and line creation
[PENDING] test idempotent reprocess
[PENDING] connect Process/Reprocess button
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
```

### Planned

- Query actual `item_mst` candidates for the exact staging site.
- Replace only `TEST-ITEM-001` in the disposable staging order with one exact returned item.
- Execute the same source order and verify one `co_mst` header plus all expected `coitem_mst` lines.
- Re-run the same source order to verify idempotency.
- Connect the verified procedure to Process/Reprocess.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
