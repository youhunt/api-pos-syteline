# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- Staging-table, IDO, Error Processing form, validation, Customer Order discovery, and controlled runtime-probe documentation.
- Controlled discovery documents:

```text
implementation/16-controlled-createcoandlines-runtime-probe.md
implementation/17-createcoandlines-nonbusiness-marker-probe.md
implementation/18-discover-createcoandlines-call-sites.md
```

- Runtime and metadata evidence including:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
tests/evidence/2026-07-30-createcoandlines-empty-object-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-nonbusiness-marker-blank-order-failure.md
tests/evidence/2026-07-30-createcoandlines-marker-probe-no-order-created.md
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
tests/evidence/2026-07-30-event-action-metadata-collections.md
tests/evidence/2026-07-30-eventactions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactions-expandedparameters-createcoandlines-no-match.md
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

- Confirmed `CreateCoAndLines` contract:

```text
IDO Name             : SLCos
Method Name          : CreateCoAndLines
Method Type          : Extension Class - Standard Method
Transactional        : false
Implementation owner : Customer.SLCos
Assembly             : Customer — Binary Only
CoAndLineInfoJson    : input-only
CoResult             : input/output + message parameter
```

- Confirmed runtime processing sequence:

```text
Base64 decode
→ JSON object / JObject parse
→ locate expected non-blank order structure
→ Customer Order schema validation
→ Customer Order and line processing
```

- Completed four controlled probes and four read-only `dbo.co_mst` checks; every check returned zero rows with no SQL error.
- Confirmed `MessageCode = 0` is not business success; parse `CoResult` and evaluate `Status`.
- Stopped guessing business-schema property names and pivoted to read-only metadata call-site discovery.
- Confirmed event-handler and event-action metadata collections and their relevant properties.
- Completed these read-only searches, all with zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
```

- Selected `EventActions.SubstitutedParameters` as the next separate fallback. Revision metadata remains a later path.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] Error Processing base form and Preview
[COMPLETED] customer validation and tests
[CONFIRMED] Customer Order header IDO = SL.SLCos
[CONFIRMED] Customer Order line IDO = SL.SLCoitems
[CONFIRMED] CreateCoAndLines method metadata and parameter contract
[CONFIRMED] implementation owner = Customer.SLCos
[CONFIRMED] assembly Customer = Binary Only
[COMPLETED] four controlled malformed/non-business probes
[COMPLETED] four no-order checks = zero rows
[COMPLETED] parent MethodToCall search = zero rows
[COMPLETED] raw EventActions.Parameters search = zero rows
[COMPLETED] EventActions.ExpandedParameters search = zero rows
[NEXT] filter EventActions.SubstitutedParameters for CreateCoAndLines
[PENDING] locate exact standard CreateCoAndLines call site
[PENDING] exact decoded JSON schema
[PENDING] custom Process/Reprocess method
[PENDING] controlled receive API method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Filter `EventActions.SubstitutedParameters` for `CreateCoAndLines` using a read-only REST v1 load.
- Inspect revision, form, or script metadata only as later separate steps if the substituted search returns no match.
- Extract the exact JSON-building and Base64-encoding contract from tenant evidence.
- Build reusable Process/Reprocess and controlled receive logic without direct inserts into `co_mst` or `coitem_mst`.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
