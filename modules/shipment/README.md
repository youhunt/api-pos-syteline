# Shipment Outbound → POS API

## Scope

Modul ini hanya menangani **Shipment outbound SyteLine → POS API**:

```text
SMK069_ShipmentAPI_mst
→ Build / Prepare Shipment
→ POS login
→ HTTP POST
→ Complete Shipment
→ Retry / Backoff
→ Scheduler / TaskMan
```

CSV parsing, `ue_SMK069_temp_sales_mst`, dan pembuatan Blanket Customer Order berada di modul `csv-to-co`. Modul CSV hanya boleh dibuka dari sini bila benar-benar diperlukan untuk dependency data Shipment.

## Runtime utama

```text
View       : dbo.SMK069_ShipmentAPI_mst
Service IDO: ue_SMK069ShipmentTransport
Extension  : SMK069ShipmentTransportExtension
Form       : Shipment Scheduler Control Center
```

## Queue incident — 9 Sep 2026

```text
P96330 WAITING_BACKOFF attempt 3/5 HTTP 404
P96331 sebelumnya WAITING_BACKOFF attempt 3/5 karena DOC_NO kosong
P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
```

Known blockers/status sekarang:

```text
P96331 missing DOC_NO local Build gate    FIXED + VERIFIED (Patch 14 Rev.2)
Complete nvarchar -> bigint               FIXED + VERIFIED (Patch 15)
Old /inventory/v1/infor_dn route          REPLACED + VERIFIED (Patch 16)
Controlled P96331 arm state               VERIFIED (Patch 17)
TaskMan runtime truth status              PATCH 18 READY; tenant verification pending
```

## Endpoint — Patch 16 verified

Tenant Query Select setelah Patch 16:

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

Patch:

```text
database/patches/shipment/2026-09-09-smk069-16-fix-shipment-endpoint-and-hold-scheduler.sql
```

## DN contract — current tenant evidence

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Therefore:

```text
P96330 = P963 + shipment_id 30
P96331 = P963 + shipment_id 31
P96332 = P963 + shipment_id 32
```

**P96330 bukan shipment_id 96330.**

## Patch 14 Revision 2 — missing DOC_NO non-blocking

Tenant verification:

```text
DN_No_Type        DocNoNonBlocking   EmptyStringJson
nvarchar          PASS               PASS
```

Missing DOC_NO no longer hard-stops Build; JSON becomes `"DOC_NO":""` when still blank. Multiple distinct nonblank DOC_NO protection remains active.

## Patch 15 — Complete Shipment string DN fix

Patch 15 separates external DN text from internal numeric shipment key:

```text
@ShipmentDn NVARCHAR(40) -> P96330
@ShipmentId BIGINT       -> 30
```

Tenant verification:

```text
Patch15Marker               OldBigintAssignmentRemoved   StringDnPresent
PASS                        PASS                         PASS
```

## Patch 17 — controlled P96331 UAT arm verified

Patch:

```text
database/patches/shipment/2026-09-09-smk069-17-arm-controlled-uat-p96331.sql
```

Tenant verification after Patch 17:

```text
MasterEnabled     0
EndpointUrl       https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
ScheduleCode      HOURLY
MaxShipments      1
ScheduleEnabled   1
RunRequested      0
RunState          I
NextRunDate       Sep 10 2026 10:35AM
ShipmentId        P96331
AttemptCount      0
RetryState        P
NextAttemptDate   NULL
LastHttpCode      0
```

## Patch 18 — actual TaskMan runtime truth

Problem found on 10 Sep 2026: the form can show custom DB flags (`SchedulerEnabled`, `IsEnabled`, `RunState`) that do not prove a real TaskMan task exists. Tenant screenshot showed `Schedule Enabled=1` while `SMK069ShipmentScheduler` was not visible in **Active Background Tasks**.

Patch 18 creates a read-only view that cross-checks the custom state against the actual Mongoose TaskMan queue table `dbo.ActiveBGTasks`:

```text
database/patches/shipment/2026-09-10-smk069-18-taskman-runtime-status.sql
docs/shipment/37-taskman-runtime-truth-status.md
```

New view:

```text
dbo.SMK069_ShipmentSchedulerRuntime_vw
```

Recommended read-only IDO after apply:

```text
ue_SMK069ShipmentSchedulerRuntime
```

The final form should show text, not raw 1/0/I/R:

```text
OVERALL STATUS
API SERVICE
MASTER CONTROL
BUSINESS SCHEDULE
ACTUAL TASKMAN
STATE SYNC
```

TaskMan truth rules:

```text
no ActiveBGTasks row              -> NOT REGISTERED
TaskStatusCode = WAITING          -> WAITING
TaskStatusCode = READY            -> READY
TaskStatusCode = RUNNING          -> RUNNING
more than one matching task       -> DUPLICATE TASKS
```

Overall examples:

```text
STOPPED - MASTER OFF
MISCONFIGURED - TASKMAN NOT REGISTERED
WARNING - DUPLICATE TASKMAN
ACTIVE - WAITING
ACTIVE - READY
RUNNING NOW
```

This prevents the form from silently trusting business/config rows when TaskMan reality is different.

## Controlled one-DN UAT policy

P96331 is already verified as candidate #1 with `MaxShipments=1`. Do not consume P96330/P96332 until the TaskMan heartbeat/runtime state is made explicit and the single controlled run is reviewed.

Decision gate after one-DN send:

```text
HTTP 404 again
  -> STOP; do not consume P96330/P96332

HTTP reaches POS business response
  -> endpoint route is proven; inspect business response

Business success
  -> verify Complete -> API log -> retry state -> shipment_mst.SMK069_Uf_api_post
```

## Scheduler / form

The one-form operator model controls business schedule state, but actual TaskMan runtime must be displayed separately.

`Run Now` / TaskMan HTTP method must remain NON-TRANSACTIONAL.

## Tenant Query Select limitations confirmed

```text
pure SELECT only
no DECLARE
no SET
no EXEC
no BEGIN/END
no GO
no plain ORDER BY
no trailing semicolon
short output values only
```

## Source utama

```text
database/patches/shipment/
database/procedures/shipment/
database/views/shipment/
database/shipment/
extension-classes/shipment/
forms/shipment/
ido/shipment/
docs/shipment/
implementation/shipment/
```

Patch 05 and Patch 06 under `database/patches/shipment/withdrawn/` must not be run.

## Next steps

1. Apply Patch 18; if `dbo.ActiveBGTasks` is not visible, stop and capture tenant evidence instead of guessing.
2. Create/read-only IDO `ue_SMK069ShipmentSchedulerRuntime` from the new runtime view.
3. Import/use the REV3 one-form template that binds text status fields to this runtime IDO.
4. Verify the form reports `NOT REGISTERED` when no actual `SMK069ShipmentScheduler` row exists in Active Background Tasks.
5. Establish exactly one persistent `SMK069ShipmentScheduler` heartbeat task; avoid duplicates.
6. Only after runtime status is truthful, execute the controlled P96331 run with Max/Run=1 and review the full lifecycle.
