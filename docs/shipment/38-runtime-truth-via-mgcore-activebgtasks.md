# Shipment Scheduler Runtime Truth via `ActiveBGTasks`

Date: 2026-09-10

## Tenant evidence

Two runtime checks are now confirmed.

### SQL path is not available

Apply Database proved that `dbo.ActiveBGTasks` is not visible from this Cloud application database. The guarded Patch 18 stopped before creating any view and has been converted to a withdrawn/no-op file.

### Mongoose IDO path is available

IDO Runtime / Load Collection successfully loaded the standard Mongoose IDO:

```text
ActiveBGTasks
```

with properties:

```text
TaskNumber
TaskName
TaskStatusCode
```

and filter:

```text
TaskName = 'SMK069ShipmentScheduler'
```

Tenant result on 10 Sep 2026:

```text
0 actual rows
```

The blank `*` row in the Load Collection form is only the insert/placeholder row. Therefore, at the time of verification, **no actual `SMK069ShipmentScheduler` task was registered in Active Background Tasks**.

Evidence:

```text
tests/evidence/2026-09-10-smk069-activebgtasks-zero-row.md
```

## Runtime truth model

The Shipment Scheduler form must combine two different sources.

Business/config state:

```text
ApiActive
MasterEnabled
IsEnabled
RunState
NextRunDate
```

Actual TaskMan state:

```text
ActiveBGTasks
  permanent filter: TaskName = 'SMK069ShipmentScheduler'
```

The form must never infer actual TaskMan registration only from the custom Shipment tables.

## Final status panel

Primary operator status must be human-readable:

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

Expected examples:

```text
no ActiveBGTasks row
  -> TASKMAN HEARTBEAT = NOT REGISTERED
  -> TASK STATUS = -
  -> TASK NUMBER = -
  -> OVERALL = STOPPED - TASKMAN NOT REGISTERED

one WAITING row
  -> TASKMAN HEARTBEAT = REGISTERED
  -> TASK STATUS = WAITING
  -> OVERALL = ACTIVE - WAITING      (when API/Master/Schedule are ON)

one READY row
  -> TASK STATUS = READY
  -> OVERALL = ACTIVE - READY        (when API/Master/Schedule are ON)

one RUNNING row
  -> TASK STATUS = RUNNING
  -> OVERALL = RUNNING NOW           (when API/Master/Schedule are ON)

more than one matching ActiveBGTasks row
  -> TASKMAN HEARTBEAT = DUPLICATE (n)
  -> OVERALL = WARNING - DUPLICATE SCHEDULER
```

Business `RunState` remains visible as a translated `IDLE` / `RUNNING` value, but it is not accepted as proof that TaskMan itself is running.

## Final one-form collection architecture

```text
ue_SMK069ShipmentScheduler
│
├── object  : ue_SMK069ShipmentSchedules
├── object2 : ue_SMK069ShipmentSchedulerDashboard
├── object3 : ue_SMK069ShipmentSchedulerQueue
└── object4 : ActiveBGTasks
              FILTERPERM(TaskName = 'SMK069ShipmentScheduler')
```

The uploaded tenant form `FS_20260910_065349.XML` already contains `V(fds_SC4)` and the filtered `ActiveBGTasks` secondary collection, but its visible status fields were still bound to custom table values and its START/STOP handlers still changed only business/master flags. The final artifact rewires both parts.

## START SCHEDULER behavior

`START SCHEDULER` must perform an actual TaskMan acceptance check.

Flow:

```text
refresh ActiveBGTasks
      ↓
0 matching rows?
      ├─ yes -> submit SMK069ShipmentScheduler as WAITING
      │         configure it as recurring heartbeat through standard
      │         SLJobQueues.BackGroundQueue2Sp
      │
      └─ no  -> reuse the existing single task
      ↓
more than 1 matching row?
      ├─ yes -> STOP, show duplicate warning
      └─ no
      ↓
confirm exactly 1 actual TaskMan row exists
      ↓
enable business schedule
      ↓
enable master scheduler
      ↓
refresh all collections and recompute runtime status
```

The recurring heartbeat is configured every 5 minutes. This is intentionally **not** the Shipment business interval. The business interval remains owned by `IntervalMinutes` / `NextRunDate`; the heartbeat merely polls for due schedules.

The recurring setup reproduces the standard Mongoose Background Queue pattern already captured from the tenant export:

```text
1. submit the background task with status WAITING
2. receive TaskNumber
3. call SLJobQueues.BackGroundQueue2Sp for recurrence
```

No second operator-facing Background Queue form is required.

## STOP SCHEDULER behavior

STOP is deliberately safety-first:

```text
1. Master Scheduler OFF
2. Business Schedule OFF
3. refresh ActiveBGTasks
4. delete matching WAITING heartbeat row(s)
5. save ActiveBGTasks
6. refresh and recompute runtime truth
```

Mongoose/TaskMan does not allow a normal Active Background Tasks delete of a task that is already `READY` or `RUNNING`. In that case the form leaves the in-flight invocation alone, but the master/business switches are already OFF so no new Shipment schedule claim should begin. When the recurring task returns to `WAITING`, STOP can be pressed again to remove it.

A future cooperative-cancel patch may stop a multi-DN sender between individual DN sends, but that is separate from deleting the TaskMan row and must only be implemented against the current tenant extension source.

## Final artifact

Conversation artifact generated from the user's current tenant export:

```text
SMK069ShipmentScheduler_ONE_FORM_FINAL_RUNTIME_TRUTH.xml
```

It contains:

- direct `ActiveBGTasks` runtime status;
- human-readable status variables;
- duplicate detection;
- actual TaskNumber / TaskStatus display;
- START that creates/checks a recurring TaskMan heartbeat before turning business/master ON;
- STOP that turns business/master OFF then deletes WAITING heartbeat rows;
- existing Run Once behavior;
- hidden POS credential placeholders only.

## Security

Real POS credentials must not be committed to Git. The form artifact uses:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

If UAT requires hardcoded form credentials, replace those placeholders only in the local XML before import. `Hidden=True` is UI hiding, not encryption; values can still be recovered from form metadata/export and may be visible in TaskMan parameters/history.

## Acceptance test

1. Keep a backup/export of the current form.
2. Replace local credential placeholders if required for UAT.
3. Import the final one-form XML.
4. Open the form while `ActiveBGTasks` has zero matching rows; verify `TASKMAN HEARTBEAT = NOT REGISTERED`.
5. Set `Max / Run = 1` for the controlled UAT.
6. Press `START SCHEDULER` once.
7. Verify exactly one `SMK069ShipmentScheduler` row appears in Active Background Tasks.
8. Verify form status becomes `REGISTERED` and normally `WAITING` after setup.
9. Press `STOP SCHEDULER`; verify master/business are OFF and the WAITING ActiveBGTasks row disappears.
10. Do not process P96330/P96332 until the controlled P96331 lifecycle is reviewed.
