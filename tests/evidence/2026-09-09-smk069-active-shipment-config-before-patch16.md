# SMK069 active Shipment config before Patch 16

Date: 2026-09-09
Scope: Shipment Outbound SyteLine → POS API
Tenant UI: SMK Query Select Execution

## Tenant result

```text
SiteRef   ApiName   IsActive   SchedulerEnabled   LoginUrl                                                    EndpointUrl                                                   HttpMethod   ContentType        SuccessMode
Default   SHIPMENT  1          1                  https://api-uat.pizzahut.co.id/service-auth/login-once      https://api-uat.pizzahut.co.id/inventory/v1/infor_dn           POST         application/json   KACS_V1
```

## Incident correlation

P96330 and P96332 reached the HTTP transport and returned:

```text
HTTP 404
Response=404 page not found
```

Patch 14 Rev.2 is already PASS/PASS and Patch 15 is PASS/PASS/PASS, so the remaining shared pre-retry blocker is the route/config layer.

Repository evidence from `docs/shipment/28-shipment-infor-endpoint-and-uom.md` records that on 7 Sep POS/KACS provided two candidate Infor → POS routes:

```text
https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
```

and one of those routes produced business response `1010 data is exist`, proving it reached payload validation rather than a route-level 404.

Since the currently active `/inventory/v1/infor_dn` is now directly proven by queue evidence to return 404, Patch 16 changes the UAT endpoint to the remaining documented candidate `/inventory-phi/v1/infor_dn` and simultaneously sets `SchedulerEnabled=0` to hold automatic retries.

No HTTP call is executed by Patch 16 itself.
