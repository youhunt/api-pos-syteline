# Start Shipment Scheduler via TaskMan — First UAT

Date: 2026-09-08

## Confirmed IDO service surface

Tenant screenshots confirm these required methods are registered on `ue_SMK069ShipmentTransport`:

```text
SMK069GetShipmentConfigSp
SMK069GetPendingShipmentsSp
SMK069RecordShipmentAttemptSp
SMK069ClaimDueShipmentScheduleSp
SMK069CompleteShipmentScheduleSp
SMK069SendPendingShipments
SMK069RunDueShipmentSchedule
```

Existing send-path methods are also present:

```text
SMK069PrepareShipmentSendSp
SMK069CompleteShipmentSendSp
SMK069PostShipmentPayload
SMK069SendOneShipment
SMK069SendOneShipmentKacs
```

## First-UAT safety values

Before TaskMan is allowed to send:

```text
ScheduleCode = HOURLY
MaxShipments = 1
IsEnabled    = 1
```

Master scheduler config must also be enabled:

```text
SchedulerEnabled = 1
```

Current pre-UAT queue baseline:

```text
P96327 READY
P96328 READY
```

Therefore the first run must process at most one DN.

## Background Task Definition

Create a custom record on **Background Task Definitions**:

```text
Task Name       : SMK069ShipmentScheduler
Executable Type : IDOMTH
Executable Name : ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule
Max Concurrent  : 1 for first UAT
```

For IDOMTH tasks, Infor TaskMan uses the `IDO.Method` executable-name format.

Do not store POS credentials in database config or on the Scheduler form. Credentials are runtime TaskMan inputs only.

## Heartbeat design

TaskMan is only a fixed heartbeat. Suggested UAT heartbeat:

```text
Every 5 minutes
```

The business cadence remains in:

```text
ue_SMK069_shipment_schedule_mst.IntervalMinutes
```

So TaskMan may wake every 5 minutes while `HOURLY` runs only when `NextRunDate` is due.

## Important: do not manually invoke with production credentials

Do not test `SMK069RunDueShipmentSchedule` interactively from an IDO invoke form with production credentials. Mongoose method inputs can be echoed in method responses/history. Use TaskMan parameters.

## Expected first run

If the first DN succeeds:

```text
Candidates = 1
Succeeded  = 1
Failed     = 0
```

If it fails:

```text
Candidates = 1
Succeeded  = 0
Failed     = 1
```

and retry/backoff state must be updated for that DN while the second READY DN is untouched because `MaxShipments = 1`.

After the task executes, verify:

```text
Background Task History
SMK069_ShipmentSchedulerDashboard_vw
SMK069_ShipmentSchedulerQueue_vw
ue_SMK069_shipment_api_log_mst
ue_SMK069_shipment_schedule_mst Last* fields
```

Do not increase MaxShipments above 1 until this one-DN path is proven.
