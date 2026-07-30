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
```

- Runtime and metadata evidence for the `CreateCoAndLines` discovery path, including four controlled probes, four no-order checks, and zero-row call-site searches across current event-handler/action fields.

### Changed

- Header total confirmed as `SUM(unit_price * qty_ordered)`.
- Cost remains outside staging and is obtained from `item_mst` during Customer Order processing.
- Standard `SiteRef` is used; no duplicate `site_ref` column.
- Customer validation is complete for valid and invalid branches.
- Confirmed standard Customer Order IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Confirmed `CreateCoAndLines` metadata and runtime observations:

```text
Method Type          : Extension Class - Standard Method
Transactional        : false
Implementation owner : Customer.SLCos
Assembly             : Customer — Binary Only
CoAndLineInfoJson    : input-only, Base64-encoded JSON object/JObject
CoResult             : input/output + message parameter, JSON-array string
```

- Completed four controlled probes and four read-only `dbo.co_mst` checks; every check returned zero rows with no SQL error.
- Completed these read-only metadata searches, all with zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
```

- On 30 July 2026, the user approved stopping further `CreateCoAndLines` reverse-engineering and pivoting to review/adapt a previous working stored procedure that inserted into `co_mst` and `coitem_mst`.
- Further `EventActionRevisions`, `EventHandlerRevisions`, form metadata, and script discovery is cancelled unless the SP path later proves unsuitable.
- Direct inserts are not treated as automatically safe; the stored procedure must include transaction control, idempotency, duplicate prevention, validation, rollback, and staging status/error handling.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] Error Processing base form and Preview
[COMPLETED] customer validation and tests
[CONFIRMED] Customer Order header IDO = SL.SLCos
[CONFIRMED] Customer Order line IDO = SL.SLCoitems
[COMPLETED] controlled CreateCoAndLines probes and no-order checks
[COMPLETED] current event-handler/action call-site searches = zero rows
[STOPPED] further CreateCoAndLines reverse-engineering
[APPROVED] pivot to controlled stored procedure processing
[NEXT] obtain and review the previous working stored procedure
[PENDING] adapt SP to SMK069 staging and current tenant
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation test
```

### Planned

- Obtain the previous working stored procedure.
- Review its parameters, order number generation, required header/line columns, defaults, validation, transaction behavior, duplicate protection, and error handling.
- Adapt it to `dbo.ue_SMK069_temp_sales_mst`, the current process-control columns, and the current tenant.
- Do not execute direct Customer Order inserts until the adapted procedure has been reviewed and a controlled DEV test plan is approved.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
