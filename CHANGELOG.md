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
- The active procedure contract was simplified by removing:

```text
@Sparepart
@PickupDate
@StartTime
@EndTime
```

- The active generated Customer Order pattern is now:

```text
COYYMM####
```

- Portal-only unavailable `Uf_*` columns remain excluded.
- Alias types remain valid for procedure parameters and variables, but system types such as `NVARCHAR` are used as `CAST`/`CONVERT` targets.
- `dbo.SMK069ProcessCustomerOrderSp` compiled successfully in the tenant.
- The first controlled execution returned:

```text
Success      : 0
CreatedCoNum : NULL
Error        : 50003 — staging SiteRef + source co_num not found
```

- Verification showed no `co_mst` or `coitem_mst` rows were created.
- This is classified as a controlled validation failure, not a compile or partial-write failure.
- The next execution must use an exact existing staging `SiteRef + co_num` pair.

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
[COMPLETED] first controlled execution
[SAFE FAILURE] no matching staging group; no Customer Order rows created
[NEXT] list exact staging SiteRef + co_num groups
[PENDING] execute one valid staging order
[PENDING] verify trigger-compatible header and line creation
[PENDING] test idempotent reprocess
[PENDING] test invalid-item rollback and staging error update
[PENDING] connect Process/Reprocess button
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
```

### Planned

- Query available staging groups.
- Execute the procedure with one exact existing `SiteRef + source co_num` pair.
- Verify one `co_mst` header and all expected `coitem_mst` lines.
- Re-run the same source order to verify idempotency.
- Run an invalid-item case to verify rollback and error persistence.
- Connect the verified procedure to Process/Reprocess.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
