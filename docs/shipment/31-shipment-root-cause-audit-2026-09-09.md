# 31 — Shipment root-cause audit: HTTP 404 + Complete nvarchar→bigint

> Date: 9 September 2026  
> Scope: **Shipment Outbound SyteLine → POS API only**  
> Status: investigation gate — **do not retry yet**  
> Audit SQL: `database/patches/shipment/2026-09-09-smk069-13-shipment-root-cause-audit.sql`

## 1. Incident state

Current queue evidence from the 9 Sep handoff:

```text
P96330 WAITING_BACKOFF attempt 3/5 HTTP 404
  POS API HTTP error 404; Response=404 page not found
  + Complete Shipment exception:
    Error converting data type nvarchar to bigint.
    dbo.SMK069CompleteShipmentSendSp:36

P96331 WAITING_BACKOFF attempt 3/5 HTTP 0
  Shipment DN P96331 tidak mempunyai DOC_NO/Customer Order.

P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
  POS API HTTP error 404; Response=404 page not found
  + Complete Shipment exception:
    Error converting data type nvarchar to bigint.
    dbo.SMK069CompleteShipmentSendSp:36
```

These are three different failure domains. Do not collapse them into one fix.

## 2. Repo audit finding: source control is behind the tenant DN contract

The current runtime contract is a prefixed string DN such as:

```text
P96330
P96331
P96332
```

Patch 11 preserved tenant evidence from `sys.parameters`:

```text
SMK069PrepareShipmentSendSp  @DN_No  bigint
SMK069BuildShipmentJsonSp    @DN_No  nvarchar
```

Patch 11 then changed only Prepare `@DN_No` to `NVARCHAR(40)`.

However the standalone files captured on 4 Sep are older:

- `database/procedures/shipment/SMK069BuildShipmentJsonSp.sql` still declares `@DN_No BIGINT`;
- `database/views/shipment/SMK069_ShipmentAPI_mst.sql` still exposes `sh.shipment_id AS DN_No`;
- `extension-classes/shipment/SMK069ShipmentSenderExtension.cs` still contains the older `long DN_No` path;
- `extension-classes/shipment/SMK069ShipmentSenderExtension.rev3.cs` is the newer string-DN candidate, but its own header warns that it is not guaranteed to equal the latest tenant source.

Therefore **none of those stale standalone files may be used to reconstruct `SMK069CompleteShipmentSendSp` by inference**.

The next tenant capture must include exact definitions of:

```text
dbo.SMK069_ShipmentAPI_mst
dbo.SMK069BuildShipmentJsonSp
dbo.SMK069PrepareShipmentSendSp
dbo.SMK069CompleteShipmentSendSp
```

and metadata for:

```text
dbo.ue_SMK069_shipment_api_log_mst
```

## 3. HTTP 404 finding

The HTTP layer is being reached. A response of:

```text
404 page not found
```

means the request arrived at a web route, but the configured Shipment route is not valid for this request.

The repo contains two historical candidates:

```text
https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
```

The configured `EndpointUrl` must be captured from the tenant and compared with the **known-good URL from POS team / the UAT request that previously returned business code `1010 data is exist`**.

Do not change the endpoint from guesswork and do not probe by burning Shipment retries.

## 4. Complete Shipment finding

`SMK069CompleteShipmentSendSp` is invoked after the HTTP call even when transport/business success is false so the outbound log can be finalized.

The extension passes this six-parameter shape:

```text
LogRowPointer
HttpCode
ResponseJson
IsSuccess
Success OUTPUT
Infobar OUTPUT
```

The observed exception occurs inside the stored procedure at line 36:

```text
Error converting data type nvarchar to bigint.
```

The exact tenant source is not in Git, so the safe procedure is:

1. capture `sys.parameters` for Complete;
2. capture `OBJECT_DEFINITION(dbo.SMK069CompleteShipmentSendSp)`;
3. capture line 36 directly;
4. capture column metadata for `ue_SMK069_shipment_api_log_mst`;
5. identify the actual string→BIGINT crossing;
6. patch only that declaration/conversion/reference;
7. preserve the rest of the tenant body exactly.

Patch 13 audit does steps 1–4 without changing any data.

## 5. P96331 is upstream CO/DOC_NO dependency

The Shipment view obtains `doc_no` through the Shipment line → Customer Order relationship.

P96331 must not be sent until its Shipment source resolves to a real Customer Order / `DOC_NO`.

This is the only reason to cross into the CSV→CO workstream: if the missing CO must be traced back to POS inbound creation. Do not mix CSV parsing or Blanket CO fixes into the HTTP 404 / Complete SP investigation.

## 6. Operational hold

Until root cause is fixed:

```text
DO NOT Reset Retry
DO NOT Run Now
DO NOT manually invoke SMK069SendPendingShipments
DO NOT manually invoke SMK069SendOneShipment
DO NOT spend the remaining attempt budget
```

The Patch 13 audit returns `SchedulerEnabled` and schedule state. If automatic scheduling is still enabled, hold it before the next `NextAttemptDate` using the normal Scheduler Control Center master switch. Do not edit retry counters directly.

## 7. Run Patch 13 audit

Run:

```text
database/patches/shipment/2026-09-09-smk069-13-shipment-root-cause-audit.sql
```

This script is intentionally read-only. Save all result sets, especially:

```text
1. current EndpointUrl / LoginUrl / SchedulerEnabled
2. procedure parameter metadata
3. exact tenant definitions
4. Complete line 36 and BIGINT markers
5. API log / Shipment view column metadata
6. P96330 / P96331 / P96332 current view rows
7. retry state
8. matching API log rows
9. scheduler state
```

## 8. Decision gate before one-DN UAT

A retry is allowed only after all of these are true:

- EndpointUrl is confirmed, not guessed;
- exact Complete source is captured;
- line 36 conversion root cause is fixed minimally;
- the fixed Complete procedure is source-controlled;
- P96331 has a valid DOC_NO before it is considered eligible;
- one active schedule maximum;
- `MaxShipments = 1` for the first controlled UAT.

Then reset **one** DN only and verify:

```text
Prepare -> HTTP -> Complete -> API log -> retry state -> Api_post
```

Do not reset all three together.
