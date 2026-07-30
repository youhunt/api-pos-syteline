# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- `SMK_RSC_POS_PaymentMap_mst`, `SMK_RSC_POS_TaxMap_mst`, `SMK_RSC_POS_RevenueMap_mst`, `SMK_RSC_POS_PostingPreview_mst`, `SMK_RSC_POS_Inbound_mst`, and `SMK_RSC_POS_RawLine_mst` designs.
- Minimum-data-profile, IDO architecture, manual CSV import, and layered testing documentation.
- `SMK069_temp_sales_mst` implementation documentation and six process-control fields.
- Completed `ue_SMK069APISalesErrorProcessing` base form and Preview documentation.
- `dbo.SMK069ValidateCustomerSp` and `ue_SMK069ValidateCustomerSp` implementation documentation.
- Evidence for invalid-customer direct SQL and Mongoose REST tests.
- Evidence for valid-customer Mongoose REST response and persisted Valid staging result.
- `implementation/14-discover-standard-customer-order-processing.md` for tenant-specific Customer Order discovery.
- Evidence confirming standard Customer Order IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- `tests/evidence/2026-07-30-slcoss-header-method-list.md` recording relevant standard header-method candidates.
- `tests/evidence/2026-07-30-create-co-and-lines-parameters.md` recording the standard extension-method parameter metadata.

### Changed

- Header total calculation confirmed as `SUM(unit_price * qty_ordered)`.
- `cost` removed from staging; cost is obtained from `item_mst` during Customer Order processing.
- One standard `SiteRef` is used; no duplicate `site_ref` column.
- Confirmed tenant naming: stored procedure without `ue_`, custom IDO method with automatic `ue_`.
- Completed customer validation for both valid and invalid branches through SQL and Mongoose REST evidence.
- Confirmed standard Customer Order entity IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Reviewed the `SL.SLCos` method-name list and identified creation-related candidates:

```text
CreateCoAndLines
NewCustomerOrderValidSp
CreateCoColSp
CoCustomerValidSp
CoCustomerValid2Sp
CoCustSeqValidSp
VerifyCoCustNumSp
CoNextKeyDelSp
SumCoSp
```

- Confirmed `CreateCoAndLines` classification:

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable
```

- Confirmed `CreateCoAndLines` parameter rows:

```text
1. CoAndLineInfoJson : VARIANT
2. CoResult          : VARIANT
```

- Recorded that parameter direction is not visible in the tenant grid and the exact JSON contract remains unconfirmed.
- Advanced the next step to a read-only metadata inspection of `IdoMethodParameters`; no business method execution is required.
- Kept the supported Customer Order creation sequence unconfirmed until method direction, JSON schema, and behavior are verified.

### Current SMK069 Status

```text
[COMPLETED] SMK069_temp_sales_mst table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp
[COMPLETED] ue_SMK069ValidateCustomerSp transactional IDO method
[COMPLETED] invalid-customer direct SQL and Mongoose REST tests
[COMPLETED] valid-customer Mongoose REST and persisted staging tests
[COMPLETED] mandatory customer validation requirement
[CONFIRMED] standard Customer Order header IDO = SL.SLCos
[CONFIRMED] standard Customer Order line IDO = SL.SLCoitems
[REVIEWED] SL.SLCos method-name list
[CONFIRMED] CreateCoAndLines is Extension Class - Standard Method
[CONFIRMED] CreateCoAndLines parameters = CoAndLineInfoJson, CoResult
[NEXT] inspect read-only IdoMethodParameters property metadata
[PENDING] custom Process/Reprocess method
[PENDING] controlled service IDO receive method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Call the read-only Mongoose metadata endpoint for `IdoMethodParameters` and identify its available properties.
- Load only the metadata rows for `SLCos / CreateCoAndLines` to determine whether output/by-reference information is exposed.
- Determine the exact `CoAndLineInfoJson` schema and `CoResult` behavior without risking standard-table inserts.
- Inspect `NewCustomerOrderValidSp` or `SL.SLCoitems` methods only after `CreateCoAndLines` has been evaluated.
- Add reusable Process/Reprocess logic for `SiteRef + co_num` without direct inserts into standard tables.
- Design the controlled service IDO receive method shared by CSV and REST API ingestion.
- Prepare sample CSV import, final API documentation, Postman collection, and deployment runbook.

## [0.1.0] — 2026-07-23

### Added

- Initial project README.
- Project overview and scope.
- Architecture and process flow.
- SyteLine Cloud naming convention using physical prefix `ue_`.
- Database design baseline.
- Draft API contract.
- Financial posting options.
- Development roadmap and history.
- Open questions checklist.