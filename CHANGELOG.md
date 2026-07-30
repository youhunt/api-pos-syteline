# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- `SMK_RSC_POS_PaymentMap_mst`, `SMK_RSC_POS_TaxMap_mst`, `SMK_RSC_POS_RevenueMap_mst`, `SMK_RSC_POS_PostingPreview_mst`, `SMK_RSC_POS_Inbound_mst`, and `SMK_RSC_POS_RawLine_mst` designs.
- Minimum-data-profile, IDO architecture, manual CSV import, and layered testing documentation.
- `SMK069_temp_sales_mst` implementation documentation and six process-control fields.
- Completed `ue_SMK069APISalesErrorProcessing` base form and Preview documentation.
- `dbo.SMK069ValidateCustomerSp` and `ue_SMK069ValidateCustomerSp` implementation documentation.
- Evidence for invalid-customer and valid-customer SQL/Mongoose REST tests.
- `implementation/14-discover-standard-customer-order-processing.md` for tenant-specific Customer Order discovery.
- Evidence confirming standard Customer Order IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

- `tests/evidence/2026-07-30-slcoss-header-method-list.md` recording relevant standard header-method candidates.
- `tests/evidence/2026-07-30-create-co-and-lines-parameters.md` recording standard extension-method parameter names.
- `implementation/15-idomethodparameters-metadata-fallback.md` documenting metadata-route, collection, and assembly discovery.
- `tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md` recording the generic HTTP 500 response.
- `tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md` confirming published parameter metadata properties.
- `tests/evidence/2026-07-30-create-co-and-lines-parameter-directions.md` confirming `InputFlag`, `OutputFlag`, and `MessageFlag`.
- `tests/evidence/2026-07-30-idomethods-idoinfo-properties.md` confirming published method-level metadata properties.
- `tests/evidence/2026-07-30-create-co-and-lines-method-row.md` recording effective method contexts for `SLCos`, `SLCos_FT`, and `ZIT_SLCos`.
- `tests/evidence/2026-07-30-idocollections-idoinfo-properties.md` confirming collection-level extension and inheritance metadata properties.
- `tests/evidence/2026-07-30-idocollections-slcoss-hierarchy.md` confirming the collection hierarchy and `Customer.SLCos` extension-owner metadata.
- `tests/evidence/2026-07-30-customer-assembly-binary-only.md` confirming that standard assembly `Customer` is published as Binary Only.

### Changed

- Header total calculation confirmed as `SUM(unit_price * qty_ordered)`.
- `cost` removed from staging; cost is obtained from `item_mst` during Customer Order processing.
- One standard `SiteRef` is used; no duplicate `site_ref` column.
- Confirmed tenant naming: stored procedure without `ue_`, custom IDO method with automatic `ue_`.
- Completed customer validation for valid and invalid branches through SQL and Mongoose REST evidence.
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

- Confirmed parameter direction contract:

```text
CoAndLineInfoJson : VARIANT, InputFlag=1, OutputFlag=0, MessageFlag=0
CoResult          : VARIANT, InputFlag=1, OutputFlag=1, MessageFlag=1
```

- Confirmed that `CoAndLineInfoJson` is input-only.
- Confirmed that `CoResult` is input/output and is the framework message parameter.
- Replaced the failed `/ido/info/IdoMethodParameters` route with successful REST v1 metadata calls.
- Confirmed that `IdoMethods` exposes method-level metadata but not direct source-code or JSON-schema properties.
- Completed the filtered `IdoMethods` load for `SLCos / CreateCoAndLines`.
- Confirmed the actual collection hierarchy:

```text
SLCos
├── SLCos_FT extends SLCos
└── ZIT_SLCos extends SLCos
```

- Confirmed base extension-owner metadata:

```text
Collection       : SLCos
Extension class  : SLCos
Namespace        : Customer
Custom assembly  : Customer
Server project   : Customer
Runtime identity : Customer.SLCos
```

- Confirmed that `SLCos_FT` and `ZIT_SLCos` inherit from `SLCos` and do not publish their own extension class, namespace, or custom assembly.
- Confirmed the standard `Customer` assembly record:

```text
Assembly Type    : Binary Only
Revision Num     : 1
Revision Date    : 5/12/2026
Access As        : BaseSyteLine
Filename         : Customer
Full Name        : Customer, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null
Symbol File Name : Customer.pdb
```

- Closed the tenant source-code discovery branch because the `Customer` assembly is binary-only and the assembly form does not expose `Customer.SLCos` source code.
- Kept the supported Customer Order creation sequence unconfirmed until the exact JSON schema and runtime result behavior are verified.
- Added an environment-safety gate before any controlled malformed/minimal runtime invocation.

### Current SMK069 Status

```text
[COMPLETED] SMK069_temp_sales_mst table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp
[COMPLETED] ue_SMK069ValidateCustomerSp transactional IDO method
[COMPLETED] invalid-customer and valid-customer tests
[COMPLETED] mandatory customer validation requirement
[CONFIRMED] standard Customer Order header IDO = SL.SLCos
[CONFIRMED] standard Customer Order line IDO = SL.SLCoitems
[REVIEWED] SL.SLCos method-name list
[CONFIRMED] CreateCoAndLines is Extension Class - Standard Method
[CONFIRMED] CoAndLineInfoJson = input-only
[CONFIRMED] CoResult = input/output + message parameter
[CONFIRMED] SLCos is the base collection
[CONFIRMED] SLCos_FT and ZIT_SLCos extend SLCos
[CONFIRMED] extension owner = Customer.SLCos, assembly Customer
[CONFIRMED] Customer assembly = Binary Only
[NEXT] confirm environment and disposable-test permission before runtime probing
[PENDING] custom Process/Reprocess method
[PENDING] controlled service IDO receive method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Confirm whether the current environment is DEV, TEST, UAT, or PRODUCTION.
- Confirm whether a disposable test Customer Order may be created.
- In non-production only, design one controlled malformed/minimal `CreateCoAndLines` invocation with pre/post verification.
- In production or where disposable creation is prohibited, request an official method contract/sample from Infor or the solution owner instead of runtime probing.
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
