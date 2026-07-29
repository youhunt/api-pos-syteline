# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- `SMK_RSC_POS_PaymentMap_mst` design.
- Mapping payment code to main account, fee account, unit codes, optional customer, bank, and settlement behavior.
- Full SyteLine table-format documentation and tab-delimited structure for the payment mapping table.
- `SMK_RSC_POS_TaxMap_mst` design.
- Mapping POS tax code to SyteLine tax code/account, tax rate, inclusive flag, rounding mode, and tolerance.
- Full SyteLine table-format documentation and tab-delimited structure for the tax mapping table.
- `SMK_RSC_POS_RevenueMap_mst` design.
- Flexible priority-based rules for mapping item, category, outlet, channel, order type, line type, and currency to revenue, discount, service, or other accounts.
- Explicit debit/credit direction and refund reversal control for posting preparation.
- Full SyteLine table-format documentation and tab-delimited structure for the revenue mapping table.
- `SMK_RSC_POS_PostingPreview_mst` design.
- Preview generation/versioning, debit-credit lines, source and mapping traceability, multi-currency amounts, approval status, posting status, and SyteLine result reference.
- Balance rules for transaction and domestic currency before approval/posting.
- Full SyteLine table-format documentation and tab-delimited structure for the posting preview table.
- `SMK_RSC_POS_Inbound_mst` design.
- Request identity, correlation, idempotency, payload version/format, optional raw-payload storage, SHA-256 duplicate support, parsing result, counts, response metadata, retry, retention, and purge controls.
- Security rules preventing storage of secrets and prohibited payment data in raw payload/logging.
- Full SyteLine table-format documentation and tab-delimited structure for the inbound table.
- `SMK_RSC_POS_RawLine_mst` minimal/flat source design.
- Minimum-data-profile and requirement-change strategy documentation.
- IDO architecture overview covering entity IDO, monitor/composite IDO, and service IDO responsibilities.
- Candidate service IDO name `SMKRSCPosIntegration`.
- Manual CSV import flow for PoC, UAT, and operational fallback.
- Layered testing strategy and initial PoC test matrix.
- `SMK069_temp_sales_mst` implementation documentation aligned to the revised sales requirement.
- Six SMK069 process-control fields: `process_status`, `validation_msg`, `error_msg`, `retry_count`, `processed_date`, and `processed_by`.
- `implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md` with completed form and Preview evidence.
- `implementation/13-create-SMK069-customer-validation.md` with confirmed tenant method type and corrected prefix rules.
- `database/stored-procedures/SMK069ValidateCustomerSp.sql` draft implementation for reusable customer validation.
- `docs/17-current-status-and-new-chat-handoff.md` with current progress and API direction.
- Tenant evidence for completed Preview behavior and read-only `process_status` display mapping.

### Changed

- Standardized existing table documentation using the full SyteLine column format.
- Added standard Mongoose columns to documented table structures.
- Updated the architecture so public REST receive operations use controlled service IDO methods rather than direct entity-IDO writes.
- Aligned SMK069 phase 1 to sample CSV input because the official POS format is not yet available.
- Removed `cost` from the implemented SMK069 staging design; cost is obtained from `item_mst`.
- Corrected the SMK069 header calculation to `SUM(unit_price * qty_ordered)`.
- Replaced the duplicate `site_ref`/`SiteRef` concept with one standard `SiteRef` column.
- Marked the SMK069 base form, all four Preview behaviors, process-status display mapping, and read-only behavior as completed.
- Confirmed tenant support for `Stored Procedure - Standard Method` on `ue_SMK069TempSales`.
- Corrected the customer-validation procedure name from `dbo.ue_SMK069ValidateCustomerSp` to `dbo.SMK069ValidateCustomerSp`.
- Documented that stored procedures do not receive the `ue_` prefix in this tenant, while custom IDO method names receive `ue_` automatically.
- Kept the base business method name as `ValidateCustomer`; the exact generated `ue_` method name must be verified in the wizard before saving.
- Defined customer-not-found as a business validation result (`process_status = E`) rather than a technical stored-procedure failure.

### Current SMK069 Status

```text
[COMPLETED] SMK069_temp_sales_mst table
[COMPLETED] process-control columns
[COMPLETED] ue_SMK069TempSales IDO and properties update
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display and read-only verification
[CONFIRMED] Stored Procedure - Standard Method tenant option
[DRAFTED]   dbo.SMK069ValidateCustomerSp SQL source
[PENDING]   create customer validation stored procedure in tenant
[PENDING]   register tenant-generated ue_ customer validation IDO method
[PENDING]   Process/reprocess method
[PENDING]   controlled service IDO receive method
[PENDING]   REST API ingestion
[PENDING]   Customer Order header and line creation
```

### Planned

- Create `dbo.SMK069ValidateCustomerSp` in the tenant application database.
- Verify the procedure appears in the IDO Method Wizard Stored Procedure dropdown.
- Review the tenant-generated `ue_` Method Name and generated parameters before saving the transactional method.
- Test valid and invalid customer outcomes against `customer_mst`.
- Add controlled Process/Reprocess logic for `SiteRef + co_num`.
- Design and implement the controlled service IDO receive method shared by CSV and REST API ingestion.
- Create Customer Order header and lines using supported SyteLine processing.
- Prepare sample CSV import, REST/API documentation, Postman collection, and deployment runbook.

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
- Initial documentation for seven staging and mapping tables.
