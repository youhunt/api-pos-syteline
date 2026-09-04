# 23 — KACS Positive Shipment UAT via Mongoose REST Invoke

Date: 2026-09-04

## 1. Current gate

Negative DN22 UAT passed and the first request to the real KACS UAT host reached
the server but returned:

```text
HTTP 401
{"message":"Invalid token"}
```

Therefore network/server-side transport is proven. The next gate is a fresh KACS
access token.

## 2. Rebuild corrected Shipment extension first

The latest `extension-classes/SMK069ShipmentSenderExtension.cs` corrects method
return semantics:

- failed HTTP/business result successfully persisted by Complete =>
  `ReturnValue=0`, business `Success=0`;
- positive KACS result is success only when both KACS business success and
  Complete success are true;
- HTTP connection/DNS WebExceptions are classified as transport failures.

Rebuild tenant assembly:

```text
ue_SMK069ShipmentExtensions
```

Expected:

```text
Assembly compiled and updated successfully.
```

Then discard IDO cache / refresh session if required.

## 3. Obtain a fresh KACS UAT token

Endpoint documented by KACS:

```text
POST https://api-uat.pizzahut.co.id/service-auth/login-once
Content-Type: application/json
```

Body shape:

```json
{
  "username": "<KACS UAT username>",
  "password": "<KACS UAT password>"
}
```

Use the credentials from the supplied KACS document/runtime secret store. Do not
commit credentials to Git.

Successful login returns `data.token` and `data.refresh_token`. Use the current
`data.token` as the Shipment bearer token.

## 4. Invoke one Shipment

Mongoose REST pattern confirmed in this tenant:

```text
POST {{ido_base}}/invoke/ue_SMK069ShipmentTransport?method=SMK069SendOneShipment
```

Body:

```json
[
  22,
  "https://api-uat.pizzahut.co.id/inventory-phi/v1/kacs_dn",
  "Authorization",
  "Bearer <FRESH_DATA_TOKEN>",
  "KACS_V1",
  "",
  60,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null
]
```

Do not paste the real token into Git or evidence files.

## 5. KACS_V1 success contract

Shipment is considered successful only when:

```text
HTTP status      = 201
response.code    = 200
response.message = Success
```

Expected IDO outputs:

```text
HttpCode         = 201
TransportSuccess = 1
BusinessSuccess  = 1
Success          = 1
ReturnValue      = 0
```

Expected database state:

```text
outbound log ProcessStatus = S
shipment Api_post          = 1
shipment Api_post_date     = populated
```

## 6. Payload observation before final production enablement

The 401 UAT attempt returned the DN22 payload with:

```text
WHS_CODE   = PLG
STORE_CODE = blank
UOM        = CTN
DN_NO      = 22
```

The KACS document provides examples with nonblank KACS-style store/warehouse
codes and numeric UOM, but does not by itself prove the exact mapping required
for this tenant data. Because HTTP 401 happens before payload acceptance, the
current run does not validate these business mappings.

After using a valid token, treat any 4xx response as the next contract/mapping
gate and do not mark the Shipment posted unless `KACS_V1` success is satisfied.
