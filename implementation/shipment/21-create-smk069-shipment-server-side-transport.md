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
`SMK069Shipment.SMK069ShipmentTransportExtension`:

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


---

## 10. Tenant metadata confirmed — 3 Sep 2026

Runtime Query Execution confirmed:

```text
SMK069BuildShipmentJsonSp
  @DN_No bigint IN
  @PayloadJson nvarchar(max) OUT
  @Success int OUT
  @Infobar nvarchar(4000) OUT

SMK069PrepareShipmentSendSp
  @DN_No bigint IN
  @EndpointUrl nvarchar(1000) IN
  @LogRowPointer uniqueidentifier OUT
  @PayloadJson nvarchar(max) OUT
  @Success int OUT
  @Infobar nvarchar(4000) OUT

SMK069CompleteShipmentSendSp
  @LogRowPointer uniqueidentifier IN
  @HttpCode int IN
  @ResponseJson nvarchar(max) IN
  @IsSuccess int IN
  @Success int OUT
  @Infobar nvarchar(4000) OUT
```

The Shipment API view also returned:

```text
ShipmentViewSiteRefCheck = PASS
```

DN22 remains pending at Site `Default` and contains four independent lot rows:

```text
12  260812-002-1B-0
6   260812-003-1B-0
3   260813-008-2A-0
9   260814-015-1C-0
```

No lot aggregation is introduced.

## 11. One-Shipment orchestration implemented

The extension class now also exposes:

```text
SMK069SendOneShipment
```

Flow:

```text
SMK069PrepareShipmentSendSp
        |
        | returns LogRowPointer + PayloadJson
        v
SMK069PostShipmentPayload
        |
        | returns HttpCode + BusinessSuccess
        v
SMK069CompleteShipmentSendSp
```

Important behavior:

- Prepare is called only once; Build is not called separately because Prepare
  already delegates payload construction to the stable Build procedure.
- HTTP/business failures are handled attempts. Complete is still called with
  `IsSuccess=0`, allowing the log to become `E` while Shipment remains pending.
- POS-confirmed success is passed to Complete as `IsSuccess=1`; only Complete
  may set `shipment_mst.SMK069_Uf_api_post=1`.
- if Complete itself fails after the HTTP attempt, the IDO method returns 16 and
  explicitly tells operations to inspect the outbound log before retrying.
- the method must be configured as **non-transactional**; an external HTTP call
  must not sit inside one database transaction.

### IDO method parameters

Create the extension-class method with this exact parameter order:

| Seq | Name | Direction | Type |
|---:|---|---|---|
| 1 | DN_No | Input | Int64 |
| 2 | EndpointUrl | Input | String |
| 3 | AuthHeaderName | Input | String |
| 4 | AuthHeaderValue | Input | String |
| 5 | SuccessMode | Input | String |
| 6 | SuccessMarker | Input | String |
| 7 | TimeoutSeconds | Input | Int32 |
| 8 | LogRowPointer | Output | String |
| 9 | PayloadJson | Output | String |
| 10 | HttpCode | Output | Int32 |
| 11 | ResponseJson | Output | String |
| 12 | TransportSuccess | Output | Int32 |
| 13 | BusinessSuccess | Output | Int32 |
| 14 | ErrorMessage | Output | String |
| 15 | Success | Output | Int32 |
| 16 | Infobar | Output | String |

### Safe negative UAT before the real endpoint is known

DN22 can be used with an intentionally invalid/unreachable UAT URL to prove the
failure path:

```text
SuccessMode = UNCONFIRMED
Expected:
  Prepare creates/returns log
  TransportSuccess = 0
  BusinessSuccess = 0
  Complete returns success for the bookkeeping operation
  Shipment Success = 0
  outbound log = E
  shipment api_post remains 0
```

Do **not** repeatedly use a URL that could accidentally resolve to a real
third-party service. Prefer the POS UAT endpoint when available.

### Positive UAT gate

Do not run a positive POST that can mark DN22 posted until all are known:

```text
POS UAT endpoint
authentication/header
example accepted response
example business-error response
duplicate DN behavior
confirmed SuccessMode / marker
```

The next implementation after one-Shipment UAT is the current-Site pending batch
orchestrator, followed by TaskMan hourly scheduling.
