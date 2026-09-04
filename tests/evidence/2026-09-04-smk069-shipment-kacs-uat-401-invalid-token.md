# SMK069 Shipment KACS UAT — HTTP 401 Invalid Token

Date: 2026-09-04

## Invocation

Server-side IDO method:

```text
ue_SMK069ShipmentTransport.SMK069SendOneShipment
```

Target endpoint:

```text
https://api-uat.pizzahut.co.id/inventory-phi/v1/kacs_dn
```

Success mode:

```text
KACS_V1
```

The actual bearer token is intentionally not recorded in Git.

## Tenant result

The request reached KACS and returned:

```text
HttpCode         = 401
ResponseJson     = {"message":"Invalid token"}
TransportSuccess = 1
BusinessSuccess  = 0
Success          = 0
```

A new outbound log RowPointer was returned and Complete recorded the failed
attempt. This proves the server-side HTTP transport can reach the KACS UAT host.

The Shipment payload remained lot-level and contained the four DN22 lot rows.

## Interpretation

This is an authentication failure, not a DNS/network failure and not yet a
Shipment payload-validation result. The next UAT must use a fresh access token
obtained from the documented KACS `/service-auth/login-once` endpoint.

Do not commit login credentials or access/refresh tokens.

## Wrapper observation

The tenant response returned method ReturnValue 16 because the prior wrapper
interpreted Complete output `Success=0` as a technical Complete failure. Tenant
database evidence already proved the failed attempt was correctly persisted as
log `E` with retry incremented.

The source is being corrected so a failed HTTP/business attempt that Complete
successfully persists is returned as a handled method result (`ReturnValue=0`,
while business output `Success=0`). A positive KACS result still requires both
`BusinessSuccess=1` and Complete success before returning Shipment success.
