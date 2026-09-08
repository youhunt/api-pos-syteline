# SMK069 Shipment Scheduler Dashboard Rev3 No-Script — Runtime Evidence

Date: 2026-09-08

## Result

The user imported `FS_20260908_100718_dashboard_rev3_noscript.XML` and opened `ue_SMK069ShipmentScheduler` successfully without the previous form-script compile error.

## Runtime observations

The form renders the redesigned dashboard layout and the existing collections load successfully:

- Primary schedule row: `HOURLY`
- Schedule Name: `Every 60 Minutes`
- Interval Minutes: `60`
- Default Max: `50`
- Max Attempts: `5`
- Dashboard Ready count: `1`
- Waiting Retry: `0`
- Exhausted: `0`
- Success Today: `0`
- Failed Today: `0`
- Queue contains `P96329` with `READY`, AttemptCount `0`, MaxAttempts `5`

## Expected limitations in no-script revision

The following are intentionally not functional yet:

- human-readable status boxes at the top are blank because Rev3 No-Script removed the VB form script that populated them;
- action buttons are intentionally disabled until they are wired with native Mongoose `Method Call` event handlers;
- this revision is a safe UI/runtime baseline only.

## Next implementation direction

Do not reintroduce VB Form Script for the operator actions. Use native Mongoose form event handlers with `Method Call` response type for:

- `SMK069SaveShipmentScheduleSp`
- `SMK069SetShipmentSchedulerEnabledSp`
- `SMK069RequestShipmentRunNowSp`
- `SMK069ResetShipmentRetrySp`

Then chain collection refresh handlers for primary schedule, Dashboard, and Queue.

The Method Call response type is the preferred mechanism because the methods are already registered on service IDO `ue_SMK069ShipmentTransport` and Mongoose supports literal/property/variable/component parameter mappings plus output parameter mappings without requiring a form-script compile step.
