# SMK069 Shipment — P96331 STORE_ORDER_NO blocker evidence

Date: 2026-09-10
Scope: Shipment Outbound SyteLine -> POS API only

## Observed retry state

```text
SiteRef  ShipmentId  AttemptCount  RetryState  NextAttemptDate       LastAttemptDate       LastHttpCode  LastError
Default  P96331      1             P           2026-09-10 08:48 UTC  2026-09-10 08:33 UTC  0             STORE_ORDER_NO kosong.
Default  P96350      1             P           2026-09-10 08:48 UTC  2026-09-10 08:33 UTC  503           POS API HTTP error 503; Response=<html>...
```

Database clock was verified as UTC:

```text
DbNow    = 2026-09-10 09:23
UtcNow   = 2026-09-10 09:23
WIB      = 2026-09-10 16:23
```

Therefore the 08:33 attempt corresponds to approximately 15:33 WIB.

## Current base Shipment state

```text
site_ref  shipment_id  whse  SMK069_Uf_api_post  SMK069_Uf_api_post_date
Default   31           PLG   0
Default   50           PLG   0
```

Both shipments remain unposted in shipment_mst.

## Current tenant Build evidence

Query Select captured the exact guard context:

```sql
IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreOrderNo, ''))), '') IS NULL
BEGIN
    SET @Infobar = 'STORE_ORDER_NO kosong.';
    RETURN 0;
END;
```

This proves P96331 passed the already-fixed missing DOC_NO gate and then stopped at a separate STORE_ORDER_NO local validation.

## Interpretation

```text
P96331
  -> local Build/Prepare failure
  -> HTTP was never attempted
  -> LastHttpCode = 0

P96350
  -> HTTP was attempted
  -> endpoint returned nginx 503 Service Temporarily Unavailable
```

The new `/inventory-phi/v1/infor_dn` route is no longer returning the earlier route-level 404, but upstream service availability remains unresolved.

## Queue/source discrepancy

A direct query against `dbo.SMK069_ShipmentSchedulerQueue_vw` for P96331/P96350 returned no rows, and a direct current `dbo.SMK069_ShipmentAPI_mst` query for those DNs also returned no rows even though the base shipment_mst records still exist.

Do not infer the cause yet. This may be due to current View joins/filtering or form cache/runtime drift and should be audited separately if the form still displays those DNs after a real collection refresh.

## Action

Patch 20 changes only the current installed `dbo.SMK069BuildShipmentJsonSp`:

```text
STORE_ORDER_NO blank
  -> no local RETURN
  -> JSON normalizes to "STORE_ORDER_NO":""
  -> POS becomes final authority
```

Patch file:

```text
database/patches/shipment/2026-09-10-smk069-20-allow-missing-store-order-no.sql
```
