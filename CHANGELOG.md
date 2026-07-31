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
tests/evidence/2026-07-31-smk069-replication-rule-delete-remote-notes-runtime.md
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
- Runtime progression:

```text
1. 50003 — staging SiteRef + source co_num not found
2. 50020 — TEST-ITEM-001 not found in item_mst
3. 50000 — standard DeleteRemoteNotesSp replication rule for target DEFAULT not found
```

- Runtime 3 confirms execution progressed into standard SyteLine trigger/replication processing during the direct `co_mst` insert.
- The current blocker is not staging or item validation. The standard path requires exactly one active Replication Category `Object` rule for `DeleteRemoteNotesSp`, target `DEFAULT`, but the current database did not provide it.
- No global trigger disabling or unverified replication-rule insertion is approved.
- The next step is read-only identification of the exact `DeleteRemoteNotesSp` caller and the current SQL session/application site context.

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
[REACHED] standard co_mst trigger/replication framework
[BLOCKED] DeleteRemoteNotesSp replication rule for target DEFAULT not found
[NEXT] identify exact DeleteRemoteNotesSp caller and session/site context
[PENDING] decide whether backup configuration, intended site, or direct-insert path must be corrected
[PENDING] execute one valid staging order
[PENDING] verify complete co_mst/coitem_mst creation
[PENDING] test idempotent reprocess
[PENDING] connect Process/Reprocess button
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
```

### Planned

- Run read-only SQL against `sys.sql_modules` to identify every object that references `DeleteRemoteNotesSp`.
- Read the current SQL `CONTEXT_INFO()` and compare it with the intended application/site context.
- Determine whether `DEFAULT` is intentional or a fallback caused by incomplete session or backup configuration.
- Do not modify standard triggers or replication rules until the exact caller and expected tenant configuration are known.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
