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
tests/evidence/2026-07-30-form-named-metadata-collections.md
tests/evidence/2026-07-30-formsandobjects-idoinfo-properties.md
tests/evidence/2026-07-30-formsandobjects-idoinfo-no-methods-section.md
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
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

- Attempted `EventActionRevisions.ExpandedParameters LIKE '%CreateCoAndLines%'`; the tenant returned `MessageCode 450`, `IllegalFilterException`, and `Items = null`. This is a rejected filter, not a zero-row result.
- Confirmed `EventHandlerRevisions` has no direct call-site text field.
- Script-name and script-description metadata discovery identified no useful production form/global-script candidate.
- Form metadata discovery selected `FormsAndObjects` as the strongest tenant-confirmed candidate.
- Confirmed `FormsAndObjects` publishes a utility/wrapper property contract, not obvious persistent fields for `FormName`, `Script`, `EventName`, `MethodToCall`, or `Parameters`.
- Confirmed the tenant's `idoinfo/FormsAndObjects` response exposes no `Methods` array.
- Used `IdoMethods` and confirmed:

```text
Rows returned  : 37
MethodType 2   : 17
MethodType 3   : 20
TxnFlag 0      : 37
StoredProcName : NULL for all rows
```

- Identified the strongest metadata candidates:

```text
UtilitiesListNames
UtilitiesLoadObjects / UtilitiesLoadObjects2
UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
GetUtilitiesOutput
```

- Compared both pseudo-code generator contracts. Each exposes 12 `VARIANT` parameters. Common parameters are:

```text
SessionID
SourceConfig
TargetConfig
Source
DatabaseName
Type
Scope
ObjectList
Version
SegmentCount
CompareIncludeSettings
```

- Confirmed `SegmentCount` is input/output; every other parameter is input-only, and no parameter is a message parameter.
- Confirmed the only contract difference is sequence 7:

```text
UtilitiesGeneratePseudoCode  : RelativePosition
UtilitiesGeneratePseudoCode2 : Options
```

- The possible list → load → generate pseudo-code → retrieve-output sequence remains an inference and has not been invoked.
- Selected read-only inspection of `GetUtilitiesOutput` parameters as the next step.
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
[COMPLETED] Script metadata discovery = no useful app script candidate
[COMPLETED] Form metadata discovery
[SELECTED] FormsAndObjects as strongest form metadata candidate
[CONFIRMED] FormsAndObjects property metadata
[NOT EXPOSED] FormsAndObjects Methods array in IDOInfo response
[COMPLETED] FormsAndObjects method metadata = 37 methods
[COMPLETED] pseudo-code generator parameter comparison
[RESUMED] CreateCoAndLines metadata discovery
[DEFERRED] direct-insert stored-procedure alternative
[NEXT] read GetUtilitiesOutput parameter metadata
[PENDING] exact decoded JSON schema
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation test
```

### Planned

- Read `FormsAndObjects.GetUtilitiesOutput` parameter metadata without invoking the method.
- Do not run either pseudo-code generator until valid values and serialization formats for all required `VARIANT` inputs are tenant-confirmed.
- Extract the exact JSON-building and Base64-encoding contract from tenant evidence.
- Keep the controlled stored-procedure design as a deferred fallback; do not execute direct inserts while metadata discovery is active.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.