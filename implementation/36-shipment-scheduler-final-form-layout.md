# Shipment Scheduler — Final Form Layout Decision

Date: 2026-09-08

This document fixes the visual information architecture for `SMK069ShipmentScheduler` after tenant form testing.

## Final layout

Use four visual zones:

```text
+--------------------------------------------------------------------------------------------------+
| SHIPMENT SCHEDULER CONTROL CENTER                                                               |
+--------------------------------------------------------------------------------------------------+
| Dashboard / Site Status                                                                         |
| API: ACTIVE | Master: OFF | Ready: 2 | Waiting: 0 | Exhausted: 0 | Default Max: 50 | Retry: 5   |
+------------------------------+-------------------------------------------------------------------+
| SCHEDULES                    | SELECTED SCHEDULE DETAIL                                           |
|                              |                                                                   |
| HOURLY                       | Code        : HOURLY                                               |
| FAST-15                      | Name        : Every 60 Minutes                                     |
| ...                          | Interval    : 60                                                   |
|                              | Max / Run   : Default / 50                                         |
|                              | Enabled     : No                                                   |
|                              | Next Run    : --                                                   |
|                              | Last Status : Never                                                |
+------------------------------+-------------------------------------------------------------------+
| SHIPMENT QUEUE                                                                                   |
| DN No    | Status | Attempts | Max Attempts | Retry After | HTTP | Last Error                    |
| P96327   | READY  | 0        | 5            |             |      |                               |
| P96328   | READY  | 0        | 5            |             |      |                               |
+--------------------------------------------------------------------------------------------------+
```

## Collection role by zone

### Header / Dashboard

IDO:

```text
ue_SMK069ShipmentSchedulerDashboard
```

This collection is Site-level and normally returns one row per Site. It must **not** be shown as the left navigation grid because a one-row grid adds no useful navigation value.

Recommended header fields:

```text
ApiActive
MasterEnabled
ReadyCount
WaitingBackoffCount
ExhaustedCount
DefaultMaxBatchSize
MaxAttempts
NextRunDate
SucceededToday
FailedToday
```

### Left grid — Schedules

Primary collection:

```text
ue_SMK069ShipmentSchedules
```

This is the correct navigation grid because there may be multiple schedule definitions. The selected row controls only the schedule detail panel on the right.

Recommended grid columns:

```text
ScheduleCode
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
NextRunDate
LastRunStatus
```

### Right detail — Selected Schedule

Bind to the same primary Schedule collection selected in the left grid.

Recommended fields:

```text
ScheduleCode
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
NextRunDate
RunState
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

This is the only true grid/detail relationship on the screen.

### Bottom grid — Shipment Queue

IDO:

```text
ue_SMK069ShipmentSchedulerQueue
```

The Queue is Site-level and independent of the selected schedule. Every schedule consumes the same Site Shipment queue.

Therefore do **not** link Queue by `ScheduleCode` and do not make Queue a child collection of Schedule.

Recommended columns:

```text
ShipmentId
QueueStatus
AttemptCount
MaxAttempts
RetryState
NextAttemptDate
LastHttpCode
LastError
```

## Configuration

`ue_SMK069ShipmentApiConfigs` is Site-level configuration and should not occupy the main screen. Put it later in a separate `Configuration` tab or an Admin section.

Show only:

```text
EndpointUrl
LoginUrl
TimeoutSeconds
SuccessMode
MaxBatchSize
MaxAttempts
BackoffBaseMinutes
BackoffCapMinutes
IsActive
SchedulerEnabled
```

Never show `AuthValue`.

## Collection loading rule

The Schedule primary collection loads with the form. Independent Dashboard / Queue / Config collections must be explicitly refreshed on form load / refresh.

Do not create fake master-detail links only to force collection loading.

## Final reasoning

The form must communicate three different scopes clearly:

```text
Site-level status      -> Dashboard header
Schedule definitions  -> left grid + selected detail
Site-level work queue  -> bottom grid
```

This avoids the false impression that a Shipment DN belongs to one specific schedule.

## Current tenant baseline

```text
Dashboard:
SiteRef             = Default
MasterEnabled       = 0
ApiActive           = 1
ScheduleCount       = 1
ActiveScheduleCount = 0
DefaultMaxBatchSize = 50
MaxAttempts         = 5
ReadyCount          = 2
WaitingBackoffCount = 0
ExhaustedCount      = 0

Schedules:
HOURLY | Every 60 Minutes | Interval 60 | IsEnabled 0

Queue:
P96327 | READY | Attempt 0/5
P96328 | READY | Attempt 0/5
```

Keep Master Scheduler and all schedules OFF until runner/TaskMan UAT is complete.
