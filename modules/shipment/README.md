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

CSV parsing dan pembuatan Blanket Customer Order berada di modul `csv-to-co`. Jangan campur workstream kecuali benar-benar diperlukan oleh dependency data Shipment.

## Runtime utama

```text
View       : dbo.SMK069_ShipmentAPI_mst
Service IDO: ue_SMK069ShipmentTransport
Extension  : SMK069ShipmentTransportExtension
Form       : ue_SMK069ShipmentScheduler
Task       : SMK069ShipmentScheduler
```

## Current status — 10 Sep 2026

```text
P96331 missing DOC_NO local Build gate    FIXED + VERIFIED (Patch 14 Rev.2)
Complete nvarchar -> bigint               FIXED + VERIFIED (Patch 15)
Old /inventory/v1/infor_dn route          REPLACED + VERIFIED (Patch 16)
Controlled P96331 arm state               VERIFIED (Patch 17)
Patch 18 SQL ActiveBGTasks view           WITHDRAWN / NO-OP for Cloud tenant
TaskMan runtime source                    VERIFIED: standard IDO ActiveBGTasks
Actual SMK069ShipmentScheduler task       NOT REGISTERED at latest runtime check
```

## Endpoint — verified

```text
SiteRef             Default
ApiName             SHIPMENT
IsActive            1
LoginUrl            https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl         https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
HttpMethod          POST
ContentType         application/json
SuccessMode         KACS_V1
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

`P96330` is **not** numeric shipment_id 96330.

## DOC_NO contract

Since Patch 14 Rev.2:

```text
DOC_NO blank                 -> allowed; Build continues and JSON sends "DOC_NO":""
one nonblank DOC_NO          -> use it
multiple distinct DOC_NO     -> block as ambiguous
```

Therefore DOC_NO is no longer a local required field for Shipment. POS remains the final authority and may still return a business validation response for blank DOC_NO.

## Patch 15 — Complete Shipment string DN fix

Patch 15 separates external DN text from internal numeric shipment key:

```text
@ShipmentDn NVARCHAR(40) -> P96330
@ShipmentId BIGINT       -> 30
```

Tenant verification:

```text
Patch15Marker               PASS
OldBigintAssignmentRemoved  PASS
StringDnPresent             PASS
```

## Patch 17 — controlled P96331 UAT arm

Latest verified controlled state:

```text
MasterEnabled     0
EndpointUrl       https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
ScheduleCode      HOURLY
MaxShipments      1
ScheduleEnabled   1
RunRequested      0
RunState          I
ShipmentId        P96331
AttemptCount      0
RetryState        P
NextAttemptDate   NULL
```

Candidate ranking was also verified:

```text
1. P96331 attempt 0
2. P96332 attempt 2
3. P96330 attempt 3
```

With `MaxShipments=1`, P96331 is the controlled first candidate.

## Scheduler runtime truth — Cloud-safe design

Do **not** treat custom table flags as proof that TaskMan exists.

Business/config state comes from:

```text
ApiActive
MasterEnabled
IsEnabled
RunState
NextRunDate
```

Actual TaskMan runtime comes directly from the standard Mongoose IDO:

```text
ActiveBGTasks
```

with permanent filter:

```text
TaskName = 'SMK069ShipmentScheduler'
```

Minimum TaskMan properties:

```text
TaskNumber
TaskName
TaskStatusCode
```

Tenant IDO Runtime / Load Collection verification on 10 Sep 2026 returned **0 actual rows** for that filter. The blank `*` row is only the form insert/placeholder row. Therefore the latest real runtime state is:

```text
TASKMAN HEARTBEAT = NOT REGISTERED
```

Evidence:

```text
tests/evidence/2026-09-10-smk069-activebgtasks-zero-row.md
docs/shipment/38-runtime-truth-via-mgcore-activebgtasks.md
```

## Patch 18 status

`database/patches/shipment/2026-09-10-smk069-18-taskman-runtime-status.sql` is now **WITHDRAWN / NO-OP**.

Reason: `dbo.ActiveBGTasks` is not visible from this Cloud application database. Runtime truth must be read through the Mongoose `ActiveBGTasks` IDO instead of an application-database SQL view.

Do not create `ue_SMK069ShipmentSchedulerRuntime` from a custom SQL view.

## Final one-form scheduler model

```text
ue_SMK069ShipmentScheduler
│
├── object  : ue_SMK069ShipmentSchedules
├── object2 : ue_SMK069ShipmentSchedulerDashboard
├── object3 : ue_SMK069ShipmentSchedulerQueue
└── object4 : ActiveBGTasks
              FILTERPERM(TaskName = 'SMK069ShipmentScheduler')
```

Operator status should be textual, not raw `1/0/I/R`:

```text
OVERALL STATUS
API SERVICE
MASTER CONTROL
BUSINESS SCHEDULE
TASKMAN HEARTBEAT
TASK STATUS
TASK NUMBER
BUSINESS RUNNER
```

Runtime rules:

```text
0 matching ActiveBGTasks row -> NOT REGISTERED
1 WAITING row                -> REGISTERED / WAITING
1 READY row                  -> REGISTERED / READY
1 RUNNING row                -> REGISTERED / RUNNING
>1 matching rows             -> WARNING - DUPLICATE SCHEDULER
```

Overall examples:

```text
STOPPED - TASKMAN NOT REGISTERED
STOPPED - MASTER OFF
STOPPED - SCHEDULE OFF
ACTIVE - WAITING
ACTIVE - READY
RUNNING NOW
WARNING - DUPLICATE SCHEDULER
```

## Final START / STOP behavior

### START SCHEDULER

The final one-form artifact checks `ActiveBGTasks` first.

If no task exists, it reproduces the standard Background Queue flow without opening the second form:

```text
submit SMK069ShipmentScheduler as WAITING
→ receive TaskNumber
→ call SLJobQueues.BackGroundQueue2Sp
→ configure a 5-minute recurring heartbeat
→ verify exactly one actual ActiveBGTasks row exists
→ enable business schedule
→ enable master scheduler
```

The 5-minute TaskMan heartbeat is infrastructure only. `IntervalMinutes` / `NextRunDate` remain the business cadence.

If more than one matching task already exists, START aborts and reports duplicate scheduler state.

### STOP SCHEDULER

```text
master OFF first
→ business schedule OFF
→ refresh ActiveBGTasks
→ delete matching WAITING heartbeat row(s)
→ refresh runtime truth
```

A standard SyteLine Active Background Tasks delete cannot remove a task already in `READY` or `RUNNING`. In that case the in-flight invocation is allowed to finish while master/business remain OFF; when it returns to WAITING, STOP can remove it.

## Credentials

The UAT form artifact keeps POS username/password hidden and uses placeholders only:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Real values must not be committed to GitHub. Replace placeholders only in the local XML if UAT requires hardcoded hidden credentials. `Hidden=True` is UI hiding, not encryption.

## Controlled one-DN UAT policy

Do not process P96330/P96332 yet. First establish exactly one TaskMan heartbeat and then run/observe P96331 with `MaxShipments=1`.

Decision gate:

```text
HTTP 404 again
  -> STOP; do not consume P96330/P96332

HTTP reaches POS business response
  -> route proven; inspect business response

Business success
  -> verify Complete -> API log -> retry state -> shipment_mst.SMK069_Uf_api_post
```

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
tests/evidence/
```

Patch 05 and Patch 06 under `database/patches/shipment/withdrawn/` must not be run.

## Next steps

1. Import the final one-form runtime-truth XML generated from `FS_20260910_065349.XML`.
2. Keep `Max / Run = 1` for UAT.
3. Press START once and verify exactly one `SMK069ShipmentScheduler` appears in Active Background Tasks.
4. Verify form shows `REGISTERED` plus actual `WAITING/READY/RUNNING` state.
5. Test STOP and verify the WAITING heartbeat disappears.
6. Only then continue controlled P96331 HTTP lifecycle testing.
