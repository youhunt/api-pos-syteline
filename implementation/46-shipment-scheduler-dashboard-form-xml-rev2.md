# Shipment Scheduler Dashboard Form — XML Revision 2

Date: 2026-09-08

## Source export

Tenant export supplied by the user:

```text
FS_20260908_100718.XML
Form: ue_SMK069ShipmentScheduler
```

The export confirmed:

- Primary collection: `ue_SMK069ShipmentSchedules`
- Secondary collection 2: `ue_SMK069ShipmentSchedulerDashboard`
- Secondary collection 3: `ue_SMK069ShipmentSchedulerQueue`
- secondary dashboard + queue refresh handlers already existed on `StdFormInitCompleted`
- the original UAT task button was still present and the form layout was still a raw field layout rather than an operational dashboard

## Revised artifact

Generated artifact:

```text
FS_20260908_100718_dashboard_rev2.XML
SHA-256: bb8777519a6fb2b57db30b7065eb0689739bfdce8c825648782abbefcd9f25f6
```

The generated XML is well-formed and keeps the same form name:

```text
ue_SMK069ShipmentScheduler
```

## Dashboard layout

Revision 2 reorganizes the form into four operational areas:

```text
SYSTEM STATUS
SCHEDULE CONTROL
LAST RUN
SHIPMENT QUEUE
```

### System Status

Shows readable status text instead of forcing operators to interpret raw 0/1 values:

```text
API               ACTIVE / INACTIVE
Scheduler Engine  ON / OFF
Schedule          ACTIVE / PAUSED
Run State         IDLE / RUNNING
```

Also shows these KPI values:

```text
Ready
Waiting Retry
Exhausted
Success Today
Failed Today
```

### Schedule Control

The UI intentionally treats the tenant's `HOURLY` row as the operational schedule and does not expose create/delete schedule actions.

Visible controls:

```text
Schedule Code       read-only
Schedule Name       read-only
Interval Minutes    editable
Max / Run           editable
Default Max         read-only
Max Attempts        read-only
Next Run            read-only
```

Actions:

```text
Save Settings
Activate
Deactivate
Run Now
```

### Last Run

Displays:

```text
LastRunDate
LastRunStatus as NEVER / SUCCESS / WARNING / ERROR
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

### Shipment Queue

Queue grid is read-only and now includes:

```text
DN No
Queue Status
Attempts
Max Attempts
Next Retry
HTTP
Last Error
```

A controlled `Reset Retry` action is provided.

## Form-script actions

Revision 2 adds a form script and uses form-script event handlers for operator actions.

Service IDO:

```text
ue_SMK069ShipmentTransport
```

Methods expected by the form:

```text
SMK069SaveShipmentScheduleSp
SMK069SetShipmentSchedulerEnabledSp
SMK069RequestShipmentRunNowSp
SMK069ResetShipmentRetrySp
```

These Patch 09 procedures must be registered as Stored Procedure - Standard Method methods on `ue_SMK069ShipmentTransport` before the related buttons are used.

The script validates:

```text
IntervalMinutes 1..10080
MaxShipments > 0 or blank
```

After every action it refreshes:

```text
Primary schedule
Dashboard secondary collection
Queue secondary collection
```

## Run Now behavior

`Run Now` does NOT perform HTTP from the form.

It calls:

```text
SMK069RequestShipmentRunNowSp
```

which marks the active schedule due. The TaskMan heartbeat remains responsible for invoking:

```text
ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule
```

This keeps scheduler control separate from the HTTP transport execution.

## Security correction

The revised XML removes the previous direct UAT `Run Background Task` form event and does not embed POS username/password in the form export.

Production credentials must not be stored in the form XML, source repository, visible form variables, or plain Task Parameters.

## Import / test order

```text
1. Back up/export current ue_SMK069ShipmentScheduler.
2. Register the four Patch 09 control SP methods listed above if not yet registered.
3. Import FS_20260908_100718_dashboard_rev2.XML.
4. Open the form and verify Dashboard + Queue auto-load.
5. Test Refresh.
6. Test Save Settings with Max / Run = 1.
7. Enable Scheduler Engine.
8. Activate HOURLY.
9. Verify Next Run is populated.
10. Run Now and verify RunRequested/NextRunDate changes.
11. Let the TaskMan heartbeat execute the due schedule.
12. Verify Last Run and Queue state after the heartbeat.
```

Do not raise `MaxShipments` above 1 until the first controlled DN UAT succeeds end to end.
