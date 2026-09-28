# SMK069 Shipment Database Source Inventory

Updated: 2026-09-28

Purpose: ensure tenant Shipment runtime objects are preserved as exact standalone source-of-truth files in Git.

## Current inventory

| Tenant object | Runtime / tenant evidence | Standalone Git source |
|---|---|---|
| `dbo.SMK069_ShipmentAPI_mst` | Exact current UAT definition recaptured 2026-09-28. Uses prefixed string DN, POS UOM mapping, converted qty/price, and `Batch`/`Expiry_date` as NULL. | ✅ authoritative current UAT capture: `database/views/shipment/SMK069_ShipmentAPI_mst.sql`; PROD baseline artifact: `deployment/shipment/prod/baseline/010-create-SMK069_ShipmentAPI_mst.sql` |
| `dbo.SMK069BuildShipmentJsonSp` | Patch 11 tenant `sys.parameters` evidence says `@DN_No` is `nvarchar`; Patch 14 Rev.2 verified `DocNoNonBlocking=PASS` and `EmptyStringJson=PASS` | ⚠️ historical standalone source is stale; current tenant definition still needs recapture |
| `dbo.SMK069PrepareShipmentSendSp` | Patch 11 changed only `@DN_No` from `BIGINT` to `NVARCHAR(40)` while preserving the installed body | ⚠️ exact current tenant SQL source not yet captured as standalone file |
| `dbo.SMK069CompleteShipmentSendSp` | Exact pre-fix tenant source captured; root cause proven: local `@ShipmentId BIGINT` receives text DN such as `P96330`. Patch 15 maps outbound DN text back to standard numeric shipment key using current View contract | ✅ pre-fix capture: `SMK069CompleteShipmentSendSp.tenant-2026-09-09.sql`; ✅ fixed canonical source: `SMK069CompleteShipmentSendSp.sql`; apply patch: `2026-09-09-smk069-15-fix-complete-shipment-dn-string.sql` |
| `dbo.ue_SMK069_shipment_api_log_mst` | Runtime/UAT-used; `ShipmentId` stores prefixed outbound DN text in current queue/log flow | ⚠️ exact tenant DDL not yet captured as standalone file |
| `SMK069ShipmentTransportExtension` | Tenant runtime uses the string-DN/scheduler path | ⚠️ `extension-classes/shipment/SMK069ShipmentSenderExtension.cs` is legacy; `SMK069ShipmentSenderExtension.rev3.cs` is newer but still must be compared with tenant before being declared authoritative |

## Confirmed DN contract — 9 Sep

Current tenant Shipment View evidence:

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Therefore:

```text
P96330 = prefix P963 + shipment_mst.shipment_id 30
P96331 = prefix P963 + shipment_mst.shipment_id 31
P96332 = prefix P963 + shipment_mst.shipment_id 32
```

Do not interpret `P96330` as numeric key `96330`.

## Confirmed Complete root cause

Pre-fix tenant Complete source:

```sql
DECLARE @ShipmentId BIGINT;

SELECT
    @ShipmentId = ShipmentId
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef = @Site
  AND RowPointer = @LogRowPointer;
```

Current API-log ShipmentId is text such as `P96330`, so the assignment performs an invalid implicit `nvarchar -> bigint` conversion.

Patch 15 separates the two contracts:

```text
@ShipmentDn NVARCHAR(40) -> outbound DN such as P96330
@ShipmentId BIGINT       -> internal shipment_mst key such as 30
```

The numeric key is resolved against `shipment_mst` with the same P963/R975 + `shipment_id` expression used by the current tenant View. A numeric-only fallback remains for historical log rows.

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

CSV→CO may be consulted only for a real upstream dependency, not as a workaround for Shipment sender validation.

## Remaining incident gate

Patch 14 resolves the local missing-DOC_NO hard stop and Patch 15 resolves the Complete string-DN conversion. The remaining independent blocker before retry is:

```text
HTTP 404 page not found
```

Do not consume another retry attempt until the configured Shipment EndpointUrl is confirmed/corrected.

## Rule going forward

A tenant Shipment object must not be considered fully source-controlled until its exact current applied/runtime definition is preserved in Git.

Documentation/evidence is useful but does not replace executable SQL/DDL/source.

Preferred locations:

```text
database/views/shipment/SMK069_ShipmentAPI_mst.sql
database/procedures/shipment/SMK069BuildShipmentJsonSp.sql
database/procedures/shipment/SMK069PrepareShipmentSendSp.sql
database/procedures/shipment/SMK069CompleteShipmentSendSp.sql
database/tables/shipment/ue_SMK069_shipment_api_log_mst.sql
extension-classes/shipment/SMK069ShipmentSenderExtension.cs
```

Do not reconstruct missing tenant definitions from memory when the tenant definition can be exported directly.
