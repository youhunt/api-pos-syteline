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

- Runtime and metadata evidence for the `CreateCoAndLines` discovery path, including four controlled probes, four no-order checks, zero-row current event-handler/action searches, and the `EventActionRevisions` property contract.
- Added:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
```

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

- Decision history on 30 July 2026:

```text
1. User temporarily approved a pivot to a prior stored-procedure approach.
2. No stored-procedure SQL was created or executed.
3. User subsequently instructed the project to continue CreateCoAndLines metadata discovery.
4. The stored-procedure path is now deferred as an alternative.
```

- Confirmed `EventActionRevisions` relevant properties:

```text
ExpandedParameters      : String(4000), read-only
ActionType              : Byte
Description             : String(40)
EventHandlerRowPointer  : GUID
Parameters              : String(3800)
Sequence                : Short Integer
RowPointer              : GUID, read-only
```

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
[CONFIRMED] EventActionRevisions property metadata
[RESUMED] CreateCoAndLines metadata discovery
[DEFERRED] direct-insert stored-procedure alternative
[NEXT] filter EventActionRevisions.Parameters for CreateCoAndLines
[PENDING] exact decoded JSON schema
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation test
```

### Planned

- Filter `EventActionRevisions.Parameters` for `CreateCoAndLines` using a read-only REST v1 load.
- Search revision `ExpandedParameters`, handler revisions, form metadata, or scripts only as later separate steps when required by tenant evidence.
- Extract the exact JSON-building and Base64-encoding contract from tenant evidence.
- Keep the controlled stored-procedure design as a deferred fallback; do not execute direct inserts while metadata discovery is active.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.