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

- Runtime and metadata evidence for the `CreateCoAndLines` discovery path, including:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-script-named-metadata-collections.md
tests/evidence/2026-07-30-script-description-metadata-collections.md
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
- Completed these read-only metadata searches with zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

- Attempted `EventActionRevisions.ExpandedParameters LIKE '%CreateCoAndLines%'`; the tenant returned `MessageCode 450`, `IllegalFilterException`, and `Items = null`.
- Classified that attempt as a rejected filter, not a zero-row result.
- Confirmed `EventHandlerRevisions` has no direct call-site text field and instead exposes child `EventActionRevisions`/`EventActions`.
- Searched tenant collection names for `Script`; no production form/global script metadata candidate was identified.
- Searched tenant collection descriptions for `script`; results were:

```text
BuildApplicationMessagesScript : temporary application-message script-generation IDO
Deployment                     : deployment scripts/XML for applet deployment
SLInvSequences                 : lexical false positive because "description" contains "script"
SLInvSequences_IDS             : same lexical false-positive mechanism
```

- Concluded that neither the script-name nor script-description discovery path identified a useful application call-site metadata source.
- Selected tenant `Form` collection discovery as the next read-only path.
- Decision history on 30 July 2026:

```text
1. User temporarily approved a pivot to a prior stored-procedure approach.
2. No stored-procedure SQL was created or executed.
3. User subsequently instructed the project to continue CreateCoAndLines metadata discovery.
4. The stored-procedure path is now deferred as an alternative.
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
[COMPLETED] EventActionRevisions.Parameters search = zero rows
[FAILED] EventActionRevisions.ExpandedParameters filter = IllegalFilterException
[CONFIRMED] EventHandlerRevisions has no direct call-site text field
[COMPLETED] Script-named collection discovery = no useful app script candidate
[COMPLETED] Script-description discovery = no useful app script candidate
[RESUMED] CreateCoAndLines metadata discovery
[DEFERRED] direct-insert stored-procedure alternative
[NEXT] discover tenant collections whose names contain Form
[PENDING] exact decoded JSON schema
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation test
```

### Planned

- Discover tenant `IdoCollections` whose names contain `Form`.
- Select a relevant form metadata candidate from tenant evidence before reading its property contract or rows.
- Extract the exact JSON-building and Base64-encoding contract from tenant evidence.
- Keep the controlled stored-procedure design as a deferred fallback; do not execute direct inserts while metadata discovery is active.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
