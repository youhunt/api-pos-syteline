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

## Important correction: Background Queue is parent-driven

`Background Queue` is not a standalone task selector. It is a recurrence/scheduling dialog that receives the task name and the event to execute from a parent form.

Opening `Background Queue` directly therefore shows only:

```text
Once / Daily / Weekly / Monthly
Occurs At / Occurs Every
Start Date / End Date
```

and does NOT show a Task Name field.

For the custom Shipment Scheduler form, use a form event with Response Type:

```text
Run Background Task
```

Task Name:

```text
SMK069ShipmentScheduler
```

For immediate one-time execution, use Task Status `READY`.

If a recurrence dialog is desired, add a second event/menu action that opens `BackgroundQueue` as a modal child and passes the task/event context to it. Do not expect a task selector when `BackgroundQueue` is opened standalone.

## TaskMan parameter count requirement

The current extension method signature is:

```text
1 Username      IN
2 Password      IN
3 ScheduleCode  REF/OUT
4 Candidates    REF/OUT
5 Succeeded     REF/OUT
6 Failed        REF/OUT
7 Exhausted     REF/OUT
8 Infobar       REF/OUT
```

TaskMan IDOMTH invokes require a comma-delimited Task Parameters list whose item count matches the IDO method parameter count.

Observed tenant error when no/too-few Task Parameters were supplied:

```text
Too few items in the invokeParameters list for
ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule.
```

For a controlled UAT using a disposable UAT credential, supply all 8 items. To avoid trailing-empty parsing ambiguity, initialize the REF/OUT slots with harmless dummy values:

```text
<UAT_USERNAME>,<UAT_PASSWORD>,X,0,0,0,0,X
```

The runner immediately resets `ScheduleCode`, counters, and `Infobar`, so the dummy values do not affect business logic.

Do NOT use a production credential in Task Parameters because task parameters can be visible in background-task diagnostics/history.

## Credential warning

The current runner signature still has:

```text
Username IN
Password IN
```

Do NOT place production POS credentials in visible Task Parameters. Mongoose can expose background-task parameters in Active Background Tasks / task diagnostics. This supersedes the earlier wording that said TaskMan parameters were automatically a safe secret store.

Before production recurring scheduling, change the runner to obtain POS credentials from an approved secure secret/configuration mechanism, or use a dedicated UAT-only disposable credential for a controlled one-time test and rotate it immediately afterward.

Do not store a production password in the Scheduler form, plain database columns, or GitHub.

## Make the schedule eligible before testing

The TaskMan heartbeat will return cleanly without sending if the schedule is not eligible. Confirm all of these before the one-DN test:

```text
HOURLY.IsEnabled = 1
Master SchedulerEnabled = 1
MaxShipments = 1
```

For immediate testing, either mark the schedule due using `SMK069RequestShipmentRunNowSp` or ensure `NextRunDate <= current server time`.

The recommended UI action is `Run Now`, which calls `SMK069RequestShipmentRunNowSp`; do not directly update `RunRequested` in production UI code.

## Heartbeat design

TaskMan is only a fixed heartbeat. Suggested production heartbeat after credential handling is solved:

```text
Every 5 minutes
```

The business cadence remains in:

```text
ue_SMK069_shipment_schedule_mst.IntervalMinutes
```

So TaskMan may wake every 5 minutes while `HOURLY` runs only when `NextRunDate` is due.

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
