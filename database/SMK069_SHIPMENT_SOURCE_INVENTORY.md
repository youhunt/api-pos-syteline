# SMK069 Shipment Database Source Inventory

Updated: 2026-09-04

Purpose: ensure tenant Shipment runtime objects are also preserved as standalone source-of-truth files in Git.

| Tenant object | Runtime status | Standalone Git source |
|---|---|---|
| `dbo.SMK069_ShipmentAPI_mst` | Implemented / UAT-used | ✅ `database/views/SMK069_ShipmentAPI_mst.sql` captured from tenant on 2026-09-04 |
| `dbo.SMK069BuildShipmentJsonSp` | Implemented / UAT-used | ✅ `database/procedures/SMK069BuildShipmentJsonSp.sql` captured from tenant on 2026-09-04 |
| `dbo.SMK069PrepareShipmentSendSp` | Implemented / UAT-used | ⚠️ exact tenant SQL source not yet captured as standalone file |
| `dbo.SMK069CompleteShipmentSendSp` | Implemented / UAT-used | ⚠️ exact tenant SQL source not yet captured as standalone file |
| `dbo.ue_SMK069_shipment_api_log_mst` | Implemented / UAT-used | ⚠️ exact tenant DDL not yet captured as standalone file |
| `SMK069ShipmentSenderExtension.cs` | Implemented / UAT-used | ✅ `extension-classes/SMK069ShipmentSenderExtension.cs` |

## Shipment source boundary

Shipment outbound and POS inbound Customer Order are separate mapping domains.

Shipment outbound business source is:

```text
dbo.SMK069_ShipmentAPI_mst
```

`dbo.SMK069BuildShipmentJsonSp` consumes that Shipment view.

Do **not** use the POS inbound Customer Order mapping view below as a Shipment source or reverse mapping source:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

That view belongs only to the POS inbound -> Customer Order flow.

If KACS rejects Shipment field values, the correction must be made in the Shipment view/source mapping (or a Shipment-specific mapping explicitly designed for it), not by reusing the inbound CO mapping view.

## Rule going forward

A tenant Shipment object must not be considered fully source-controlled until its exact applied/runtime definition is preserved in Git.

Documentation/evidence describing behavior is useful but does not replace the executable SQL/DDL source.

When the remaining exact tenant definitions are captured, store them under:

```text
database/procedures/SMK069PrepareShipmentSendSp.sql
database/procedures/SMK069CompleteShipmentSendSp.sql
database/tables/ue_SMK069_shipment_api_log_mst.sql
```

Do not reconstruct these three from memory if the tenant definition can be exported directly.
