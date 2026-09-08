# Shipment Scheduler Form with Multi-Schedule Support

Date: 2026-09-08

This document corrects the earlier over-simplification that proposed hiding the Schedule list permanently.

## Final decision

Because users must be able to add and maintain more than one scheduler definition, the Schedule selector/list remains part of the main form.

The Queue is still Site-level and is not owned by the currently selected Schedule while it is still READY.

## Final first operational layout

```text
+----------------------+-----------------------------------------------+
| SCHEDULE LIST        | SELECTED SCHEDULE                             |
|                      | Code         : HOURLY                          |
| [New] [Delete]       | Name         : Every 60 Minutes               |
|                      | Interval     : 60                              |
| HOURLY               | Max/Run      : blank = default                |
| FAST-15              | Enabled      : 0                              |
| NIGHTLY              | Next Run     : --                             |
|                      | Last Status  : N                              |
+----------------------+-----------------------------------------------+
| DASHBOARD / SITE STATUS                                             |
| API Active 1 | Master 0 | Ready 2 | Waiting 0 | Exhausted 0 | Max 50 |
+----------------------------------------------------------------------+
| SHIPMENT QUEUE                                                       |
| DN       | Status | Attempts | Max | Next Retry | HTTP | Last Error  |
| P96327   | READY  | 0        | 5   |            |      |             |
| P96328   | READY  | 0        | 5   |            |      |             |
+----------------------------------------------------------------------+
```

## Collection semantics

```text
Schedule list/detail  = ue_SMK069ShipmentSchedules
Dashboard             = ue_SMK069ShipmentSchedulerDashboard
Queue                 = ue_SMK069ShipmentSchedulerQueue
Config                = ue_SMK069ShipmentApiConfigs
```

The Schedule list and selected Schedule detail are two presentations of the same Schedule collection.

Dashboard and Queue are Site-level data.

Do not link Queue to `ScheduleCode`.
Do not treat Dashboard as owned by one Schedule.

## Adding schedules

Users must be able to add schedule definitions from the main form.

Recommended controls:

```text
New Schedule
Delete/Deactivate Schedule
Save Schedule
Run Now
```

A new Schedule row captures at least:

```text
ScheduleCode
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
StartAt / NextRunDate when applicable
```

The existing `SMK069SaveShipmentScheduleSp` already supports inserting a new Schedule when the `(SiteRef, ScheduleCode)` row does not exist.

Examples:

```text
HOURLY   | Every 60 Minutes | 60 | default batch
FAST-15  | Every 15 Minutes | 15 | 10 shipments/run
NIGHTLY  | Nightly          | configured schedule policy
```

## Queue ownership and traceability

A READY queue row has no owning schedule yet.

When a due Schedule actually claims and processes a queue item, traceability should be recorded through the run model:

```text
Schedule -> Run Header -> Run Detail -> Shipment
```

This lets the operator answer:

```text
Which schedule processed P96327?
At what time?
In which run?
What was the result?
```

The run traceability model is documented in:

```text
implementation/39-shipment-scheduler-run-traceability-model.md
```

## Form behavior

1. Left Schedule list stays visible so the user can select/add schedules.
2. Right-side fields edit/show the selected Schedule.
3. Dashboard is a global Site summary and must not change merely because a different Schedule row is selected.
4. Queue is a global Site queue and must not change merely because a different Schedule row is selected.
5. Later, Run History can be filtered by selected Schedule if desired, because a completed run does have a ScheduleCode.

## Current UAT baseline

```text
Schedule: HOURLY
Interval: 60
Enabled : 0
Dashboard ReadyCount: 2
Queue:
P96327 READY
P96328 READY
```

Scheduler execution remains OFF until the form read model, run traceability, and first-send UAT are ready.
