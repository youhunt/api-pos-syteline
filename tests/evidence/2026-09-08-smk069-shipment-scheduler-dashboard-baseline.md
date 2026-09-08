# SMK069 Shipment Scheduler Dashboard — Baseline Evidence

Date: 2026-09-08
Tenant site: `Default`

## Context

Patch 08 Rev.2 and Patch 09 were applied successfully in the SyteLine tenant.
Because this tenant's Apply Database / Query Select tools do not behave like SSMS for multi-statement batches and OUTPUT-parameter verification, the dashboard was verified through:

```text
dbo.SMK069_ShipmentSchedulerDashboard_vw
```

## Observed result

```text
SiteRef                 Default
MasterEnabled           0
ApiActive               1
ScheduleCount           1
ActiveScheduleCount     0
NextRunDate             NULL
DefaultMaxBatchSize     50
MaxAttempts             5
ReadyCount              2
WaitingBackoffCount     0
ExhaustedCount          0
SucceededToday          0
FailedToday             0
```

## Interpretation

This is the expected pre-UAT baseline:

- Shipment API config exists and is active.
- Master scheduler remains OFF, so no automatic shipment should be sent yet.
- One schedule definition exists (the seeded HOURLY schedule).
- No schedule is active yet.
- Default maximum shipments per run is parameterized at 50.
- Retry budget is parameterized at 5 attempts.
- Two Shipment DN candidates are currently READY for processing.
- No Shipment is waiting for retry backoff or exhausted.
- No scheduler success/failure attempt has been recorded today.

## Next verification

Apply separately:

```text
database/patches/2026-09-08-smk069-10b-shipment-scheduler-queue-view.sql
```

Then inspect:

```text
dbo.SMK069_ShipmentSchedulerQueue_vw
```

Expected at this point: two rows with `QueueStatus = READY`, assuming the underlying Shipment data does not change between checks.

Do not enable the master scheduler or HOURLY schedule yet. Keep UAT disabled until the queue rows are verified and the Control Center IDO/form wiring is ready.
