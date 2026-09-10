# Shipment Scheduler — TaskMan Runtime Truth

Date: 2026-09-10

## Problem

The Shipment Scheduler Control Center originally displayed only custom application state:

- `ue_SMK069_shipment_api_config_mst.SchedulerEnabled`
- `ue_SMK069_shipment_schedule_mst.IsEnabled`
- `ue_SMK069_shipment_schedule_mst.RunState`

Those fields describe business/config intent, but they are not proof that a real Mongoose TaskMan background task is currently registered or executing.

Observed tenant screen on 10 Sep 2026 showed:

```text
API Active       = 1
Master Engine    = 0
Schedule Enabled = 1
Run State        = I
```

and the **Active Background Tasks** screen did not show `SMK069ShipmentScheduler`.

Therefore the effective runtime state was STOPPED / not registered even though the business schedule row was enabled.

## Authoritative TaskMan source

Infor Mongoose documents the actual queue as:

```text
Table : ActiveBGTasks
IDO   : MGCore.ActiveBGTasks
Form  : Active Background Tasks
```

Task states:

```text
WAITING = scheduled/recurring task is registered and waiting
READY   = task is queued for immediate TaskMan pickup
RUNNING = task is currently processing
absent  = no active TaskMan task is registered
```

The Shipment control center must therefore cross-check custom business state with `dbo.ActiveBGTasks`.

## Patch 18

File:

```text
database/patches/shipment/2026-09-10-smk069-18-taskman-runtime-status.sql
```

Creates:

```text
dbo.SMK069_ShipmentSchedulerRuntime_vw
```

The view is read-only and does not activate, submit, retry, or send anything.

Output properties:

```text
SiteRef
TaskName
ApiActive
MasterEnabled
ScheduleEnabled
BusinessRunning
NextRunDate
ActiveTaskCount
RunningCount
ReadyCount
WaitingCount
LatestTaskNumber
ApiStatusText
MasterStatusText
ScheduleStatusText
TaskManStatusText
OverallStatusText
StateSyncText
```

## Overall state rules

Examples:

```text
API inactive
  -> STOPPED - API INACTIVE

Master off
  -> STOPPED - MASTER OFF

Business schedule off
  -> STOPPED - SCHEDULE OFF

Business config ON but ActiveBGTasks has no SMK069ShipmentScheduler
  -> MISCONFIGURED - TASKMAN NOT REGISTERED

More than one active SMK069ShipmentScheduler task
  -> WARNING - DUPLICATE TASKMAN

TaskStatusCode = RUNNING
  -> RUNNING NOW

TaskStatusCode = READY
  -> ACTIVE - READY

TaskStatusCode = WAITING
  -> ACTIVE - WAITING
```

## Drift indicator

The view also compares custom `RunState` intent against actual TaskMan state:

```text
SYNC
DRIFT - BUSINESS SAYS RUNNING, TASKMAN DOES NOT
DRIFT - TASKMAN RUNNING, BUSINESS SAYS IDLE
```

This makes runtime drift visible instead of silently trusting the custom tables.

## IDO to create after Patch 18

Use IDO Wizard:

```text
Project Name       : ue_SMKRSCPOS
Access As          : ue_
Primary Base Table : SMK069_ShipmentSchedulerRuntime_vw
Table Alias        : shprun
IDO Name           : ue_SMK069ShipmentSchedulerRuntime
Extends            : blank
Extend And Replace : unchecked
```

Use `SiteRef` as the logical pseudo key. This IDO is read-only.

## Form design

Add the runtime IDO as a fourth secondary collection and show text, not numeric flags:

```text
OVERALL STATUS     : object4.OverallStatusText
API SERVICE        : object4.ApiStatusText
MASTER CONTROL     : object4.MasterStatusText
BUSINESS SCHEDULE  : object4.ScheduleStatusText
ACTUAL TASKMAN     : object4.TaskManStatusText
STATE SYNC         : object4.StateSyncText
TASK COUNT         : object4.ActiveTaskCount
TASK NUMBER        : object4.LatestTaskNumber
```

The operator should not need to interpret `1`, `0`, `I`, or `R` to know whether the scheduler is actually operating.

## Safety

A row in `ActiveBGTasks` is stronger runtime evidence than custom scheduler flags, but it still represents TaskMan queue state. A persistent `WAITING` record means the recurring task is registered; `RUNNING` is the definitive indication that TaskMan is executing it at that moment.
