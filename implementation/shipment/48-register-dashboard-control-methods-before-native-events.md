# Register dashboard control methods before native form events

Date: 2026-09-08

## Tenant evidence

The `ue_SMK069ShipmentTransport` Method Call dropdown currently contains the existing scheduler/runtime methods, including:

- `SMK069ClaimDueShipmentScheduleSp`
- `SMK069CompleteShipmentScheduleSp`
- `SMK069GetPendingShipmentsSp`
- `SMK069GetShipmentConfigSp`
- `SMK069RecordShipmentAttemptSp`
- `SMK069RunDueShipmentSchedule`
- shipment sender methods

It does **not** yet contain the four operator-control procedures introduced by Patch 09:

- `SMK069SaveShipmentScheduleSp`
- `SMK069SetShipmentSchedulerEnabledSp`
- `SMK069RequestShipmentRunNowSp`
- `SMK069ResetShipmentRetrySp`

Patch 09 creates these SQL procedures, but applying the SQL does not automatically register them as methods on the Mongoose service IDO. They must be added to `ue_SMK069ShipmentTransport` as `Stored Procedure - Standard Method` methods before native form Method Call events can reference them.

## Required metadata

### SMK069RequestShipmentRunNowSp

1. `ScheduleCode` IN
2. `Success` OUT
3. `Infobar` OUT

### SMK069ResetShipmentRetrySp

1. `DN_No` IN
2. `Success` OUT
3. `Infobar` OUT

### SMK069SetShipmentSchedulerEnabledSp

1. `Enabled` IN
2. `Success` OUT
3. `Infobar` OUT

### SMK069SaveShipmentScheduleSp

1. `ScheduleCode` IN
2. `ScheduleName` IN
3. `IntervalMinutes` IN
4. `MaxShipments` IN
5. `IsEnabled` IN
6. `StartAt` IN
7. `Success` OUT
8. `Infobar` OUT

After registering, save the IDO and refresh metadata/cache if the Method Call dropdown does not immediately show the new methods.

## Form implementation rule

Do not wire `Run Now`, `Activate`, `Deactivate`, `Save Settings`, `Enable/Disable Engine`, or `Reset Retry` until their corresponding IDO methods are present in the dropdown.
