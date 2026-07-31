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
tests/evidence/2026-07-31-formsandobjects-getutilitiesoutput-parameters.md
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
tests/evidence/2026-07-31-customerordersquickentry-selected-as-call-site-candidate.md
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
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
- Completed direct event/action call-site searches with zero rows.
- Classified `EventActionRevisions.ExpandedParameters` as an illegal/rejected filter, not a zero-row result.
- Confirmed `EventHandlerRevisions` has no direct call-site text field.
- Script-name and script-description discovery identified no useful production form/global-script candidate.
- Confirmed `FormsAndObjects` is a utility/wrapper contract and its `idoinfo` response exposes no `Methods` array.
- Used `IdoMethods` and confirmed 37 `FormsAndObjects` methods.
- Compared `UtilitiesGeneratePseudoCode` and `UtilitiesGeneratePseudoCode2`; each has 12 `VARIANT` parameters and differs only at sequence 7 (`RelativePosition` versus `Options`).
- Confirmed `GetUtilitiesOutput` accepts `SessionID` and `SegmentNumber`.
- Confirmed the visible `Form Control > Utilities` tab contains only device-type synchronization actions. No Sync action was executed, and that path is stopped.
- User explicitly reconfirmed `SL.SLCos.CreateCoAndLines` as the active implementation direction; direct SQL insert remains fallback only.
- Selected `CustomerOrdersQuickEntry` as the strongest current standard call-site candidate.
- Confirmed its primary header collection is `SLCos` with collection name `oSLCos`.
- Confirmed its line grid is a `SubCollection Grid` using parent `primary collection`, subcollection property `SLCoitems`, and collection name `oLines`.
- Confirmed `Reload After Child Save` is enabled, update locking is `Row`, and no custom load method is configured for header or line.
- Confirmed a top-level `Secondary Collection 2: SLAppsParms` exists; its role remains uninspected.
- The bindings prove the standard header/detail relationship but do not yet prove that the form invokes `CreateCoAndLines`; ordinary parent-child collection Save remains possible.
- Selected form event/script search for `CreateCoAndLines` as the next controlled step.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] Error Processing base form and Preview
[COMPLETED] customer validation and tests
[CONFIRMED] Customer Order header IDO = SL.SLCos
[CONFIRMED] Customer Order line IDO = SL.SLCoitems
[COMPLETED] controlled CreateCoAndLines probes and no-order checks
[COMPLETED] direct event/action call-site searches = zero rows
[FAILED] EventActionRevisions.ExpandedParameters filter = IllegalFilterException
[COMPLETED] FormsAndObjects metadata and method inspection
[STOPPED] Form Control Utilities path = device synchronization only
[ACTIVE] SL.SLCos.CreateCoAndLines standard-method direction
[SELECTED] CustomerOrdersQuickEntry as form call-site candidate
[CONFIRMED] CustomerOrdersQuickEntry SLCos/oSLCos header binding
[CONFIRMED] CustomerOrdersQuickEntry SLCoitems/oLines subcollection binding
[DEFERRED] direct-insert stored-procedure alternative
[NEXT] search CustomerOrdersQuickEntry events/scripts for CreateCoAndLines
[PENDING] exact decoded JSON schema
[PENDING] implement Process/Reprocess
[PENDING] implement controlled receive API
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation test
```

### Planned

- Search `CustomerOrdersQuickEntry` form events/scripts for `CreateCoAndLines` without saving or customizing the form.
- If no direct reference exists, inspect New, Save, and Quick Order Verification event sequences separately.
- Extract the exact JSON-building and Base64-encoding contract when tenant evidence exposes it.
- Keep direct SQL inserts as a deferred fallback.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
