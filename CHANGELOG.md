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

- Added direct-insert evidence:

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
tests/evidence/2026-07-31-legacy-portal-header-line-direct-insert-flow.md
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
- The user supplied the complete legacy portal header and line creation flow.
- Confirmed the header procedure `dbo.TDI_PortalEMotor_InsertCO` generates `@co_num` and returns it through an input/output parameter.
- Confirmed the portal already reads the generated value with `cmd.Parameters["@co_num"].Value` and uses the same value for every `dbo.coitem_mst` line.
- Confirmed tenant-specific header numbering patterns:

```text
normal    : EMYYMM####
sparepart : EMPYYMM###
```

- Confirmed the legacy `co_mst` header field mapping and the full 26-column `coitem_mst` line insert mapping.
- The generated order number does not require an identity lookup or second query; it should be generated once and reused for header and all lines in one transaction.
- The legacy application-side two-stage save must be consolidated so that header, every line, and staging success updates commit or roll back together.
- The existing global trigger disable/enable and foreign-key `NOCHECK/CHECK` statements will not be retained.
- The string-concatenated line inserts will be replaced with parameterized or set-based SQL.
- Order-number generation must be concurrency-safe; unlocked `MAX(co_num) + 1` is not acceptable for the new processor.
- For reprocessing traceability, the generated SyteLine `co_num` should be stored separately from an external/POS order number when those are different.

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
[CONFIRMED] legacy dbo.TDI_PortalEMotor_InsertCO header mapping
[CONFIRMED] legacy dbo.coitem_mst line insert mapping
[CONFIRMED] generated @co_num output handoff to detail lines
[REQUIRED] consolidate header, lines, and staging updates into one transaction
[REQUIRED] keep triggers and constraints enabled
[NEXT] draft dbo.SMK069ProcessCustomerOrderSp from staging
[PENDING] confirm distinct staging field for generated SyteLine co_num
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] DEV header-and-lines creation test
```

### Planned

- Draft `dbo.SMK069ProcessCustomerOrderSp` using the confirmed header and line mappings.
- Read one source order from staging, generate one final `@co_num`, and reuse it for `co_mst` plus every `coitem_mst` row.
- Return the generated `co_num` and a controlled error/message output.
- Keep triggers and constraints enabled.
- Add transaction control, idempotency, reprocess protection, and concurrency-safe numbering before DEV execution.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
