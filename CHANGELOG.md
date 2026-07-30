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

### Changed

- Header total calculation confirmed as `SUM(unit_price * qty_ordered)`.
- `cost` removed from staging; cost will be obtained from `item_mst` during Customer Order processing.
- One standard `SiteRef` is used; no duplicate `site_ref` column.
- Confirmed tenant naming: stored procedure without `ue_`, custom IDO method with automatic `ue_`.
- Confirmed method parameters: `SiteRef`, `CoNum`, and output `Infobar`.
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

- Advanced validation testing to direct staging verification for `process_status = V` and `validation_msg = NULL`.

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
[NEXT]      verify TEST000002 process_status = V and validation_msg = NULL
[PENDING]   Process/reprocess method
[PENDING]   controlled service IDO receive method
[PENDING]   final external POS REST API contract
[PENDING]   Customer Order header and line creation
```

### Planned

- Verify the `TEST000002` staging row after the successful valid-customer API response.
- Mark customer validation fully completed only after the row contains `process_status = V` and `validation_msg = NULL`.
- Add controlled Process/Reprocess logic for `SiteRef + co_num`.
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