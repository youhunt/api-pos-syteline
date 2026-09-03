# 21 — SMK069 Shipment Server-Side HTTP Transport Foundation

> Date: 3 September 2026  
> Source of truth: `docs/24-smk069-current-handoff-2026-09-03.md`  
> Status: implementation foundation committed; tenant wiring/UAT still required.

## 1. Why this step exists

Shipment SQL is already stable enough for the data lifecycle:

```text
Build JSON
-> Prepare outbound log
-> HTTP POST
-> Complete result
```

The missing production layer is the server-side HTTP transport and scheduler.

The POS Shipment endpoint, authentication, and exact business-success response
are still open. Therefore the transport must be usable for UAT without
accidentally marking a Shipment posted.

## 2. New extension class

Source:

```text
extension-classes/SMK069ShipmentSenderExtension.cs
```

Extension IDO name used by the class:

```text
ue_SMK069ShipmentTransport
```

Public method:

```text
SMK069PostShipmentPayload
```

The method only performs the HTTP POST and evaluates the response. It does not
directly update `shipment_mst` or the outbound log.

This separation is intentional. The final one-Shipment orchestration remains:

```text
SMK069PrepareShipmentSendSp
-> SMK069PostShipmentPayload
-> SMK069CompleteShipmentSendSp
```

## 3. Method contract

Input:

| Parameter | Meaning |
|---|---|
| EndpointUrl | POS Shipment endpoint, supplied at runtime/configuration |
| RequestJson | JSON returned by Shipment Prepare/Build |
| AuthHeaderName | Optional header, for example Authorization or X-API-Key |
| AuthHeaderValue | Runtime secret/value; never commit real credentials |
| SuccessMode | UNCONFIRMED, MARKER, or HTTP_2XX |
| SuccessMarker | Required only for MARKER |
| TimeoutSeconds | Default 60; maximum 300 |

Output:

| Parameter | Meaning |
|---|---|
| HttpCode | HTTP status when a server response exists |
| ResponseJson | POS response body, capped at 1 MiB |
| TransportSuccess | 1 when an HTTP response was received; 0 on connection/transport failure |
| BusinessSuccess | 1 only when the configured success rule is satisfied |
| ErrorMessage | Transport/business failure detail |
| Infobar | Human-readable summary without credential values |

## 4. Conservative success behavior

Default/blank `SuccessMode` becomes:

```text
UNCONFIRMED
```

In that mode:

```text
HTTP 200/201/etc.
!=
confirmed POS business success
```

Therefore:

```text
BusinessSuccess = 0
```

until the POS response contract is confirmed.

Supported modes:

### UNCONFIRMED

Use now for connectivity/UAT. A 2xx response is captured but not accepted as a
business success.

### MARKER

Requires both:

1. HTTP 2xx; and
2. `SuccessMarker` exists in the response body.

Use only after the POS team provides a stable success marker.

### HTTP_2XX

Treats any HTTP 2xx response as business success.

Do not use this in production until the POS team explicitly confirms that a 2xx
status alone means the Shipment is accepted successfully.

## 5. Authentication

The source contains no real credentials.

Examples of runtime values:

```text
AuthHeaderName  = Authorization
AuthHeaderValue = Bearer <runtime secret>
```

or:

```text
AuthHeaderName  = X-API-Key
AuthHeaderValue = <runtime secret>
```

Do not put username/password/token into:

- Git;
- SQL source;
- the endpoint URL;
- test payload files.

## 6. Tenant setup

Create or use an IDO named:

```text
ue_SMK069ShipmentTransport
```

Import the compiled extension assembly and attach
`SMK069Shipment.SM K069ShipmentTransportExtension` with the whitespace removed
from the class name:

```text
SMK069Shipment.SMK069ShipmentTransportExtension
```

Add a hand-coded IDO method whose name exactly matches:

```text
SMK069PostShipmentPayload
```

The method should not be marked transactional because it performs an external
HTTP call.

## 7. First safe UAT

Before wiring Prepare/Complete, use the current DN22 preview payload:

```text
tests/payloads/shipment-dn22-current-preview.json
```

Use:

```text
SuccessMode = UNCONFIRMED
```

Expected for a reachable endpoint returning HTTP 2xx:

```text
TransportSuccess = 1
BusinessSuccess  = 0
HttpCode         = actual 2xx code
ResponseJson     = actual POS body
ErrorMessage     = response contract not confirmed
```

This proves server-side connectivity without changing Shipment posted status.

## 8. Runtime audit before orchestration

Run:

```text
database/patches/2026-09-03-smk069-shipment-production-readiness-audit.sql
```

The audit is read-only and returns:

- active Site from `CONTEXT_INFO`;
- Site-context status for Build/Prepare/Complete;
- exact parameter metadata for the three Shipment SPs;
- Shipment view columns and `site_ref` check;
- outbound log columns;
- current-site pending Shipment snapshot;
- suspicious duplicate N/S log attempts for the logical key `SiteRef + ShipmentId`.

The exact parameter result is required before coding the final orchestration so
the existing stable SP signatures are not guessed or changed.

## 9. Next code step

After the runtime audit and POS endpoint/response sample are available:

1. add one-Shipment orchestration method;
2. invoke Prepare;
3. call this HTTP transport;
4. invoke Complete with `BusinessSuccess`;
5. confirm failure leaves `api_post=0`;
6. confirm success sets `api_post=1`;
7. add pending-batch orchestration;
8. schedule the batch IDO method through TaskMan, default every 1 hour.

The form remains UAT/debug only.
