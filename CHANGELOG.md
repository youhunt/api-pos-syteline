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
- Minimal source fields for business date, transaction number, POS item, source quantity, and total amount.
- Separate mapping-result fields for SyteLine item, converted quantity, and U/M so source values are not overwritten.
- Flat-row transaction grouping and reconciliation rules.
- Full SyteLine table-format documentation and tab-delimited structure for the raw-line table.
- Minimum-data-profile and requirement-change strategy documentation.
- IDO architecture overview covering entity IDO, monitor/composite IDO, and service IDO responsibilities.
- Candidate entity IDO catalog and service IDO name `SMKRSCPosIntegration`.
- `SMKRSCPosInbounds` IDO design with full property mapping, default property list, status transition, subcollection, authorization matrix, restricted payload access, retry, purge, form usage, and test scenarios.
- IDO Wizard clarification explaining that entity, monitor/composite, and service are architectural roles rather than separate Mongoose object types.
- Wizard implementation patterns for table-backed entity IDOs, read-only monitor IDOs, and method-focused service IDOs.
- `SMKRSCPosBatches` entity IDO design with wizard values, full property mapping, update policy, profile-dependent subcollections, security, form design, review checklist, and tests.
- Manual CSV import flow for PoC, UAT, and operational fallback.
- `SMKRSCPosImportCenter` form design with browse/attachment, validation, transactional staging import, raw-line review, and error-log review.
- Candidate service methods `CreateManualInbound`, `ValidateAttachedCsv`, and `ImportAttachedCsv`.
- Versioned minimal CSV template `templates/pos-minimal-v1.csv`.
- Layered testing strategy from metadata smoke test through controlled actual-posting test.
- Initial 30-case PoC test matrix covering valid receive, mapping, reconciliation, idempotency, retry, security, preview, and concurrency.
- Synthetic minimal-profile payloads for valid, unmapped-item, and negative-quantity scenarios.
- Test workspace and evidence-recording guidance under `tests/`.
- `SMK069_temp_sales_mst` implementation documentation aligned to the revised sales requirement.
- Six SMK069 process-control fields: `process_status`, `validation_msg`, `error_msg`, `retry_count`, `processed_date`, and `processed_by`.
- `implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md` with the next-step base-form guide.
- `docs/17-current-status-and-new-chat-handoff.md` with actual progress, development rules, and a ready-to-paste new-chat prompt.

### Changed

- Standardized all existing table documentation using the full SyteLine column format: `Column Name`, `Schema`, `Table Name`, `Data Type`, `System Data Type`, `Length`, `Decimal Position`, `Default Value`, `Is Nullable`, `Primary Key`, and `Key Sequence`.
- Added standard Mongoose columns to every documented table structure.
- Added `database/tables/TABLE_DOCUMENTATION_TEMPLATE.md` as the required format for subsequent table documentation.
- Updated README and database design to include payment, tax, revenue, posting-preview, inbound-request, and minimal raw-line designs.
- Clarified that the complete transaction model and minimal flat model are alternatives selected after reviewing the official source data.
- Clarified that current tables and IDOs are candidate PoC designs and may be simplified or adjusted after the official raw data, retention policy, accounting flow, and tenant standard are received.
- Updated the architecture so public REST receive operations use controlled service IDO methods rather than direct entity-IDO writes.
- Clarified that an entity, monitor, or service role is implemented with standard Mongoose IDO metadata; service behavior is supplied through IDO methods.
- Established posting preview as the safe PoC boundary before actual financial posting is enabled.
- Established manual CSV upload as an implementation step before the remaining complete-profile IDOs, using the same service processing core planned for REST API input.
- Aligned SMK069 phase 1 to sample CSV input because the official POS file format is not yet available.
- Removed `cost` from the implemented SMK069 staging design after confirmation that cost is obtained from `item_mst`.
- Corrected the SMK069 header calculation to `SUM(unit_price * qty_ordered)`.
- Replaced the duplicate `site_ref`/`SiteRef` concept with one standard `SiteRef` column.
- Updated SMK069 progress to reflect that the table and `ue_SMK069TempSales` IDO are complete while the form is not yet created.

### Current SMK069 Status

```text
[COMPLETED] SMK069_temp_sales_mst table
[COMPLETED] process-control columns
[COMPLETED] ue_SMK069TempSales IDO and properties update
[NEXT]      ue_SMK069APISalesErrorProcessing base form
[PENDING]   Preview filters
[PENDING]   customer validation
[PENDING]   Process/reprocess method
[PENDING]   Customer Order header and line creation
```

### Planned

- Create the base `ue_SMK069APISalesErrorProcessing` Grid Only form.
- Add Order Date and CO Number Preview filters after the base form passes its smoke test.
- Add `cust_num` validation against `customer_mst`.
- Add controlled Process/Reprocess logic for all lines belonging to the selected `SiteRef + co_num`.
- Create Customer Order header and lines using supported SyteLine processing.
- Prepare the SMK069 sample CSV and import flow.
- Produce the final technical API document using the Nava_TempJournal document format as reference.
- Minimum entity IDOs required by manual import: raw-line, process-log, and item-map IDOs.
- `SMKRSCPosIntegration` service-method implementation for manual CSV import.
- Remaining transaction, payment, mapping, and posting-preview entity IDOs.
- Monitor/composite IDO design.
- Final table/profile selection after raw data review.
- Verify attachment access, CSV parser support, file-size limits, and retention policy in the tenant.
- REST API implementation notes.
- Postman collection.
- Automated test execution and deployment runbook.

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

### Designed Tables

- `SMK_RSC_POS_Batch_mst`
- `SMK_RSC_POS_Tran_mst`
- `SMK_RSC_POS_TranLine_mst`
- `SMK_RSC_POS_Payment_mst`
- `SMK_RSC_POS_ProcessLog_mst`
- `SMK_RSC_POS_OutletMap_mst`
- `SMK_RSC_POS_ItemMap_mst`

### Notes

The repository is currently in Proof-of-Concept design stage. The API and financial posting route remain subject to official source data and Finance/SyteLine decisions.