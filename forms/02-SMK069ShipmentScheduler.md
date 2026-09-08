# SMK069ShipmentScheduler — Shipment Scheduler Control Center

## Identity

```text
Form Name          : SMK069ShipmentScheduler
Display Name       : Shipment Scheduler Control Center
IDO Project        : SMK069
Primary Collection : ue_SMK069ShipmentSchedules
Service IDO        : ue_SMK069ShipmentTransport
Status              : Ready for Mongoose form build after Patch 09
Design Date         : 2026-09-08
```

## Why this form exists

Scheduler Shipment sudah memiliki config, retry state, outbound API log, dan batch sender,
tetapi tanpa form operator harus membaca tabel dan menjalankan SQL untuk menjawab pertanyaan
sederhana seperti:

- scheduler hidup atau mati?
- kapan jalan lagi?
- ada berapa DN yang siap dikirim?
- DN mana yang sedang backoff?
- DN mana yang sudah menyerah setelah `MaxAttempts`?
- run terakhir sukses atau gagal?
- endpoint dan retry policy sekarang berapa?
- bagaimana menjalankan sekarang tanpa membuka password di form?

Form ini menjadi **control center operasional** untuk semua pertanyaan tersebut.

Password/token **tidak pernah menjadi field form**.

---

## Recommended Layout

```text
+--------------------------------------------------------------------------------------------------+
| SHIPMENT SCHEDULER CONTROL CENTER                                                               |
+--------------------------------------------------------------------------------------------------+
| API       [ACTIVE]       Master Scheduler [OFF]        Next Run [--]                             |
| Ready     [   0 ]        Waiting Backoff   [   0 ]     Exhausted [   0 ]                         |
| Success Today [ 0 ]      Failed Today      [   0 ]                                              |
|                                                                                                  |
| [Refresh]  [Master ON/OFF]  [New Schedule]  [Run Now]                                            |
+--------------------------------------------------------------------------------------------------+
| Tabs                                                                                             |
| [Schedules] [Retry Queue] [Last Result] [API Log] [Configuration]                                |
+--------------------------------------------------------------------------------------------------+
```

The top summary is loaded through `SMK069GetShipmentSchedulerDashboardSp`, not by
letting the client calculate counts independently.

---

# 1. Dashboard Header

Use form variables:

```text
vMasterEnabled
vApiActive
vScheduleCount
vActiveScheduleCount
vNextRunDate
vReadyCount
vWaitingBackoffCount
vExhaustedCount
vSucceededToday
vFailedToday
vDashboardMessage
```

### Suggested visual states

```text
API Active       : green when 1, red when 0
Master Scheduler : green ON / gray OFF
Ready            : neutral
Waiting Backoff  : amber when > 0
Exhausted        : red when > 0
Failed Today     : red when > 0
```

Do not make the colors the only signal; keep the numeric/text label visible.

---

# 2. Schedules Tab

Primary collection:

```text
IDO      : ue_SMK069ShipmentSchedules
Filter   : SiteRef = current site
Order By : IsEnabled DESC, NextRunDate, ScheduleCode
```

Grid columns:

| Field | Label | Editable | Notes |
|---|---|---:|---|
| `ScheduleCode` | Code | On create only | Example `HOURLY`, `NIGHT` |
| `ScheduleName` | Schedule Name | Yes | Friendly name |
| `IntervalMinutes` | Every (Minutes) | Yes | `60` = hourly |
| `MaxShipments` | Max / Run | Yes | blank = use config `MaxBatchSize` |
| `IsEnabled` | Active | Through Save action | Schedule-level switch |
| `NextRunDate` | Next Run | No | calculated |
| `RunRequested` | Run Now Requested | No | internal |
| `RunState` | State | No | `I` idle / `R` running |
| `LastRunDate` | Last Run | No | result timestamp |
| `LastRunStatus` | Last Status | No | `N/S/W/E` |
| `LastCandidates` | Candidate | No | last result |
| `LastSucceeded` | Success | No | last result |
| `LastFailed` | Failed | No | last result |
| `LastExhausted` | Exhausted | No | last result |
| `LastMessage` | Last Message | No | last summary |

### Schedule editor area

```text
Schedule Code     [____________]
Schedule Name     [________________________________]
Run Every         [ 60 ] minutes
Max Shipments     [     ]  (blank = config default)
Active            [x]
First / Next Run  [yyyy-mm-dd hh:mm]  optional

[Save Schedule] [Clear / New]
```

`Save Schedule` invokes `SMK069SaveShipmentScheduleSp`.

Do not let users edit `NextRunDate`, `RunState`, `LeaseUntil`, or last-result
columns directly.

### Default row

Patch 09 seeds:

```text
Code     : HOURLY
Name     : Every 60 Minutes
Interval : 60
Active   : OFF
```

It is deliberately OFF until UAT is complete.

---

# 3. Run Now

Button:

```text
[Run Now]
```

Behavior:

1. requires selected schedule;
2. invokes `SMK069RequestShipmentRunNowSp`;
3. refreshes schedule + dashboard;
4. **does not ask for POS username/password**;
5. marks the schedule due and lets the secure background runner pick it up.

This matters because Mongoose can echo IDO input parameters in responses.
Production credentials must stay in TaskMan parameters, not a button event.

Enable when:

```text
vMasterEnabled = 1
AND selected schedule IsEnabled = 1
AND RunState <> 'R'
```

---

# 4. Master Scheduler ON/OFF

Button / toggle invokes:

```text
SMK069SetShipmentSchedulerEnabledSp
```

Labels:

```text
OFF -> "Master Scheduler OFF"
ON  -> "Master Scheduler ON"
```

This is different from `Schedule.IsEnabled`:

- `SchedulerEnabled` in API config = **master kill switch**;
- `Schedule.IsEnabled` = whether one schedule participates.

A schedule may be active while the master switch is OFF; in that case it will
not be claimed by the background runner.

---

# 5. Retry Queue Tab

Collection:

```text
IDO      : ue_SMK069ShipmentRetries
Filter   : SiteRef = current site AND RetryState <> 'S'
Order By : RetryState DESC, NextAttemptDate, ShipmentId
Read Only: Yes, except controlled Reset action
```

Columns:

| Field | Label |
|---|---|
| `ShipmentId` | DN No |
| `RetryState` | State |
| `AttemptCount` | Attempts |
| `FirstAttemptDate` | First Attempt |
| `LastAttemptDate` | Last Attempt |
| `NextAttemptDate` | Retry After |
| `LastHttpCode` | HTTP |
| `LastError` | Last Error |

Display text:

```text
P = Pending / waiting retry
X = Exhausted / operator action required
S = Success (normally hidden from this tab)
```

### Reset Retry

Button:

```text
[Reset Retry]
```

Invokes:

```text
SMK069ResetShipmentRetrySp(selected ShipmentId)
```

Confirmation text:

```text
Return DN <DN> to the automatic queue?
Use this only after the cause of the failure has been corrected.
```

The procedure resets attempt count and retry timing but keeps `LastError` and
`LastHttpCode` for audit visibility.

---

# 6. Last Result Tab

The selected schedule itself carries the latest run summary:

```text
LastStartDate
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

Recommended card:

```text
Last Run        : 2026-09-08 10:00
Status          : SUCCESS / WARNING / ERROR
Candidates      : 12
Succeeded       : 11
Failed          : 1
Exhausted       : 0
Message         : ...
```

Status mapping:

```text
N = Never run
S = Completed, no shipment failure
W = Completed, one or more shipment failures
E = Background/system error
```

Detailed per-DN history belongs in API Log, not in the schedule row.

---

# 7. API Log Tab

Collection:

```text
Source : existing dbo.ue_SMK069_shipment_api_log_mst
Mode   : read-only on this form
Filter : SiteRef = current site
Order  : newest first
```

Show the existing operational fields that are present in the tenant, including
at minimum when available:

```text
ShipmentId
Status
HttpCode
Request/Response timestamp
RetryCount
ErrorMessage / Response
RowPointer
```

Do not display auth token, password, or authorization header. `AuthValue` from
the API config is also intentionally absent from this form.

If payload/response columns are large, use a detail text area or separate
drill-down rather than placing full JSON in the grid.

---

# 8. Configuration Tab

Collection:

```text
IDO    : ue_SMK069ShipmentApiConfigs
Filter : SiteRef = current site AND ApiName = 'SHIPMENT'
```

Fields visible:

| Field | Label | Editable |
|---|---|---:|
| `EndpointUrl` | Shipment Endpoint | Yes |
| `LoginUrl` | Login Endpoint | Yes |
| `HttpMethod` | HTTP Method | Normally no |
| `ContentType` | Content Type | Normally no |
| `TimeoutSeconds` | Timeout (Seconds) | Yes |
| `SuccessMode` | Success Mode | Yes |
| `IsActive` | API Config Active | Admin only |
| `SchedulerEnabled` | Master Scheduler | via action |
| `MaxBatchSize` | Default Max / Run | Yes |
| `MaxAttempts` | Max Attempts | Yes |
| `BackoffBaseMinutes` | Backoff Base (Min) | Yes |
| `BackoffCapMinutes` | Backoff Cap (Min) | Yes |

Fields deliberately hidden:

```text
AuthValue
```

`AuthType` and `AuthHeader` may be shown read-only for troubleshooting, but
they are not the source of the runtime KACS token.

### Recommended validation

```text
EndpointUrl       required, https
LoginUrl          required, https
TimeoutSeconds    1..300
MaxBatchSize      > 0
MaxAttempts       1..20
BackoffBaseMinutes > 0
BackoffCapMinutes >= BackoffBaseMinutes
SuccessMode       KACS_V1 for current POS contract
```

---

# 9. Buttons and Events

| Button | Action |
|---|---|
| Refresh | reload dashboard + current collections |
| New Schedule | clear editor variables |
| Save Schedule | invoke `SMK069SaveShipmentScheduleSp` |
| Run Now | invoke `SMK069RequestShipmentRunNowSp` |
| Master ON/OFF | invoke `SMK069SetShipmentSchedulerEnabledSp` |
| Reset Retry | invoke `SMK069ResetShipmentRetrySp` |
| View API Detail | drill into selected API log row |

After every mutating action:

```text
refresh Schedules
refresh Retry Queue if relevant
invoke Dashboard
display returned Infobar
```

---

# 10. Form Load Event

Pseudo-flow:

```text
FormLoad
  -> filter all collections to current Site
  -> select SHIPMENT config
  -> invoke SMK069GetShipmentSchedulerDashboardSp
  -> load form variables
  -> select first active schedule, otherwise HOURLY
```

Optional timer refresh:

```text
every 60 seconds while the form is open
```

The actual scheduler **must not depend on this timer or on the form being open**.

---

# 11. Authorization

Recommended security classes:

| Security Class | Permission |
|---|---|
| `SMK069_SHIPMENT_SCHED_VIEW` | view dashboard, schedules, retry, API logs |
| `SMK069_SHIPMENT_SCHED_RUN` | Run Now |
| `SMK069_SHIPMENT_SCHED_RETRY` | Reset Retry |
| `SMK069_SHIPMENT_SCHED_ADMIN` | edit config, schedules, master switch |

Do not give configuration edit rights just because a user may view logs.

---

# 12. Background Runner Relationship

The form defines and monitors schedules; it is not the runtime host.

Recommended runtime model:

```text
TaskMan heartbeat (for example every 5 minutes)
       |
       v
SMK069RunDueShipmentSchedule
       |
       +-- SMK069ClaimDueShipmentScheduleSp
       |      -> no due schedule = return without HTTP
       |
       +-- existing SMK069SendPendingShipments
       |
       +-- SMK069CompleteShipmentScheduleSp
              -> saves last result + computes NextRunDate
```

This makes schedule edits effective from the form without editing TaskMan every
time. TaskMan carries only the POS credentials and the heartbeat.

The runner method is the next wiring step on the existing
`ue_SMK069ShipmentTransport` extension class; Patch 09 already provides the SQL
contract it consumes.

---

# 13. Acceptance Test

After Patch 09 and form build:

```text
1. Open form:
   Master Scheduler = OFF
   default HOURLY schedule exists and is OFF.

2. Save HOURLY with:
   interval = 60
   Active = ON
   -> Next Run populated.

3. Keep master OFF:
   Run Now must refuse with a clear message.

4. Master ON:
   Run Now marks schedule due.
   No username/password field appears anywhere on the form.

5. Retry Queue:
   a failed DN shows Attempts, Retry After and Last Error.

6. Reset Retry:
   selected DN returns to P with AttemptCount=0,
   while Last Error remains visible.

7. Dashboard:
   Ready / Backoff / Exhausted counts agree with retry data.

8. Background runner complete:
   Last Result updates and Next Run moves by IntervalMinutes.
```
