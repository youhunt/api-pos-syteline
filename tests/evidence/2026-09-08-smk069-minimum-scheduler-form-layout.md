# SMK069 Shipment Scheduler — Minimum Form Layout Evidence

Date: 2026-09-08

The tenant form `SMK069ShipmentScheduler` has reached the first visible layout milestone in Design Mode.

## Visible structure confirmed

Primary schedule area currently includes:

- Schedule Code
- Schedule Name
- Interval Minutes
- Max Shipments
- Is Enabled
- Run State
- Last Status

Dashboard area currently includes:

- Master Scheduler
- API Active
- Ready
- Waiting Retry
- Exhausted
- Default Max

Queue grid currently includes visible columns for:

- ShipmentId
- Queue Status
- Max Attempts
- Next Attempt
- Last HTTP Code
- Last Error

## Required small correction before runtime verification

Add `AttemptCount` to the queue grid so the retry information is shown as current attempt versus max attempts.

Recommended first queue columns:

```text
ShipmentId
QueueStatus
AttemptCount
MaxAttempts
NextAttemptDate
LastHttpCode
LastError
```

## Runtime verification still required

Design Mode blanks are not considered a failure by themselves. Save the form, exit Design Mode, then open it normally.

Expected runtime data:

```text
ScheduleCode       = HOURLY
ScheduleName       = Every 60 Minutes
IntervalMinutes    = 60
IsEnabled          = 0
RunState           = I
LastRunStatus      = N

MasterEnabled      = 0
ApiActive          = 1
ReadyCount         = 2
WaitingBackoffCount= 0
ExhaustedCount     = 0
DefaultMaxBatchSize= 50

P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

Keep scheduler OFF. No Run Now, Master ON, TaskMan heartbeat, or automatic HTTP sending is enabled at this milestone.
