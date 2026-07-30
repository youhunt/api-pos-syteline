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
- `implementation/15-idomethodparameters-metadata-fallback.md` documenting metadata-route discovery and REST v1 fallbacks.
- `tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md` recording the generic HTTP 500 response.
- `tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md` confirming published parameter metadata properties.
- `tests/evidence/2026-07-30-create-co-and-lines-parameter-directions.md` confirming `InputFlag`, `OutputFlag`, and `MessageFlag`.
- `tests/evidence/2026-07-30-idomethods-idoinfo-properties.md` confirming published method-level metadata properties.
- `tests/evidence/2026-07-30-create-co-and-lines-method-row.md` recording effective method contexts for `SLCos`, `SLCos_FT`, and `ZIT_SLCos`.
- `tests/evidence/2026-07-30-idocollections-idoinfo-properties.md` confirming collection-level extension and inheritance metadata properties.

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
- Confirmed that `IdoMethods` exposes `MethodDesc`, `MethodType`, `TxnFlag`, `StoredProcName`, `BaseCollectionName`, `DerOutriggerProfile`, `DerSpMethodsAllowed`, `MethodParameters`, and `MethodResultSets`.
- Confirmed that published `IdoMethods` metadata does not directly expose an extension class, assembly, source code, help URL, or JSON-schema field.
- Completed the filtered `IdoMethods` load for `SLCos / CreateCoAndLines`.
- Recorded three effective base contexts returned for the same `_ItemId`:

```text
SLCos
SLCos_FT
ZIT_SLCos
```

- Recorded that `MethodDesc`, `StoredProcName`, and `DerOutriggerProfile` are NULL for all returned method rows.
- Confirmed that `IdoCollections` exposes the following implementation and hierarchy properties:

```text
Extends
ExtClassName
ExtClassNamespace
CustomAssemblyName
ServerName
AccessAs
OutriggerProfile
DerServerPlusCollection
```

- Kept the supported Customer Order creation sequence unconfirmed until the collection hierarchy, exact JSON schema, and runtime result behavior are verified.
- Advanced the next step to a read-only metadata load for `SLCos`, `SLCos_FT`, and `ZIT_SLCos`.

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
[CONFIRMED] effective contexts = SLCos, SLCos_FT, ZIT_SLCos
[CONFIRMED] IdoCollections extension/inheritance metadata properties
[NEXT] load collection rows for SLCos, SLCos_FT, and ZIT_SLCos
[PENDING] custom Process/Reprocess method
[PENDING] controlled service IDO receive method
[PENDING] final external POS REST API contract
[PENDING] Customer Order header and line creation
```

### Planned

- Load read-only `IdoCollections` rows for `SLCos`, `SLCos_FT`, and `ZIT_SLCos`.
- Confirm the actual `Extends` chain and extension class, namespace, assembly, server project, access-as, outrigger, and server-plus metadata.
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