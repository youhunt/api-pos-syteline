# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- Staging-table, IDO, form, validation, Customer Order discovery, and controlled runtime-probe documentation.
- Evidence confirming standard Customer Order IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Evidence confirming `CreateCoAndLines` metadata, parameters, parameter directions, collection hierarchy, extension owner, and binary-only assembly.
- `implementation/16-controlled-createcoandlines-runtime-probe.md` for controlled DEV contract discovery.
- Runtime evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
```

### Changed

- Header total confirmed as `SUM(unit_price * qty_ordered)`.
- Cost remains outside staging and is obtained from `item_mst` during Customer Order processing.
- Standard `SiteRef` is used; no duplicate `site_ref` column.
- Customer validation is completed for valid and invalid branches.
- Confirmed standard Customer Order entity IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Confirmed `CreateCoAndLines` classification:

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : false
Stored Proc.  : not applicable
```

- Confirmed parameter contract:

```text
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
- Completed raw malformed probe and confirmed `CoAndLineInfoJson` requires Base64 content.
- Completed first post-probe read-only check; no Customer Order was found in the checked 30-minute window.
- Completed Base64 `ew==` probe, which decodes to malformed `{`.
- Confirmed the decoded content is parsed as a JSON object / Newtonsoft `JObject`.
- Completed the second read-only recent-order verification after the `ew==` probe; it returned zero rows with no SQL error.
- Completed the empty-object probe using Base64 `e30=`, which decodes to `{}`.
- Confirmed the empty object passed Base64 decoding and JObject parsing but failed non-blank order-input validation with:

```text
The input for order creation cannot be blank
```

- Refined the public processing sequence to:

```text
Base64 decode
→ JSON object / JObject parse
→ non-blank order-input validation
→ Customer Order schema validation
→ Customer Order and line processing
```

- Confirmed again that `MessageCode = 0` does not establish business success; `CoResult` returned `Status = Fail`.
- Confirmed `CoResult` failure records do not always contain `ErrrorMessage`; the empty-object branch returned only `Status` and `Message`.
- Added a third read-only no-order verification gate before any non-empty contract probe.

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
[COMPLETED] raw malformed runtime probe
[CONFIRMED] input transport = Base64
[COMPLETED] first no-order verification = zero rows
[COMPLETED] malformed decoded JSON probe
[CONFIRMED] decoded payload must be JSON object / JObject
[COMPLETED] second no-order verification = zero rows
[COMPLETED] empty JSON object probe
[CONFIRMED] non-blank order input is required
[NEXT] third read-only no-order verification
[PENDING] exact decoded JSON schema
[PENDING] custom Process/Reprocess method
[PENDING] controlled receive API method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Repeat the read-only recent-order check after the empty-object probe.
- Only after a zero-row result, design one controlled non-empty marker-object probe without customer, item, site, order, date, quantity, or price values.
- Determine exact JSON property names, required header/line fields, `co_num` behavior, and success `CoResult` shape.
- Build reusable Process/Reprocess and controlled receive logic without direct inserts into `co_mst` or `coitem_mst`.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
