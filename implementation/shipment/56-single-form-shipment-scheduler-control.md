# 56 — Single-Form Shipment Scheduler Control

Date: 2026-09-10
Status: Revision 2 after tenant UI test

## Source evidence

Tenant form export reviewed: `FS_20260910_040209.XML`.

The original export contains two forms:

- `ue_SMK069_BackgroundQueue`
- `ue_SMK069ShipmentScheduler`

The operator-facing scheduler originally opened `BackgroundQueue(...)` from Activate. The one-form conversion removes that child-form workflow.

## Tenant test result — 10 Sep 2026

After importing the first one-form revision, the operator screenshot showed:

```text
API Active       = 1
Master Engine    = 0
Schedule Enabled = 1
Run State        = I
ScheduleCode     = HOURLY
IntervalMinutes  = 10
MaxShipments     = 1
```

This means the effective scheduler is **STOPPED**. A schedule row can be enabled while the master engine is disabled; `RunState=I` means idle, not running.

Effective run condition:

```text
ApiActive = 1
AND MasterEnabled = 1
AND IsEnabled = 1
```

The supplied Active Background Tasks screenshot also did not show a recurring `SMK069ShipmentScheduler` instance. Background Task Definition existence alone is not enough: TaskMan needs one active recurring heartbeat instance.

## Final operator model

Use only one operator-facing form:

```text
ue_SMK069ShipmentScheduler
```

Background Task Definition remains:

```text
SMK069ShipmentScheduler
```

TaskMan is a **persistent infrastructure heartbeat**. Provision it once, for example every 5 minutes. It does not own the business interval.

The business interval is owned by:

```text
ue_SMK069_shipment_schedule_mst.IntervalMinutes
ue_SMK069_shipment_schedule_mst.NextRunDate
```

A 10-minute business interval with a 5-minute TaskMan heartbeat runs at the first heartbeat after `NextRunDate` becomes due.

Do not create another recurring TaskMan row every time START is pressed; that can create duplicate sender instances.

## Revision 2 UI

Internal numeric/coded status must be explained in the form:

```text
API SERVICE
MASTER SCHEDULER
BUSINESS SCHEDULE
RUNNER STATE

RUN CONDITION: API=1 + MASTER=1 + SCHEDULE=1
I=IDLE/READY, R=RUNNING
```

Operator buttons:

```text
SAVE SCHEDULE
START SCHEDULER
STOP SCHEDULER
RUN ONCE
REFRESH
```

`ScheduleName`, `IntervalMinutes`, and `MaxShipments` are maintainable; `ScheduleCode` remains read-only.

## START behavior

Revision 2 restores master-first startup:

1. `SMK069SetShipmentSchedulerEnabledSp(1)`
2. `SMK069SaveShipmentScheduleSp(... IsEnabled=1 ...)`
3. refresh Schedule / Dashboard / Queue

No Background Queue child form is opened, and no additional recurring TaskMan heartbeat is created.

Expected result:

```text
ApiActive     = 1
MasterEnabled = 1
IsEnabled     = 1
RunState      = I until a due run is claimed
```

## STOP behavior

1. `SMK069SetShipmentSchedulerEnabledSp(0)`
2. `SMK069SaveShipmentScheduleSp(... IsEnabled=0 ...)`
3. refresh Schedule / Dashboard / Queue

Master OFF is first so no new schedule claim can start.

A persistent TaskMan heartbeat may remain visible in Active Background Tasks; while Master/Schedule are OFF, it should complete as a no-op and must not send a Shipment.

STOP prevents new claims. It is not a hard kill of an already executing HTTP request. A true mid-request abort requires cooperative cancellation in the current tenant extension.

## Active Background Tasks versus History

These are different concepts:

```text
Background Task Definition
    = definition named SMK069ShipmentScheduler

Active Background Tasks
    = currently scheduled/queued recurring or waiting instances

Background Task History
    = instances that already executed/completed
```

The 10 Sep screenshot did not show `SMK069ShipmentScheduler` in Active Background Tasks. History did show truncated task names beginning `SMK069Sh...` for task numbers 4634 and 4631; those should be opened to confirm whether they were prior one-shot Shipment scheduler runs.

## RUN ONCE

`RUN ONCE` retains native Mongoose `ResponseType 19` after `SMK069RequestShipmentRunNowSp`. It submits the Background Task Definition immediately and therefore produces a TaskMan instance/history entry.

For UAT keep:

```text
MaxShipments = 1
```

## Credentials

POS User and Password controls are hidden in the one-form template. Local XML uses placeholders:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Real credentials must not be committed to GitHub. `Hidden=True` hides controls from operators but does not encrypt metadata or TaskMan parameters.

## Artifact generator

Repository tool:

```text
tools/shipment/convert_scheduler_one_form.py
```

Revision 2 output adds human-readable status guidance and uses START/STOP captions while preserving the one-form layout.

## Acceptance test

1. Ensure exactly one recurring TaskMan heartbeat `SMK069ShipmentScheduler` has been provisioned.
2. Import the Revision 2 one-form XML.
3. Verify POS credential controls are not visible.
4. Verify status legend is visible.
5. Set `MaxShipments=1` during UAT.
6. Press START SCHEDULER.
7. Refresh and verify `API=1`, `MASTER=1`, `SCHEDULE=1`.
8. Wait for the heartbeat or use RUN ONCE for a controlled test.
9. Press STOP SCHEDULER and verify Master/Schedule become 0.
10. Confirm no duplicate recurring TaskMan row is created by repeated START/STOP operations.
