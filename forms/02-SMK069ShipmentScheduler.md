# SMK069ShipmentScheduler — Shipment Scheduler Control Center

## Final Tenant UI Decision — 8 Sep 2026

Form Name: `SMK069ShipmentScheduler`

The current tenant uses one operator-facing schedule only:

```text
ScheduleCode = HOURLY
```

The database may remain capable of more schedules, but this form does NOT expose New / Copy / Delete schedule actions.

The form is an operational dashboard, not a raw-table maintenance screen.

## Collections

```text
Primary Collection      : ue_SMK069ShipmentSchedules
Secondary Collection 2  : ue_SMK069ShipmentSchedulerDashboard
Secondary Collection 3  : ue_SMK069ShipmentSchedulerQueue
Service IDO             : ue_SMK069ShipmentTransport
```

Current tenant baseline confirmed on 8 Sep 2026:

```text
ScheduleCode     = HOURLY
ApiActive        = 1
MasterEnabled    = 0
IsEnabled        = 0
ReadyCount       = 1
Ready Shipment   = P96329
DefaultMaxBatch  = 50
```

## Final Layout

Do not add another splitter. Use the current form body and arrange four clear blocks.

```text
+--------------------------------------------------------------------------------+
| SHIPMENT SCHEDULER CONTROL CENTER                                              |
+--------------------------------------------------------------------------------+
| SYSTEM STATUS                                                                  |
| API [ACTIVE]   Scheduler [STOPPED]   Next Run [--]   Last Run [Never]          |
| System: Master ON/OFF (admin status only)                                      |
+--------------------------------------------------------------------------------+
| SCHEDULE CONTROL                         | LAST RUN                             |
| Code             HOURLY                  | Status      Never                    |
| Name             Every 60 Minutes        | Candidates  0                        |
| Interval Minutes [60]                    | Succeeded   0                        |
| Max Shipments    [1] / Default 50        | Failed      0                        |
|                                           | Exhausted   0                        |
| [Save Settings] [Activate] [Deactivate]  | Message     --                       |
| [Run Now] [Refresh]                      |                                        |
+--------------------------------------------------------------------------------+
| QUEUE SUMMARY                                                                   |
| Ready [1]   Waiting Retry [0]   Exhausted [0]   Success Today [0] Failed [0]    |
+--------------------------------------------------------------------------------+
| SHIPMENT QUEUE                                                                  |
| DN | Status | Attempts | Max | Next Retry | HTTP | Last Error                   |
| P96329 | READY | 0 | 5 | -- | -- | --                                           |
+--------------------------------------------------------------------------------+
```

## 1. System Status

Show these as read-only status fields / badges:

```text
ApiActive
MasterEnabled
NextRunDate
LastRunDate
```

Derived scheduler display state:

```text
MasterEnabled = 0                  -> SYSTEM DISABLED
MasterEnabled = 1, IsEnabled = 0   -> SCHEDULE STOPPED
RunState = R                       -> RUNNING
otherwise                          -> ACTIVE
```

`MasterEnabled` is an ADMIN kill switch. Do not make it the normal operator ON/OFF control.

If MasterEnabled = 0, show a clear warning such as:

```text
Scheduler system is disabled by administrator.
```

and disable Run Now.

## 2. Schedule Control

Visible properties:

```text
ScheduleCode       read-only
ScheduleName       read-only or editable by admin
IntervalMinutes    editable
MaxShipments       editable; blank = DefaultMaxBatchSize
IsEnabled          do not expose as a raw numeric textbox in the final UI
RunState           read-only
```

Use operator buttons instead of typing `0` / `1`:

```text
[Activate]
[Deactivate]
```

Recommended visibility:

```text
Activate   visible/enabled when IsEnabled = 0
Deactivate visible/enabled when IsEnabled = 1
```

Use `SMK069SaveShipmentScheduleSp` for saving settings and changing IsEnabled so NextRunDate is calculated server-side.

Parameters:

```text
ScheduleCode
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
StartAt = NULL
Success OUT
Infobar OUT
```

For first UAT keep:

```text
MaxShipments = 1
```

## 3. Run Now

Final production-safe button:

```text
[Run Now]
```

invokes:

```text
SMK069RequestShipmentRunNowSp(ScheduleCode)
```

It only makes HOURLY due immediately. It does not perform HTTP and it does not ask for POS credentials.

Enable only when:

```text
MasterEnabled = 1
AND IsEnabled = 1
AND RunState <> 'R'
```

The TaskMan heartbeat then picks up the due schedule.

Do not make the production Run Now button carry POS username/password in visible form parameters.

## 4. Last Run

Show these primary schedule properties as a dedicated result card:

```text
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

Status mapping:

```text
N = Never Run
S = Success
W = Completed With Failure
E = System Error
```

A TaskMan `Task Succeeded` result alone is NOT proof that a Shipment was processed. `LastCandidates`, `LastRunDate`, and queue/retry changes are the business proof.

## 5. Queue Summary KPIs

Use dashboard collection properties:

```text
ReadyCount
WaitingBackoffCount
ExhaustedCount
SucceededToday
FailedToday
DefaultMaxBatchSize
MaxAttempts
```

Main KPI row should display:

```text
Ready
Waiting Retry
Exhausted
Success Today
Failed Today
```

`DefaultMaxBatchSize` and `MaxAttempts` are supporting policy values and can appear as smaller text under Schedule Control rather than as headline KPIs.

## 6. Shipment Queue Grid

Collection: `ue_SMK069ShipmentSchedulerQueue`

Columns, in this order:

```text
ShipmentId       -> DN No
QueueStatus      -> Status
AttemptCount     -> Attempts
MaxAttempts      -> Max
NextAttemptDate  -> Next Retry
LastHttpCode     -> HTTP
LastError        -> Last Error
```

Current expected row:

```text
P96329 | READY | 0 | 5 | -- | -- | --
```

Queue is global for the Site. It is not owned by the HOURLY schedule before processing.

## 7. Dashboard / Queue Loading

Keep Dashboard and Queue as Form Secondary Collections.

They must be explicitly refreshed on form load / refresh.

Recommended events:

```text
StdFormInitCompleted
  sequence 10 -> refresh ue_SMK069ShipmentSchedulerDashboard
  sequence 20 -> refresh ue_SMK069ShipmentSchedulerQueue

StdFormRefreshCompleted
  refresh the same two secondary collections if needed
```

Do not redesign them as business parent/child collections merely to make them load.

## 8. Buttons

Final operator-facing buttons:

```text
Save Settings
Activate
Deactivate
Run Now
Refresh
```

Optional admin-only button for UAT / emergency configuration:

```text
Enable System / Disable System
```

which invokes `SMK069SetShipmentSchedulerEnabledSp`.

In normal operation MasterEnabled should normally stay ON and operator control is IsEnabled.

## 9. Refresh Behavior After Actions

After Save / Activate / Deactivate / Run Now:

```text
1. refresh primary Schedule
2. refresh Dashboard secondary collection
3. refresh Queue secondary collection
4. display returned Infobar / Success message
```

## 10. Final Acceptance

The form is ready when an operator can answer, without SQL:

```text
Is the API active?
Is the scheduler system enabled?
Is HOURLY active?
When will it run next?
How many Shipments are ready / waiting retry / exhausted?
Which DN is currently waiting?
What happened on the last scheduler run?
How many succeeded / failed?
Can I activate / deactivate it?
Can I request Run Now?
```

No credential or token is displayed anywhere on the dashboard.
