# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- `SMK_RSC_POS_PaymentMap_mst`, `SMK_RSC_POS_TaxMap_mst`, `SMK_RSC_POS_RevenueMap_mst`, `SMK_RSC_POS_PostingPreview_mst`, `SMK_RSC_POS_Inbound_mst`, and `SMK_RSC_POS_RawLine_mst` designs.
- Minimum-data-profile, IDO architecture, manual CSV import, and layered testing documentation.
- `SMK069_temp_sales_mst` implementation documentation and six process-control fields.
- Completed `ue_SMK069APISalesErrorProcessing` base form and Preview documentation.
- `dbo.SMK069ValidateCustomerSp` and `ue_SMK069ValidateCustomerSp` implementation documentation.
- Evidence for invalid-customer direct SQL and Mongoose IDO REST tests.
- Evidence for valid-customer Mongoose REST response and persisted Valid staging result.
- `implementation/14-discover-standard-customer-order-processing.md` for tenant-specific standard Customer Order discovery.
- `tests/evidence/2026-07-30-standard-customer-order-header-ido.md` confirming the standard Customer Order header IDO.
- `tests/evidence/2026-07-30-standard-customer-order-line-ido.md` confirming the standard Customer Order line IDO.

### Changed

- Header total calculation confirmed as `SUM(unit_price * qty_ordered)`.
- `cost` removed from staging; cost will be obtained from `item_mst` during Customer Order processing.
- One standard `SiteRef` is used; no duplicate `site_ref` column.
- Confirmed tenant naming: stored procedure without `ue_`, custom IDO method with automatic `ue_`.
- Confirmed validation method parameters: `SiteRef`, `CoNum`, and output `Infobar`.
- Clarified that `cust_num` is read from staging and is not passed as method parameter 2.
- Completed invalid-customer SQL and Mongoose REST validation tests.
- Completed valid-customer Mongoose REST and persisted staging tests.
- Marked the first mandatory customer validation requirement fully completed.
- Recorded that `SL.SLCustomers / oCustomers` belongs to the Customers form and is not a Customer Order IDO.
- Confirmed the standard Customer Order entity IDOs from tenant evidence:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- Confirmed that Collection Name is blank/not assigned on both inspected standard forms.
- Advanced discovery from object identity to the available standard method/business-process review, starting with `SL.SLCos`.

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
[IN PROGRESS] standard Customer Order method/business-process discovery
[PENDING] custom Process/Reprocess method
[PENDING] controlled service IDO receive method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Inspect the available standard method names on `SL.SLCos` without modifying or executing them.
- Inspect `SL.SLCoitems` methods separately after the header-method review.
- Identify supported order-number generation, header creation, line creation, and save processing.
- Add reusable Process/Reprocess logic for `SiteRef + co_num` without direct inserts to standard tables.
- Design the controlled service IDO receive method shared by CSV and REST API ingestion.
- Create Customer Order header and lines using supported SyteLine business processing.
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
