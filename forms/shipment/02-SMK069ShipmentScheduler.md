# ue_SMK069ShipmentScheduler — Shipment Scheduler Control Center

Date: 2026-09-10

## Final operator model

One operator-facing form only:

```text
ue_SMK069ShipmentScheduler
```

One business schedule currently used:

```text
ScheduleCode = HOURLY
```

The form is an operational control center, not a raw-table editor.

## Collections

```text
object  : ue_SMK069ShipmentSchedules
object2 : ue_SMK069ShipmentSchedulerDashboard
object3 : ue_SMK069ShipmentSchedulerQueue
object4 : ActiveBGTasks
          permanent filter:
          TaskName = 'SMK069ShipmentScheduler'
```

`object4` is critical. It is the Cloud-safe runtime truth source for TaskMan. Do not infer actual TaskMan registration from `SchedulerEnabled`, `IsEnabled`, or `RunState` alone.

Tenant verification on 10 Sep 2026 using IDO Runtime / Load Collection returned zero actual `ActiveBGTasks` rows for `SMK069ShipmentScheduler`, proving that custom schedule flags can differ from real TaskMan state.

## Status panel

Do not expose raw `1 / 0 / I / R` as the main operator status.

Display:

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

Mappings:

```text
ApiActive=1                  -> API SERVICE = ACTIVE
ApiActive<>1                 -> API SERVICE = INACTIVE
MasterEnabled=1              -> MASTER CONTROL = ON
MasterEnabled<>1             -> MASTER CONTROL = OFF
IsEnabled=1                  -> BUSINESS SCHEDULE = ENABLED
IsEnabled<>1                 -> BUSINESS SCHEDULE = DISABLED
RunState=R                   -> BUSINESS RUNNER = RUNNING
otherwise                    -> BUSINESS RUNNER = IDLE
```

Actual TaskMan mappings from `ActiveBGTasks`:

```text
0 rows                       -> HEARTBEAT = NOT REGISTERED
1 row                        -> HEARTBEAT = REGISTERED
>1 rows                      -> HEARTBEAT = DUPLICATE (n)
TaskStatusCode=WAITING       -> TASK STATUS = WAITING
TaskStatusCode=READY         -> TASK STATUS = READY
TaskStatusCode=RUNNING       -> TASK STATUS = RUNNING
```

Overall examples:

```text
STOPPED - API INACTIVE
STOPPED - TASKMAN NOT REGISTERED
WARNING - DUPLICATE SCHEDULER
STOPPED - MASTER OFF
STOPPED - SCHEDULE OFF
ACTIVE - WAITING
ACTIVE - READY
RUNNING NOW
```

## START SCHEDULER

START is not allowed to merely flip custom DB flags.

Required flow:

```text
refresh ActiveBGTasks
      ↓
more than 1 matching task?
      ├─ yes -> abort / duplicate warning
      └─ no
      ↓
0 matching task?
      ├─ yes -> submit SMK069ShipmentScheduler as WAITING
      │         receive TaskNumber
      │         configure recurrence with SLJobQueues.BackGroundQueue2Sp
      │         refresh ActiveBGTasks
      └─ no -> reuse existing task
      ↓
exactly 1 actual task exists?
      ├─ no -> do NOT enable business/master
      └─ yes
      ↓
SMK069SaveShipmentScheduleSp(... IsEnabled=1 ...)
      ↓
SMK069SetShipmentSchedulerEnabledSp(1)
      ↓
refresh all collections / recompute status
```

The recurring TaskMan heartbeat is set to 5 minutes. This is infrastructure polling only. Actual Shipment cadence remains controlled by:

```text
IntervalMinutes
NextRunDate
```

## STOP SCHEDULER

STOP is safety-first:

```text
SMK069SetShipmentSchedulerEnabledSp(0)
      ↓
SMK069SaveShipmentScheduleSp(... IsEnabled=0 ...)
      ↓
refresh ActiveBGTasks
      ↓
delete matching WAITING heartbeat row(s)
      ↓
save / refresh ActiveBGTasks
```

A task already in READY or RUNNING cannot be deleted through the normal Active Background Tasks delete flow. In that state, master/business switches are still turned OFF first so no new Shipment schedule claim should begin. The current invocation is allowed to finish; once the recurring row becomes WAITING again, STOP can remove it.

## RUN ONCE

`RUN ONCE` remains a one-time READY submit for controlled testing.

For current UAT keep:

```text
MaxShipments = 1
```

P96331 is the verified first queue candidate. Do not consume P96330/P96332 until the P96331 lifecycle is reviewed.

## Save Schedule

Editable operator fields:

```text
ScheduleName
IntervalMinutes
MaxShipments
```

Read-only/system fields include:

```text
ScheduleCode
NextRunDate
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

## Shipment queue

Collection:

```text
ue_SMK069ShipmentSchedulerQueue
```

Columns:

```text
ShipmentId       -> DN No
QueueStatus      -> Status
AttemptCount     -> Attempts
MaxAttempts      -> Max
NextAttemptDate  -> Next Retry
LastHttpCode     -> HTTP
LastError        -> Last Error
```

## Credentials

POS username/password controls stay hidden.

Conversation artifact uses placeholders:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Replace only in the local UAT XML if hardcoded credentials are required. Never commit real values to Git. Hidden form variables are not encrypted secrets.

## Current final artifact

Generated from tenant export `FS_20260910_065349.XML`:

```text
SMK069ShipmentScheduler_ONE_FORM_FINAL_RUNTIME_TRUTH.xml
```

Key behavior:

- directly reads actual `ActiveBGTasks`;
- computes human-readable runtime status in a form script;
- detects duplicate matching tasks;
- shows actual TaskNumber and TaskStatusCode;
- creates/checks recurring heartbeat on START without opening a second Background Queue form;
- disables master/business first on STOP and removes WAITING heartbeat rows;
- preserves explicit RUN ONCE behavior.

## Acceptance

The form is accepted only when an operator can answer without opening SQL or Active Background Tasks separately:

```text
Is the API active?
Is the master switch ON?
Is the business schedule enabled?
Is the actual TaskMan heartbeat registered?
What is its actual TaskStatusCode?
What is its TaskNumber?
Is the business runner idle or running?
Is there a duplicate scheduler?
Can START create exactly one actual heartbeat?
Can STOP remove the WAITING heartbeat?
```
