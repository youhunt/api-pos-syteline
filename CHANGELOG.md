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
- Minimum-data-profile and requirement-change strategy documentation.

### Changed

- Standardized all existing table documentation using the full SyteLine column format: `Column Name`, `Schema`, `Table Name`, `Data Type`, `System Data Type`, `Length`, `Decimal Position`, `Default Value`, `Is Nullable`, `Primary Key`, and `Key Sequence`.
- Added standard Mongoose columns to every documented table structure.
- Added `database/tables/TABLE_DOCUMENTATION_TEMPLATE.md` as the required format for subsequent table documentation.
- Updated README and database design to include payment, tax, and revenue mappings.
- Clarified that current tables are candidate PoC designs and may be simplified or adjusted after the official raw data and accounting flow are received.

### Planned

- Posting preview design.
- Final table selection after raw data review.
- IDO design.
- Custom form design.
- Stored procedure specification.
- REST API implementation notes.
- Postman collection.
- Test scenarios and deployment runbook.

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
