# SMK069 Shipment Scheduler — Dashboard Rev.5 Background Task Wiring

Date: 2026-09-09

## Source

This revision was generated from tenant export `FS_20260909_014506.XML` for form `ue_SMK069ShipmentScheduler`.

## Final button semantics implemented

### Run Now

`Run Now` is a direct one-time execution.

Flow:

1. Call `SMK069RequestShipmentRunNowSp` to force the `HOURLY` schedule due now.
2. Submit Background Task Definition `SMK069ShipmentScheduler` using native Mongoose **Run Background Task** (`ResponseType 19`).
3. Submit it with `TASKSTATUS(READY)` so TaskMan runs it as soon as possible.
4. Refresh Schedule, Dashboard, and Queue collections.

This means the run should appear briefly in Active Background Tasks and then in Background Task History after completion.

### Activate / Schedule

`Activate / Schedule` is for recurring operation.

Flow:

1. Set Master Shipment Scheduler ON through `SMK069SetShipmentSchedulerEnabledSp`.
2. Enable `HOURLY` through `SMK069SaveShipmentScheduleSp`.
3. Open the standard Mongoose `BackgroundQueue` modal child.
4. The Background Queue uses `SubmitSchedulerScheduled` as its RunTaskEvent, allowing the user to configure recurrence and create the scheduled Active Background Task.

Recommended recurrence for scheduler heartbeat: every 5 minutes, Max Concurrent = 1.

### Deactivate

For the current single-schedule design:

1. Disable `HOURLY`.
2. Set Master Shipment Scheduler OFF.
3. Refresh all dashboard collections.

A recurring Active Background Task row may remain scheduled in Mongoose, but with Master/Schedule OFF the runner will return a clean no-op and will not send Shipments.

## Runtime POS credentials

The current extension method `SMK069RunDueShipmentSchedule` still requires:

1. Username
2. Password
3. ScheduleCode OUT
4. Candidates OUT
5. Succeeded OUT
6. Failed OUT
7. Exhausted OUT
8. Infobar OUT

Rev.5 therefore introduces runtime-only form variables/components:

- `POSUsername`
- `POSPassword`

They are blank in the XML and are not hardcoded in the repository.

Both one-time and recurring TaskMan submissions use:

`V(POSUsername),V(POSPassword),X,0,0,0,0,X`

Important: TaskMan stores task parameters in Active Background Tasks / history diagnostics. This is acceptable only for controlled UAT credentials. Production hardening should move POS credentials to a secure server-side source and remove them from task parameters entirely.

## Native Mongoose events

- `SubmitSchedulerScheduled` — ResponseType 19, used by Background Queue recurrence.
- `RunNowOnce` — mark due + ResponseType 19 READY submission.
- `ActivateSchedule` — Master ON + HOURLY ON + ResponseType 3 BackgroundQueue modal child.
- `DeactivateSchedule` — HOURLY OFF + Master OFF.
- `SaveScheduleSettings` — save current settings.
- `RefreshDashboard` — refresh object/object2/object3.

## Form artifact

Generated local artifact:

`FS_20260909_014506_dashboard_rev5_background_tasks.XML`

The XML was parsed successfully after generation.

## UAT sequence

1. Import Rev.5 form XML.
2. Enter UAT POS User and POS Password in the runtime credential fields.
3. Set Max / Run = 1.
4. Click `Activate / Schedule`.
5. In Background Queue choose recurrence, recommended every 5 minutes, then save.
6. Verify `SMK069ShipmentScheduler` appears in Active Background Tasks.
7. Click `Run Now` for a separate one-time immediate task.
8. Verify the task appears in Background Task History.
9. Refresh the dashboard and confirm Last Run / Candidates / Success / Failure / Queue state.
