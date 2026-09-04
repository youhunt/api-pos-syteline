# Configure SMK069 Shipment -> KACS Mapping

Date: 2026-09-04

## Scope

This mapping belongs only to Shipment outbound:

```text
SyteLine Shipment
-> dbo.SMK069_ShipmentAPI_mst
-> dbo.SMK069BuildShipmentJsonSp
-> KACS Shipment API
```

Do not reuse `dbo.ue_SMK069_pos_sales_inbound_mapping_view`; that belongs to POS inbound -> Customer Order.

## Why this change exists

KACS sample Shipment payload uses external KACS codes and a numeric UOM, for example:

```json
{
  "CUST_CODE": "S060",
  "WHS_CODE": "R950",
  "STORE_CODE": "R919",
  "DETAIL": [
    {
      "UOM": 1
    }
  ]
}
```

The previous DN22 payload was generated directly from SyteLine values:

```text
CUST_CODE  = C000001
WHS_CODE   = PLG
STORE_CODE = blank
UOM        = CTN
```

The KACS sample values are examples only. They are not hardcoded into the integration.

## New Shipment-specific mapping tables

```text
dbo.ue_SMK069_shipment_customer_map_mst
  SiteRef + SytelineCustNum -> KacsCustCode + KacsStoreCode

dbo.ue_SMK069_shipment_whse_map_mst
  SiteRef + SytelineWhse -> KacsWhsCode

dbo.ue_SMK069_shipment_uom_map_mst
  SiteRef + SytelineUom -> KacsUom (INT)
```

`dbo.SMK069_ShipmentAPI_mst` now consumes these mappings. Missing mappings return NULL and `SMK069BuildShipmentJsonSp` rejects the Shipment before HTTP send.

## Apply

Use **Apply Database** for:

```text
database/patches/2026-09-04-smk069-shipment-kacs-payload-mapping-v1.sql
```

The patch creates the mapping tables, updates the Shipment view, and updates the JSON builder.

## Populate real mapping values

The current DN22 SyteLine source values are:

```text
customer = C000001
warehouse = PLG
U/M = CTN
```

Populate their actual KACS values after confirmation from the business/KACS master data.

Example template only — replace all `<...>` values before execution:

```sql
DECLARE @Site NVARCHAR(8) = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));

INSERT INTO dbo.ue_SMK069_shipment_customer_map_mst
(
    SiteRef,
    SytelineCustNum,
    KacsCustCode,
    KacsStoreCode
)
VALUES
(
    @Site,
    N'C000001',
    N'<REAL_KACS_CUST_CODE>',
    N'<REAL_KACS_STORE_CODE>'
);

INSERT INTO dbo.ue_SMK069_shipment_whse_map_mst
(
    SiteRef,
    SytelineWhse,
    KacsWhsCode
)
VALUES
(
    @Site,
    N'PLG',
    N'<REAL_KACS_WHS_CODE>'
);

INSERT INTO dbo.ue_SMK069_shipment_uom_map_mst
(
    SiteRef,
    SytelineUom,
    KacsUom
)
VALUES
(
    @Site,
    N'CTN',
    <REAL_KACS_UOM_INTEGER>
);
```

Do not paste this template unchanged into production.

## Verify

Run in **SMK Query Select Execution / Query Execution**:

```text
database/patches/2026-09-04-smk069-shipment-kacs-mapping-query-execution.sql
```

Expected builder characteristics after real mappings are configured:

- `CUST_CODE` = mapped KACS customer code;
- `WHS_CODE` = mapped KACS warehouse code;
- `STORE_CODE` = mapped KACS store code and not blank;
- `UOM` = JSON number, not SyteLine string;
- batch/lot rows remain separate;
- `DN_NO`, `DOC_NO`, delivery date, store order no, vehicle, item, quantity, price, batch and expiry remain sourced from Shipment/CO data as before.

## Important non-assumptions

The integration does not automatically convert:

```text
C000001 -> S060
PLG     -> R950
CTN     -> 1
```

unless those are confirmed to be the real tenant mappings. The values in the KACS document are sample values, not proof of DN22 business mapping.
