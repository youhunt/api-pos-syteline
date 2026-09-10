# SMK069 Scheduler UI State / TaskMan Heartbeat Gap — 10 Sep 2026

## Tenant screenshot state

Operator screenshot shows:

```text
API Active       = 1
Master Engine    = 0
Schedule Enabled = 1
Run State        = I
ScheduleCode     = HOURLY
IntervalMinutes  = 10
MaxShipments     = 1
```

Interpretation:

```text
API config        ACTIVE
Business schedule ENABLED
Runner            IDLE
Effective system  STOPPED because Master Engine = 0
```

The effective run condition is:

```text
ApiActive = 1
AND MasterEnabled = 1
AND IsEnabled = 1
```

## Active Background Tasks evidence

The supplied Active Background Tasks screenshot does not show an active recurring task named `SMK069ShipmentScheduler`.

The Background Task History screenshot does show rows whose task names begin with `SMK069Sh...` (notably task numbers 4634 and 4631), which are consistent with prior one-shot/manual executions and are not proof of an active recurring heartbeat.

## Root cause of operator confusion

The one-form revision removed the interactive `BackgroundQueue(...)` child-form call from Activate. That successfully removed the second visible form, but it also means Activate no longer creates a recurring TaskMan instance.

`SMK069ShipmentScheduler` as a Background Task Definition is not the same thing as an Active Background Task recurrence instance.

The intended production architecture is therefore:

```text
TaskMan recurring heartbeat (provision once, e.g. every 5 minutes)
        -> SMK069RunDueShipmentSchedule
        -> reads MasterEnabled + schedule IsEnabled + NextRunDate
        -> sends only when due
```

Business interval remains in `ue_SMK069_shipment_schedule_mst`; TaskMan heartbeat is infrastructure and must not be recreated on every Activate click.

## UI action

Revise form labels so numeric/internal codes are explained visibly:

```text
API SERVICE
MASTER SCHEDULER
BUSINESS SCHEDULE
RUNNER STATE

RUN CONDITION: API=1 + MASTER=1 + SCHEDULE=1
I=IDLE/READY, R=RUNNING
```

Operator buttons become:

```text
SAVE SCHEDULE
START SCHEDULER
STOP SCHEDULER
RUN ONCE
```

Real POS credentials remain local/hidden only and must not be committed to GitHub.
