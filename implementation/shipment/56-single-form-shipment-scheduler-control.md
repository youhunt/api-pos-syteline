# 56 — Single-Form Shipment Scheduler Control

Date: 2026-09-10

## Source evidence

Tenant form export reviewed: `FS_20260910_040209.XML`.

The export contains two forms:

- `ue_SMK069_BackgroundQueue`
- `ue_SMK069ShipmentScheduler`

The operator-facing `ue_SMK069ShipmentScheduler` currently opens `BackgroundQueue(...)` from `ActivateSchedule`. That child form is therefore the reason activation becomes a two-form workflow.

The same main form already has all business controls needed for the single-schedule model: ScheduleCode, ScheduleName, IntervalMinutes, MaxShipments, Activate, Deactivate, Run Now, status, and retry queue.

## New operator decision

Use only one operator-facing form:

```text
ue_SMK069ShipmentScheduler
```

The Background Task Definition remains:

```text
SMK069ShipmentScheduler
```

TaskMan is treated as a persistent heartbeat. The form-defined business schedule owns the actual send cadence through `ue_SMK069_shipment_schedule_mst` / `IntervalMinutes` / `NextRunDate`.

Do not create another recurring TaskMan row every time the operator presses Activate.

## Activate behavior

`Activate Scheduler` should execute in this order:

1. `SMK069SaveShipmentScheduleSp(... IsEnabled=1 ...)`
2. `SMK069SetShipmentSchedulerEnabledSp(1, ...)`
3. refresh Schedule, Dashboard, Queue

The previous `BackgroundQueue(...)` child-form call is removed.

Saving the schedule before switching the master ON reduces the window where TaskMan could see an enabled master with stale schedule settings.

## Deactivate behavior

`Deactivate Scheduler` should execute in this order:

1. `SMK069SetShipmentSchedulerEnabledSp(0, ...)`
2. `SMK069SaveShipmentScheduleSp(... IsEnabled=0 ...)`
3. refresh Schedule, Dashboard, Queue

Master OFF is intentionally first so no new schedule claim can start while the schedule row is being disabled.

A persistent recurring TaskMan heartbeat may remain registered. With Master/Schedule OFF, the runner is a no-op and sends no new Shipment.

### Important limitation

Deactivate prevents **new claims/runs**. It is not a hard kill for an HTTP request that has already been claimed and is executing. A true mid-run abort requires separate cooperative-cancellation logic in the current tenant extension and must not be implemented from stale repo source without tenant evidence.

## Modify existing schedule

The existing `Save Settings` event remains the maintenance path for:

- `ScheduleName`
- `IntervalMinutes`
- `MaxShipments`

`ScheduleCode` remains read-only.

For the one-form XML template, `ScheduleName` is made editable so the existing schedule can be maintained without a second form.

## Run Now

Current tenant form uses native Mongoose `ResponseType 19` after `SMK069RequestShipmentRunNowSp`, submitting Background Task Definition `SMK069ShipmentScheduler` immediately.

That mechanism may remain for an explicit one-time run. It does not create the recurring schedule dialog.

## Credentials

Current export exposes POS User and POS Password controls and stores blank form variables. The one-form template hides both labels and editors and makes the editors read-only.

The generated template intentionally contains placeholders only:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Real credentials must **not** be committed to GitHub. If the UAT operator insists on hardcoding them in the form, replace the placeholders only in the local XML before import.

Important: `Hidden=True` is UI hiding, not secret storage. Values can still be recovered from form metadata/export and may also appear in TaskMan parameters/history. Long-term production hardening should resolve credentials server-side instead of putting them in form XML or TaskMan parameters.

## Generated conversation artifact

Generated from the tenant export:

```text
SMK069ShipmentScheduler_ONE_FORM_TEMPLATE.xml
```

Changes applied:

- only `ue_SMK069ShipmentScheduler` remains in the export;
- `ue_SMK069_BackgroundQueue` removed;
- `ActivateSchedule` no longer opens BackgroundQueue;
- Activate order changed to Schedule ON -> Master ON;
- Deactivate order changed to Master OFF -> Schedule OFF;
- ScheduleName made editable;
- POS username/password labels and editors hidden;
- hidden credential variables use non-secret placeholders;
- `SubmitSchedulerScheduled` event removed because the child recurring-dialog path is no longer used;
- existing `RunNowOnce` native TaskMan submission retained for explicit one-time execution.

## Acceptance test

1. Import the one-form XML in a UAT scope.
2. Verify only `ue_SMK069ShipmentScheduler` is included by the import artifact.
3. If using form-hardcoded UAT credentials, replace placeholders locally before import.
4. Open the form; POS credential controls must not be visible.
5. Change IntervalMinutes / MaxShipments and press Save Settings; verify values persist.
6. Press Activate Scheduler; no Background Queue child form should open.
7. Verify MasterEnabled=1 and IsEnabled=1, and NextRunDate is calculated.
8. Press Deactivate Scheduler; verify MasterEnabled=0 and IsEnabled=0.
9. Confirm the existing persistent TaskMan heartbeat may still appear, but it must not send while Master/Schedule are OFF.
10. For Run Once, use MaxShipments=1 during UAT and verify Background Task History plus Shipment API log/retry state.
