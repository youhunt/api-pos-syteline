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
