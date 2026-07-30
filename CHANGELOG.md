# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- `SMK_RSC_POS_PaymentMap_mst` design.
- Mapping payment code to main account, fee account, unit codes, optional customer, bank, and settlement behavior.
- `SMK_RSC_POS_TaxMap_mst` design.
- `SMK_RSC_POS_RevenueMap_mst` design.
- `SMK_RSC_POS_PostingPreview_mst` design.
- `SMK_RSC_POS_Inbound_mst` design.
- `SMK_RSC_POS_RawLine_mst` minimal/flat source design.
- Minimum-data-profile and requirement-change strategy documentation.
- IDO architecture overview covering entity IDO, monitor/composite IDO, and service IDO responsibilities.
- Candidate service IDO name `SMKRSCPosIntegration`.
- Manual CSV import flow for PoC, UAT, and operational fallback.
- Layered testing strategy and initial PoC test matrix.
- `SMK069_temp_sales_mst` implementation documentation aligned to the revised sales requirement.
- Six SMK069 process-control fields: `process_status`, `validation_msg`, `error_msg`, `retry_count`, `processed_date`, and `processed_by`.
- `implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md` with completed form and Preview evidence.
- `implementation/13-create-SMK069-customer-validation.md` with method configuration, persistence evidence, SQL test, IDO REST test, and parameter-semantics correction.
- `database/stored-procedures/SMK069ValidateCustomerSp.sql` implementation for reusable customer validation.
- `docs/17-current-status-and-new-chat-handoff.md` with current progress and API direction.
- Tenant evidence for completed Preview behavior and read-only `process_status` display mapping.
- Confirmed customer-validation IDO method `ue_SMK069ValidateCustomerSp` with Transactional enabled.
- Confirmed generated parameter order: `SiteRef`, `CoNum`, and `Infobar`.
- Controlled invalid-customer evidence: `DEFAULT / TEST000002 / TST0002` is absent from `customer_mst`.
- Successful direct execution evidence for `dbo.SMK069ValidateCustomerSp`: ReturnCode `0`, `process_status = E`, and customer-not-found Infobar/validation message.
- Successful Mongoose IDO REST invocation evidence with `MessageCode = 0`, `ReturnValue = 0`, and the returned customer-not-found Infobar.
- `tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md` containing the IDO REST response and verification result.
- Recorded the expected `ReturnValue = 16` response when `C000001` was supplied as parameter 2 and interpreted as a non-existent staging `CoNum`.

### Changed

- Standardized existing table documentation using the full SyteLine column format.
- Added standard Mongoose columns to documented table structures.
- Updated the architecture so public REST receive operations use controlled service IDO methods rather than direct entity-IDO writes.
- Aligned SMK069 phase 1 to sample CSV input because the official POS format is not yet available.
- Removed `cost` from the implemented SMK069 staging design; cost is obtained from `item_mst`.
- Corrected the SMK069 header calculation to `SUM(unit_price * qty_ordered)`.
- Replaced the duplicate `site_ref`/`SiteRef` concept with one standard `SiteRef` column.
- Marked the SMK069 base form, all Preview behaviors, process-status display mapping, and read-only behavior as completed.
- Confirmed tenant support for `Stored Procedure - Standard Method` on `ue_SMK069TempSales`.
- Corrected the customer-validation procedure name to `dbo.SMK069ValidateCustomerSp` while the IDO method receives the automatic `ue_` prefix.
- Defined customer-not-found as a business validation result (`process_status = E`) rather than a technical execution failure.
- Completed generated parameter review and method persistence verification.
- Completed both direct stored-procedure and Mongoose IDO REST invalid-customer tests.
- Clarified that method parameter 2 is `CoNum`, not `cust_num`; the procedure reads `cust_num` from the selected staging rows.
- Updated the valid-customer test pattern to assign a real customer to `TEST000001`, then invoke the method with `DEFAULT, TEST000001, <blank Infobar>`.
- Advanced the current task to verifying candidate customer `C000001` exists for site `DEFAULT` and `cust_seq = 0`.

### Current SMK069 Status

```text
[COMPLETED] SMK069_temp_sales_mst table
[COMPLETED] process-control columns
[COMPLETED] ue_SMK069TempSales IDO and properties update
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp created in tenant
[COMPLETED] ue_SMK069ValidateCustomerSp IDO method persisted
[COMPLETED] generated parameter review
[COMPLETED] invalid-customer test case confirmation
[COMPLETED] direct stored-procedure invalid-customer execution test
[COMPLETED] invalid-customer Mongoose IDO REST invocation test
[CONFIRMED] parameter 2 is CoNum, not cust_num
[NEXT]      verify DEFAULT / C000001 / cust_seq 0 exists
[PENDING]   valid-customer validation execution test
[PENDING]   Process/reprocess method
[PENDING]   controlled service IDO receive method
[PENDING]   final REST API ingestion
[PENDING]   Customer Order header and line creation
```

### Planned

- Verify `C000001` exists in `customer_mst` for `site_ref = DEFAULT` and `cust_seq = 0`.
- Assign the verified customer temporarily to the `TEST000001` staging rows and reset their validation state.
- Invoke `ue_SMK069ValidateCustomerSp` with `DEFAULT, TEST000001, <blank Infobar>` and verify the Valid result.
- Add controlled Process/Reprocess logic for `SiteRef + co_num`.
- Design and implement the controlled service IDO receive method shared by CSV and REST API ingestion.
- Create Customer Order header and lines using supported SyteLine processing.
- Prepare sample CSV import, final REST/API documentation, Postman collection, and deployment runbook.

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