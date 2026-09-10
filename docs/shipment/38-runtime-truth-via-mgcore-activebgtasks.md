# Shipment Scheduler Runtime Truth via `MGCore.ActiveBGTasks`

Date: 2026-09-10

## Why Patch 18 SQL was withdrawn

Tenant Apply Database proved that `dbo.ActiveBGTasks` is not visible from the current Cloud application database. The guarded Patch 18 stopped before creating any view.

Do not infer that TaskMan is unavailable. In Mongoose, the actual Active Background Tasks queue is exposed through the standard IDO:

```text
MGCore.ActiveBGTasks
```

That IDO is the correct Cloud-safe source for runtime TaskMan status.

## Runtime truth model

The Shipment Scheduler form must show two separate layers:

### Business/config state

From the existing Shipment scheduler collections:

```text
ApiActive
MasterEnabled
IsEnabled
RunState
NextRunDate
```

These answer whether the custom Shipment scheduler is configured to run.

### Actual TaskMan state

From `MGCore.ActiveBGTasks`, filtered by:

```text
TaskName = 'SMK069ShipmentScheduler'
```

Minimum properties to expose/read:

```text
TaskNumber
TaskName
TaskStatusCode
```

Useful additional properties may be added only after confirming their exact names in the tenant metadata/form designer.

Task status interpretation:

```text
WAITING  = recurring/scheduled TaskMan row exists and is waiting
READY    = queued and ready for TaskMan
RUNNING  = TaskMan is processing now
no row   = no active TaskMan registration exists
```

## Recommended form status

Do not show raw `1 / 0 / I` as the primary operator status.

Show human-readable values:

```text
API SERVICE        ACTIVE / INACTIVE
MASTER CONTROL     ON / OFF
BUSINESS SCHEDULE  ENABLED / DISABLED
ACTUAL TASKMAN     NOT REGISTERED / WAITING / READY / RUNNING
```

Overall interpretation:

```text
ApiActive = 0
  -> STOPPED - API INACTIVE

MasterEnabled = 0
  -> STOPPED - MASTER OFF

IsEnabled = 0
  -> STOPPED - SCHEDULE OFF

ApiActive=1 + MasterEnabled=1 + IsEnabled=1 + no MGCore.ActiveBGTasks row
  -> MISCONFIGURED - TASKMAN NOT REGISTERED

same flags + TaskStatusCode=WAITING
  -> ACTIVE - WAITING

same flags + TaskStatusCode=READY
  -> ACTIVE - READY

same flags + TaskStatusCode=RUNNING
  -> RUNNING NOW
```

If more than one active row exists for `SMK069ShipmentScheduler`, show:

```text
WARNING - DUPLICATE TASKMAN
```

## Tenant verification before editing the final form

Use IDO Runtime / Load Collection with:

```text
IDO        : MGCore.ActiveBGTasks
Properties : TaskNumber,TaskName,TaskStatusCode
Filter     : TaskName = 'SMK069ShipmentScheduler'
```

Expected outcomes:

- one row: actual TaskMan heartbeat/instance exists;
- zero rows: no active TaskMan registration exists;
- more than one row: duplicate TaskMan registrations must be investigated.

Do not proceed to create a custom SQL view for this purpose.

## Form wiring

Add `MGCore.ActiveBGTasks` as a read-only secondary collection on `ue_SMK069ShipmentScheduler` and apply a fixed filter for `SMK069ShipmentScheduler`.

Refresh this collection on:

```text
StdFormInitCompleted
Refresh
Activate Scheduler
Deactivate Scheduler
Run Once
```

The final form should display actual TaskMan state next to the existing business/config state so operators can distinguish configuration from runtime reality.

## Security

Do not expose POS credentials in this runtime collection or status panel.
