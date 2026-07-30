# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- Staging-table, IDO, Error Processing form, validation, Customer Order discovery, and controlled runtime-probe documentation.
- Evidence confirming standard Customer Order IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Evidence confirming `CreateCoAndLines` metadata, parameters, directions, collection hierarchy, extension owner, and binary-only assembly.
- Controlled discovery documents:

```text
implementation/16-controlled-createcoandlines-runtime-probe.md
implementation/17-createcoandlines-nonbusiness-marker-probe.md
implementation/18-discover-createcoandlines-call-sites.md
```

- Runtime and metadata evidence:

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
```

### Changed

- Header total confirmed as `SUM(unit_price * qty_ordered)`.
- Cost remains outside staging and is obtained from `item_mst` during Customer Order processing.
- Standard `SiteRef` is used; no duplicate `site_ref` column.
- Customer validation is complete for valid and invalid branches.
- Confirmed standard Customer Order entity IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Confirmed `CreateCoAndLines` classification and parameter contract:

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : false
Stored Proc.  : not applicable

CoAndLineInfoJson : input-only
CoResult          : input/output + message parameter
```

- Confirmed collection hierarchy and implementation owner:

```text
SLCos
├── SLCos_FT extends SLCos
└── ZIT_SLCos extends SLCos

Extension owner : Customer.SLCos
Assembly        : Customer — Binary Only
```

- Confirmed runtime environment as DEV and disposable testing as allowed.
- Confirmed public input processing sequence:

```text
Base64 decode
→ JSON object / JObject parse
→ locate expected non-blank order structure
→ Customer Order schema validation
→ Customer Order and line processing
```

- Confirmed `MessageCode = 0` does not establish business success; parse `CoResult` and evaluate `Status`.
- Confirmed `CoResult` is a JSON-array string and failure records may or may not contain `ErrrorMessage`.
- Completed four controlled probes:

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

- Confirmed an arbitrary non-empty property does not satisfy the required order-input contract.
- Completed four post-probe read-only `dbo.co_mst` checks; every check returned zero rows with no SQL error.
- Stopped guessing business-schema property names.
- Pivoted to read-only discovery of standard form/event/script metadata that calls `SLCos.CreateCoAndLines`.
- Confirmed tenant event-related metadata IDOs:

```text
EventHandlerRevisions
EventHandlers
EventHandlerStates
IdoEventHandlerAppliesToObjects
IdoEventHandlerAppliesToTasks
QueuedEventHandlers
```

- Confirmed all six are published from `MGCore` with `AccessAs = Core`.
- Confirmed `EventHandlers` publishes call-site-relevant properties including `MethodToCall` and child `EventActions`.
- Completed the read-only `EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'` search.
- Confirmed the request succeeded but returned zero rows, so no parent handler stores the target directly in `MethodToCall`.
- Confirmed tenant event-action metadata collections:

```text
EventAction_GenericParms
EventActionRevisions
EventActions
EventActionStates
EventActionVariableAccess
```

- Selected `EventActions` as the primary child-action metadata candidate based on the tenant description `Event Actions`.
- Kept generic parameters, revisions, state/status, and variable-access collections as separate later paths whose properties remain uninspected.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] Error Processing base form and Preview
[COMPLETED] customer validation and tests
[CONFIRMED] Customer Order header IDO = SL.SLCos
[CONFIRMED] Customer Order line IDO = SL.SLCoitems
[CONFIRMED] CreateCoAndLines = Extension Class - Standard Method
[CONFIRMED] CoAndLineInfoJson = input-only
[CONFIRMED] CoResult = input/output + message
[CONFIRMED] implementation owner = Customer.SLCos
[CONFIRMED] assembly Customer = Binary Only
[COMPLETED] four controlled malformed/non-business probes
[CONFIRMED] input transport = Base64
[CONFIRMED] decoded payload = JSON object / JObject
[CONFIRMED] specific order structure is required
[COMPLETED] four no-order checks = zero rows
[CONFIRMED] candidate event metadata IDOs
[CONFIRMED] EventHandlers property metadata
[COMPLETED] parent MethodToCall search = zero rows
[CONFIRMED] event-action metadata collections
[NEXT] read EventActions property metadata
[PENDING] locate exact standard CreateCoAndLines call site
[PENDING] exact decoded JSON schema
[PENDING] custom Process/Reprocess method
[PENDING] controlled receive API method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Read `EventActions` IDOInfo property metadata.
- Locate standard tenant call sites for `SLCos.CreateCoAndLines` without editing metadata.
- Inspect revision, generic-parameter, form, or script metadata only as later separate steps when tenant evidence requires them.
- Extract the exact JSON-building and Base64-encoding contract from tenant evidence.
- Build reusable Process/Reprocess and controlled receive logic without direct inserts into `co_mst` or `coitem_mst`.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.