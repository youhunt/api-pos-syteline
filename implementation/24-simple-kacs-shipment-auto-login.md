# SMK069 Simple KACS Shipment Sender

Date: 2026-09-04

## Decision

Keep Shipment outbound simple.

```text
DN_No
-> SMK069PrepareShipmentSendSp / SMK069BuildShipmentJsonSp
-> Shipment JSON payload only
-> login KACS
-> receive access token
-> POST Shipment JSON with Authorization: Bearer <token>
-> receive KACS response
-> SMK069CompleteShipmentSendSp
```

The KACS endpoint, login endpoint, Authorization header and token are transport concerns. They must never be inserted into the Shipment business JSON.

## KACS endpoints in extension source

The non-secret UAT/production URLs are resolved internally from `ApiEnvironment`:

```text
UAT:
https://api-uat.pizzahut.co.id/service-auth/login-once
https://api-uat.pizzahut.co.id/inventory-phi/v1/kacs_dn

PROD:
https://api-prod.pizzahut.co.id/service-auth/login-once
https://api-prod.pizzahut.co.id/inventory-phi/v1/kacs_dn
```

No credential or token is committed to Git.

## New extension method

```text
SMK069SendOneShipmentKacs
```

Input order:

```text
1  DN_No
2  ApiEnvironment       UAT / PROD
3  Username
4  Password
5  TimeoutSeconds
```

Output order:

```text
6  LogRowPointer
7  PayloadJson
8  LoginHttpCode
9  HttpCode
10 ResponseJson
11 TransportSuccess
12 BusinessSuccess
13 ErrorMessage
14 Success
15 Infobar
```

The access token is deliberately not returned and is not logged.

The method must be NON-TRANSACTIONAL because it calls an external API.

## UAT REST invoke

```text
POST {{ido_base}}/invoke/ue_SMK069ShipmentTransport?method=SMK069SendOneShipmentKacs
```

Body is the Mongoose IDO method parameter array, not the KACS Shipment payload:

```json
[
  22,
  "UAT",
  "<KACS_USERNAME>",
  "<KACS_PASSWORD>",
  60,
  null,
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

The actual outbound KACS Shipment body remains only the JSON produced by `SMK069BuildShipmentJsonSp`, for example:

```json
{
  "CUST_CODE": "...",
  "WHS_CODE": "...",
  "DOC_NO": "...",
  "DN_NO": "...",
  "DELIVERY_DATE": "...",
  "STORE_ORDER_NO": "...",
  "STORE_CODE": "...",
  "VEHICLE_NUMBER": "...",
  "DETAIL": []
}
```

## Success rule

Shipment is successful only when KACS returns:

```text
HTTP 201
code = 200
message = Success
```

Only then may Complete set `SMK069_Uf_api_post = 1`.

All other responses remain failure and keep the Shipment pending.

## Security

- do not commit username/password/token;
- do not return the access token from the method;
- do not store login response tokens in the outbound log;
- production scheduler credentials must come from secure runtime configuration rather than source code.
