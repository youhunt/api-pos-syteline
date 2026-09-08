# SMK069 Shipment Scheduler — Native Mongoose Method Call Template / Dashboard Rev4

Date: 2026-09-08

## Tenant evidence captured

The tenant-exported form `ue_SMK069ShipmentScheduler` now contains a native Mongoose Method Call for `RequestRunNow`:

```text
ue_SMK069ShipmentTransport.SMK069RequestShipmentRunNowSp(
  PARMS(VAR P(ScheduleCode), RVAR V(Success), MESSAGE)
  ERRORMESSAGE(mBackEndMessage)
  SUCCESSMESSAGE(mBackEndMessage)
)
```

This confirms the exact serialization style used by the tenant for native Method Call event handlers. We should use this pattern instead of Form Script for scheduler control actions.

## Dashboard Rev4 design

Rev4 removes Form Script entirely and wires native events for:

- Save Settings -> `SMK069SaveShipmentScheduleSp`
- Activate -> `SMK069SetShipmentSchedulerEnabledSp(1)` then `SMK069SaveShipmentScheduleSp(..., IsEnabled=1, ...)`
- Deactivate -> `SMK069SaveShipmentScheduleSp(..., IsEnabled=0, ...)`
- Run Now -> `SMK069RequestShipmentRunNowSp`
- Refresh -> refresh primary schedule, dashboard secondary collection, and queue secondary collection

The separate Enable Engine / Disable Engine buttons are hidden from the operator UI. `Activate` automatically turns the master engine ON before activating `HOURLY`, while `Deactivate` only pauses the schedule and leaves the master engine available as an admin/global kill switch.

## Status display

Because the no-script design cannot translate values into friendly text without another mechanism, Rev4 binds status fields directly to native values:

- API Active: `0/1`
- Master Engine: `0/1`
- Schedule Enabled: `0/1`
- Run State: `I/R`
- Last Status: `N/S/W/E`

This is intentionally preferable to blank status boxes.

## Reset Retry

Reset Retry remains disabled in Rev4 until we capture the tenant's exact Method Call serialization for a selected property from Secondary Collection 3 (`ShipmentId`). Do not guess secondary-collection parameter syntax.

## UAT order

1. Import Rev4 over the current scheduler form after backup.
2. Open form and verify no Form Script compile error.
3. Click Refresh and verify Schedule + Dashboard + Queue reload.
4. Keep `Max / Run = 1`.
5. Click Activate and verify Master Engine = 1, Schedule Enabled = 1, Next Run populated.
6. Click Run Now and verify schedule is marked due.
7. Execute / wait for TaskMan heartbeat and verify Last Run + queue state.

No database patch is required for this form-only revision, assuming Patch 08 Rev2 + Patch 09 and the four dashboard control SP methods are already registered on `ue_SMK069ShipmentTransport`.
