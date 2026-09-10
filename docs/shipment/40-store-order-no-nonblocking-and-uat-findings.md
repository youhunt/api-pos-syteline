# Shipment — STORE_ORDER_NO non-blocking and UAT findings

Date: 2026-09-10
Scope: Shipment Outbound SyteLine -> POS API only

## Current findings

Controlled manual UAT showed two distinct outcomes at approximately 15:33 WIB (server/database clock is UTC):

```text
P96331 -> Attempt 1 -> HTTP 0   -> STORE_ORDER_NO kosong.
P96350 -> Attempt 1 -> HTTP 503 -> nginx Service Temporarily Unavailable
```

Interpretation:

- P96331 did not reach the POS API. It passed the already-fixed DOC_NO gate and then stopped at a separate local Build validation for STORE_ORDER_NO.
- P96350 did reach the configured `/inventory-phi/v1/infor_dn` route and received HTTP 503 from nginx. This is no longer the previous route-level 404; upstream/service availability is now the external blocker for that attempt.

## Tenant source proof

Current installed `dbo.SMK069BuildShipmentJsonSp` contains:

```sql
IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreOrderNo, ''))), '') IS NULL
BEGIN
    SET @Infobar = 'STORE_ORDER_NO kosong.';
    RETURN 0;
END;
```

## Patch 20

`database/patches/shipment/2026-09-10-smk069-20-allow-missing-store-order-no.sql`

Business behavior after Patch 20:

```text
STORE_ORDER_NO blank
  -> Build continues
  -> JSON contains "STORE_ORDER_NO":""
  -> POS API is final authority
```

Safety:

- tenant Build definition is preserved through `OBJECT_DEFINITION`;
- Patch 14 Rev.2 DOC_NO marker is required;
- string DN contract is required;
- Shipment View is not changed;
- no retry reset;
- no TaskMan submit;
- no HTTP call.

## Queue/source discrepancy

Direct queries for P96331/P96350 against `SMK069_ShipmentSchedulerQueue_vw` and `SMK069_ShipmentAPI_mst` returned no rows, while `shipment_mst` still contains shipment_id 31 and 50 with `SMK069_Uf_api_post=0`.

Do not assume the cause. If the form still shows those DNs after a real `object3` refresh, audit the current tenant `SMK069_ShipmentAPI_mst` joins/filtering and the installed queue view before changing code.

## Next controlled test

1. Apply Patch 20.
2. Verify marker + empty-string JSON projection.
3. Do not reset/retry all DNs.
4. Inspect the current source View and queue eligibility before choosing the next one-DN UAT candidate.
5. If a selected candidate reaches HTTP and returns 503 again, treat that as external POS/API service availability rather than a local Build validation failure.
