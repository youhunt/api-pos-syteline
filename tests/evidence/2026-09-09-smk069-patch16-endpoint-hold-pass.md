# SMK069 Shipment Patch 16 — Endpoint + scheduler hold verification PASS

Date: 2026-09-09
Scope: Shipment Outbound SyteLine → POS API
Tenant UI: SMK Query Select Execution

## Tenant verification result

```text
SiteRef             Default
ApiName             SHIPMENT
IsActive            1
SchedulerEnabled    0
LoginUrl            https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl         https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
HttpMethod          POST
ContentType         application/json
SuccessMode         KACS_V1
```

Interpretation:

- Patch 16 changed the UAT Shipment endpoint from `/inventory/v1/infor_dn` to the evidence-backed remaining candidate `/inventory-phi/v1/infor_dn`;
- scheduler master is held OFF (`SchedulerEnabled = 0`) so the queue cannot consume additional attempts automatically during controlled UAT preparation;
- LoginUrl, HTTP method, content type and success mode remain unchanged.

## Current incident status

```text
P96331 missing DOC_NO local Build gate  FIXED + VERIFIED by Patch 14 Rev.2
Complete nvarchar -> bigint             FIXED + VERIFIED by Patch 15
Old /inventory/v1/infor_dn route        REPLACED by Patch 16
Scheduler automatic sending             HELD OFF for controlled one-DN UAT
```

## Next UAT gate

Before enabling automatic scheduling:

1. keep master OFF while preparing the control-center values;
2. set the selected schedule `MaxShipments = 1`;
3. reset exactly one DN only (P96331 candidate);
4. perform one controlled run through the secured background sender;
5. verify HTTP response, Complete result, API log, retry state and `shipment_mst.SMK069_Uf_api_post`;
6. if the result is still route-level 404, stop and do not consume P96330/P96332;
7. only after one-DN evidence is clean should normal scheduling be re-enabled.
