# SMK069 Shipment Patch 15 — Complete prefixed-DN verification PASS

Date: 2026-09-09
Scope: Shipment Outbound SyteLine → POS API
Tenant UI: SMK Query Select Execution

## Verification result

Tenant Query Select returned:

```text
Patch15Marker               OldBigintAssignmentRemoved   StringDnPresent
PASS                        PASS                         PASS
```

Interpretation:

- installed `dbo.SMK069CompleteShipmentSendSp` contains marker `SMK069-COMPLETE-DN-STRING-R1`;
- the old direct assignment `@ShipmentId = ShipmentId`, which caused implicit `nvarchar -> bigint` conversion for values such as `P96330`, is no longer present;
- the installed Complete procedure now keeps the outbound prefixed DN in `@ShipmentDn` and resolves the numeric `shipment_mst.shipment_id` separately.

Current tenant DN evidence used by Patch 15:

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Therefore examples are:

```text
P96330 -> shipment_mst.shipment_id 30
P96331 -> shipment_mst.shipment_id 31
P96332 -> shipment_mst.shipment_id 32
```

The previous Complete failure is considered fixed at the stored-procedure level:

```text
Error converting data type nvarchar to bigint.
dbo.SMK069CompleteShipmentSendSp:36
```

## Remaining incident gate

Do not Reset Retry or Run Now yet. The independent HTTP route failure remains:

```text
HTTP 404
Response=404 page not found
```

Patch 14 Rev.2 and Patch 15 now leave the endpoint as the only known blocker before a controlled one-DN retry.

## Next action

Capture the active Shipment configuration from the tenant and verify the exact POS route before consuming another attempt.
