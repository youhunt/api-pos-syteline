# SMK069 Shipment Scheduler — Run Now vs TaskMan Heartbeat

Date: 2026-09-08

## Clarification

The `Run Now` button on `ue_SMK069ShipmentScheduler` does **not** submit a new background task by itself.

Current native form event:

- Event: `RequestRunNow`
- Method: `ue_SMK069ShipmentTransport.SMK069RequestShipmentRunNowSp`

That stored procedure only:

1. validates Master Scheduler is ON,
2. validates the schedule is enabled,
3. sets `RunRequested = 1`,
4. sets `NextRunDate = GETDATE()`.

It intentionally does not perform HTTP and does not invoke TaskMan.

## Why no Background Task History row appears

A Background Task History row appears only when TaskMan actually executes an IDOMTH task such as:

`ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule`

Therefore, if `SMK069ShipmentScheduler` is not present as an enabled recurring task in **Active Background Tasks**, pressing `Run Now` only leaves the schedule marked due. Nothing consumes it.

## Required production model

Use one recurring TaskMan heartbeat:

- Task Name: `SMK069ShipmentScheduler`
- Type: `IDOMTH`
- Executable: `ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule`
- Max Concurrent: `1`
- Recurrence: every 5 minutes (or shorter if tenant policy allows)
- Enabled: Yes

The form-managed business schedule remains independent from this heartbeat.

Example:

```text
TaskMan heartbeat every 5 minutes
        |
        v
SMK069RunDueShipmentSchedule
        |
        +-- no due schedule -> clean no-op
        |
        +-- due/RunRequested schedule -> claim HOURLY -> send max batch -> complete run
```

`Run Now` means **make HOURLY due immediately**, so the next TaskMan heartbeat takes it.

## UX wording

To avoid operator confusion, preferred label is either:

- `Run Now` with helper text `Processed on next scheduler heartbeat`, or
- `Run Next Poll`

The dashboard should also expose whether the TaskMan heartbeat is configured/active when feasible.

## Important

Do not implement direct HTTP sending in the form button. The form should not collect or expose POS credentials. The secure background runner remains the execution boundary.
