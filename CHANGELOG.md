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
- Evidence file `tests/evidence/2026-07-30-smk069-valid-customer-ido-rest-response.md` for the successful valid-customer API response.
- Evidence file `tests/evidence/2026-07-30-smk069-valid-customer-staging-result.md` confirming the persisted Valid result.
- `implementation/14-discover-standard-customer-order-processing.md` for tenant-specific standard Customer Order IDO and method discovery.

### Changed

- Header total calculation confirmed as `SUM(unit_price * qty_ordered)`.
- `cost` removed from staging; cost will be obtained from `item_mst` during Customer Order processing.
- One standard `SiteRef` is used; no duplicate `site_ref` column.
- Confirmed tenant naming: stored procedure without `ue_`, custom IDO method with automatic `ue_`.
- Confirmed validation method parameters: `SiteRef`, `CoNum`, and output `Infobar`.
- Clarified that `cust_num` is read from staging and is not passed as method parameter 2.
- Completed invalid-customer SQL and IDO REST validation tests.
- Updated staging test customers to real customer values:

```text
DEFAULT | TEST000001 | C000001 | line 1
DEFAULT | TEST000001 | C000001 | line 2
DEFAULT | TEST000002 | C000002 | line 1
```

- Recorded valid-customer Mongoose IDO REST response for `DEFAULT + TEST000002`:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    ""
  ],
  "ReturnValue": "0"
}
```

- Verified the persisted valid-customer staging result:

```text
SiteRef        : DEFAULT
co_num         : TEST000002
co_line        : 1
cust_num       : C000002
process_status : V
validation_msg : NULL
```

- Marked the first mandatory customer validation requirement fully completed for both valid and invalid branches.
- Advanced development to tenant-specific discovery of the standard Customer Order IDO and supported business process before creating custom Process/Reprocess logic.
- Recorded that the first discovery screenshot showed `SL.SLCustomers` with collection `oCustomers`, which belongs to the standard Customers form and is not the Customer Order header IDO.
- Kept the standard Customer Order header IDO status as not confirmed; the correct Customer Orders form must still be inspected.

### Current SMK069 Status

```text
[COMPLETED] SMK069_temp_sales_mst table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp
[COMPLETED] ue_SMK069ValidateCustomerSp transactional IDO method
[COMPLETED] generated parameter review
[COMPLETED] invalid-customer direct SQL test
[COMPLETED] invalid-customer Mongoose IDO REST test
[COMPLETED] valid-customer Mongoose IDO REST response
[COMPLETED] valid-customer persisted staging result
[COMPLETED] mandatory customer validation requirement
[IN PROGRESS] standard Customer Order IDO/business-process discovery
[NOT CONFIRMED] standard Customer Order header IDO
[PENDING] custom Process/reprocess method
[PENDING] controlled service IDO receive method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Open the correct standard Customer Orders form in Design Mode and identify its exact primary collection IDO in this tenant.
- Inspect supported standard Customer Order methods after the tenant IDO is confirmed.
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