# 36 — Controlled one-DN UAT arm for P96331

> Date: 9 September 2026  
> Scope: Shipment Outbound SyteLine -> POS API only  
> Patch: `database/patches/shipment/2026-09-09-smk069-17-arm-controlled-uat-p96331.sql`

## Why Patch 17 exists

Patch 14 fixed missing `DOC_NO` as a local hard stop. Patch 15 fixed Complete's prefixed DN `nvarchar -> bigint` failure. Patch 16 moved the endpoint to the remaining evidence-backed UAT route and held the master scheduler OFF.

The first pre-UAT verification after Patch 16 showed:

```text
HOURLY MaxShipments    NULL
HOURLY IsEnabled       1
HOURLY RunRequested    0
HOURLY RunState        I
P96331 AttemptCount    3
P96331 RetryState      P
P96331 NextAttemptDate Sep 9 2026 9:24AM
```

That state is not safe to run because:

1. `MaxShipments=NULL` falls back to the configured batch maximum when the schedule is claimed;
2. P96331 was not actually reset;
3. an enabled schedule with an already-due/NULL NextRunDate can be claimed immediately as soon as master scheduling is turned on, before an operator has time to press Run Now.

## Patch 17 behavior

Patch 17 is an **arming patch only**. It performs no HTTP call.

It asserts:

```text
active SHIPMENT config exists
Master Scheduler = OFF
EndpointUrl = https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
HOURLY schedule exists
P96331 retry state exists
P96331 is still an unsent eligible Shipment in the Shipment View
```

Then it changes only controlled-UAT state:

```text
HOURLY MaxShipments   = 1
HOURLY IsEnabled      = 1
HOURLY RunRequested   = 0
HOURLY RunState       = I
HOURLY LeaseUntil     = NULL
HOURLY NextRunDate    = GETDATE() + 1 day

P96331 AttemptCount    = 0
P96331 RetryState      = P
P96331 NextAttemptDate = NULL
```

Historical `LastHttpCode` / `LastError` are deliberately retained, matching `SMK069ResetShipmentRetrySp` audit semantics.

## Why NextRunDate is parked in the future

`SMK069ClaimDueShipmentScheduleSp` considers an enabled schedule due when any of the following are true:

```text
RunRequested = 1
NextRunDate IS NULL
NextRunDate <= GETDATE()
```

Therefore leaving `NextRunDate=NULL` is **not** a safe idle state. Patch 17 parks the date one day ahead so the master scheduler can later be turned on without an immediate automatic claim. The operator can then explicitly use Run Now, which sets the schedule due.

## Apply Database

Run Patch 17 through Infor Apply Database as one batch. It contains no `GO`.

Expected output:

```text
OK - Patch 17 applied.
Master Scheduler tetap OFF.
HOURLY MaxShipments=1, IsEnabled=1, RunRequested=0, RunState=I.
HOURLY NextRunDate diparkir +1 hari untuk mencegah auto-claim sebelum Run Now.
P96331 AttemptCount=0, RetryState=P, NextAttemptDate=NULL.
Patch ini TIDAK melakukan HTTP call.
LANGKAH BERIKUT: verifikasi ranking candidate sebelum Master Scheduler ON.
```

## Query Select verification

Use pure SELECT only, with no trailing semicolon:

```sql
SELECT
    c.SchedulerEnabled AS MasterEnabled,
    c.EndpointUrl,
    s.ScheduleCode,
    s.MaxShipments,
    s.IsEnabled AS ScheduleEnabled,
    s.RunRequested,
    s.RunState,
    s.NextRunDate,
    r.ShipmentId,
    r.AttemptCount,
    r.RetryState,
    r.NextAttemptDate,
    r.LastHttpCode
FROM dbo.ue_SMK069_shipment_api_config_mst AS c
JOIN dbo.ue_SMK069_shipment_schedule_mst AS s
  ON s.SiteRef = c.SiteRef
 AND s.ScheduleCode = N'HOURLY'
LEFT JOIN dbo.ue_SMK069_shipment_retry_mst AS r
  ON r.SiteRef = c.SiteRef
 AND r.ShipmentId = N'P96331'
WHERE c.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.ApiName = N'SHIPMENT'
  AND c.IsActive = 1
```

Expected key values:

```text
MasterEnabled    0
MaxShipments     1
ScheduleEnabled  1
RunRequested     0
RunState         I
ShipmentId       P96331
AttemptCount     0
RetryState       P
NextAttemptDate  NULL
```

Do not turn master ON until the queue ranking is verified and P96331 is confirmed as the single first candidate for MaxShipments=1.
