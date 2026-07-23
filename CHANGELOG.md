# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Changed

- Standardized all existing table documentation using the full SyteLine column format: `Column Name`, `Schema`, `Table Name`, `Data Type`, `System Data Type`, `Length`, `Decimal Position`, `Default Value`, `Is Nullable`, `Primary Key`, and `Key Sequence`.
- Added standard Mongoose columns to every documented table structure.
- Added `database/tables/TABLE_DOCUMENTATION_TEMPLATE.md` as the required format for subsequent table documentation.

### Planned

- Payment mapping table.
- Tax mapping table.
- Revenue mapping table.
- Posting preview design.
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
