# SMK069 Shipment Scheduler - Final UI Semantics for Run Now vs Activate

Date: 2026-09-08

## Decision

The dashboard buttons must have different operational meanings:

### Run Now

`Run Now` means **submit one background task immediately**.

Use the native Mongoose event response type **Run Background Task** (`ResponseType 19`) against Background Task Definition:

- Task Name: `SMK069ShipmentScheduler`
- Executable Type: `IDOMTH`
- Executable: `ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule`
- Task Status: `READY`

Expected behavior:

1. User clicks Run Now.
2. A READY background task is inserted into Active Background Tasks.
3. TaskMan executes it as soon as possible.
4. The execution is visible in Background Task History after completion.
5. This is a one-time execution only; it does not create a recurring schedule.

The old `SMK069RequestShipmentRunNowSp` behavior only marked `RunRequested=1` / `NextRunDate=GETDATE()` and depended on a later heartbeat. That behavior is not the intended UX for the dashboard button named `Run Now`.

### Activate

`Activate` means **enable the recurring Shipment scheduler**, not merely run one job.

Application/business state:

- Master scheduler ON.
- `HOURLY.IsEnabled = 1`.
- `NextRunDate` is calculated by `SMK069SaveShipmentScheduleSp`.

Infrastructure state:

- A recurring TaskMan task named `SMK069ShipmentScheduler` must already exist and be enabled in Active Background Tasks / Background Queue (recommended heartbeat every 5 minutes).
- The heartbeat itself is infrastructure and should normally remain active. The HOURLY row decides whether Shipment processing is enabled.

This avoids creating duplicate recurring Active Background Task rows each time the operator clicks Activate.

### Deactivate

`Deactivate` sets `HOURLY.IsEnabled = 0` and clears/neutralizes the application schedule. It does not have to delete the infrastructure heartbeat task.

### Why the recurring heartbeat remains separate

Mongoose `Run Background Task` with `READY` submits an immediate one-time task. Recurrence is configured using Background Queue / Active Background Tasks, not by the normal Run Background Task response parameters.

Therefore the dashboard should not attempt to create a new recurring TaskMan row every time Activate is clicked.

## Security constraint

The current extension method `SMK069RunDueShipmentSchedule` still accepts POS `Username` and `Password` as input parameters. A Mongoose Run Background Task response serializes task parameters into the task record and they can be visible in task diagnostics/history/exported form XML.

Do **not** hardcode production POS credentials in a form XML/event definition.

Before productionizing direct one-time Run Now, choose one of these:

1. provide a secure server-side credential source and refactor the background method so the form does not submit credentials, or
2. for controlled UAT only, use disposable UAT credentials and rotate them after testing.

The repository/form must never contain production credentials.

## Final UX

- `Save Settings`: save Interval and Max Shipments.
- `Activate`: Master ON + HOURLY enabled.
- `Deactivate`: HOURLY disabled.
- `Run Now`: direct one-time Run Background Task submission.
- `Refresh`: refresh schedule/dashboard/queue.
- `Reset Retry`: reset selected DN retry state.

## Evidence from tenant export

The earlier tenant export already showed native Mongoose Run Background Task serialization with `ResponseType 19`, confirming this response type is supported in the tenant. Any old UAT credentials embedded in that export must not be copied into production form definitions.
