# SMK069 Shipment Database Source Inventory

Updated: 2026-09-09

Purpose: ensure tenant Shipment runtime objects are preserved as exact standalone source-of-truth files in Git.

## Current inventory

| Tenant object | Runtime / tenant evidence | Standalone Git source |
|---|---|---|
| `dbo.SMK069_ShipmentAPI_mst` | Runtime now emits prefixed string DN values such as `P96330` | ⚠️ **STALE** — `database/views/shipment/SMK069_ShipmentAPI_mst.sql` was captured on 2026-09-04 and still shows `sh.shipment_id AS DN_No`; recapture exact tenant definition |
| `dbo.SMK069BuildShipmentJsonSp` | Patch 11 tenant `sys.parameters` evidence on 2026-09-09 says `@DN_No` is `nvarchar`; Patch 14 Rev.2 verified `DocNoNonBlocking=PASS` and `EmptyStringJson=PASS` | ⚠️ **STALE** standalone source — `database/procedures/shipment/SMK069BuildShipmentJsonSp.sql` was captured on 2026-09-04 and still declares `@DN_No BIGINT`; current tenant definition still needs recapture |
| `dbo.SMK069PrepareShipmentSendSp` | Patch 11 changed only `@DN_No` from `BIGINT` to `NVARCHAR(40)` while preserving the installed body | ⚠️ exact current tenant SQL source not yet captured as standalone file |
| `dbo.SMK069CompleteShipmentSendSp` | Exact tenant source captured 2026-09-09; root cause proven: local `@ShipmentId BIGINT` receives text `ShipmentId` such as `P96330` from API log | ✅ pre-fix tenant source captured at `database/procedures/shipment/SMK069CompleteShipmentSendSp.tenant-2026-09-09.sql`; Patch 15 pending mapping verification |
| `dbo.ue_SMK069_shipment_api_log_mst` | Runtime/UAT-used; `ShipmentId` stores prefixed outbound DN text in current queue/log flow | ⚠️ exact tenant DDL not yet captured as standalone file |
| `SMK069ShipmentTransportExtension` | Tenant runtime has progressed past the 4 Sep source and uses the string-DN/scheduler path | ⚠️ `extension-classes/shipment/SMK069ShipmentSenderExtension.cs` is legacy; `SMK069ShipmentSenderExtension.rev3.cs` is a newer candidate but explicitly is not guaranteed to equal the latest tenant source |

## 9 Sep root-cause audit

Use the read-only audit before any retry or Complete patch:

```text
database/patches/shipment/2026-09-09-smk069-13-shipment-root-cause-audit.sql
```

Confirmed Complete root cause from tenant source:

```sql
DECLARE @ShipmentId BIGINT;

SELECT
    @ShipmentId = ShipmentId
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef = @Site
  AND RowPointer = @LogRowPointer;
```

Current queue/log DN values are text such as:

```text
P96330
P96331
P96332
```

Therefore the assignment above attempts an implicit `nvarchar -> bigint` conversion before Complete can update the API log / Shipment state.

The remaining Patch 15 gate is to verify exactly how the current tenant Shipment View maps prefixed outbound `DN_No` back to the numeric standard `shipment_mst.shipment_id`. Do not assume that stripping the `P` prefix is correct until the current tenant View definition confirms it.

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

If KACS/POS rejects Shipment field values, the correction must be made in the Shipment view/source mapping (or a Shipment-specific mapping explicitly designed for it), not by reusing the inbound CO mapping view.

CSV→CO may be consulted only for a real upstream dependency, not as a workaround for the Shipment sender's DOC_NO validation.

## Rule going forward

A tenant Shipment object must not be considered fully source-controlled until its **exact current applied/runtime definition** is preserved in Git.

Documentation/evidence describing behavior is useful but does not replace the executable SQL/DDL/source.

When the current tenant definitions are captured, preserve them under the Shipment workstream, for example:

```text
database/views/shipment/SMK069_ShipmentAPI_mst.sql
database/procedures/shipment/SMK069BuildShipmentJsonSp.sql
database/procedures/shipment/SMK069PrepareShipmentSendSp.sql
database/procedures/shipment/SMK069CompleteShipmentSendSp.sql
database/tables/shipment/ue_SMK069_shipment_api_log_mst.sql
extension-classes/shipment/SMK069ShipmentSenderExtension.cs
```

Do not reconstruct missing tenant definitions from memory when the tenant definition can be exported directly.
