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

- Added direct-insert decision evidence:

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
```

### Changed

- Header total remains `SUM(unit_price * qty_ordered)`.
- Cost remains outside staging and is retrieved from master data during Customer Order processing.
- Standard `SiteRef` is used; no duplicate `site_ref` column.
- Customer validation is complete for valid and invalid branches.
- Standard Customer Order model confirmed:

```text
Header : SL.SLCos / dbo.co_mst
Lines  : SL.SLCoitems / dbo.coitem_mst
```

- `CreateCoAndLines` discovery confirmed Base64/JObject transport but did not identify the exact business JSON schema.
- Controlled malformed/non-business probes created no Customer Order rows.
- Direct event/action searches returned no call-site rows; one `ExpandedParameters` filter was rejected with `IllegalFilterException`.
- `CustomerOrdersQuickEntry` confirmed:

```text
Primary collection : SLCos / oSLCos
Line subcollection : SLCoitems / oLines
```

- Form-level `CreateCoAndLines` search displayed no matching handler.
- `StdFormSave` exposed custom `SMK_Save()` logic.
- The user-provided complete `SMK_Save()` source proved that it only changes `Stat` to `S` for a request date more than 30 days in the past. It does not build JSON, encode Base64, invoke `CreateCoAndLines`, or create Customer Order data.
- On 31 July 2026, the user explicitly paused the `CreateCoAndLines` discovery path and activated the controlled stored-procedure/direct-insert path to meet the delivery schedule.
- `implementation/19-controlled-sp-direct-order-processing.md` is now the active implementation document.
- The existing `dbo.InsertCO` header logic may be reused only after removing global trigger/constraint changes and placing header, lines, and staging updates in one transaction.
- Triggers and constraints must remain enabled.
- The next required input is the tenant-specific `dbo.coitem_mst` line insertion implementation.

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
[AVAILABLE] existing dbo.InsertCO header procedure
[REQUIRED] refactor dbo.InsertCO without DISABLE TRIGGER or NOCHECK
[NEXT] obtain previous coitem_mst line insert procedure/code
[PENDING] build dbo.SMK069ProcessCustomerOrderSp
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] DEV header-and-lines creation test
```

### Planned

- Obtain the previous `InsertCOItem`/`InsertCoLine` procedure or direct `INSERT INTO coitem_mst` mapping.
- Build one controlled processing procedure for header, all lines, and staging status in a single transaction.
- Keep triggers and constraints enabled.
- Add idempotency and reprocess protection before DEV execution.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
