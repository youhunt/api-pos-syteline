# Rebuild Shipment Scheduler Dashboard UI and Actions

Date: 2026-09-08

This is the practical build sequence for the current tenant form `SMK069ShipmentScheduler`.

## Goal

Turn the current proof-of-data form into an operator dashboard without recreating the form or adding another splitter.

## Existing Collections

```text
Primary : ue_SMK069ShipmentSchedules
Secondary 2 : ue_SMK069ShipmentSchedulerDashboard
Secondary 3 : ue_SMK069ShipmentSchedulerQueue
```

## Step 1 — Re-arrange the current components

Create visual group headings with labels / rectangles / group boxes if available:

```text
SYSTEM STATUS
SCHEDULE CONTROL
LAST RUN
SHIPMENT QUEUE
```

Do not expose `IsEnabled` as a numeric 0/1 input in the final UI.

Keep hidden/bound components if they are needed by event parameters.

## Step 2 — Top System Status

Read-only components:

```text
API Status      <- Dashboard.ApiActive
Master Status   <- Dashboard.MasterEnabled
Next Run        <- Schedule.NextRunDate
Last Run        <- Schedule.LastRunDate
```

Suggested text mapping:

```text
ApiActive 1 -> ACTIVE
ApiActive 0 -> INACTIVE

MasterEnabled 1 -> SYSTEM ON
MasterEnabled 0 -> SYSTEM OFF
```

If conditional colors are easy in the tenant:

```text
ACTIVE / SYSTEM ON -> green
OFF / ERROR        -> red
WAITING            -> amber
```

Text labels must remain visible even without color.

## Step 3 — Schedule Control

Fields:

```text
Schedule Code     read-only
Schedule Name     read-only
Interval Minutes  editable
Max Shipments     editable
Run State         read-only
```

Small policy text:

```text
Default Max / Run : Dashboard.DefaultMaxBatchSize
Max Attempts      : Dashboard.MaxAttempts
```

Buttons:

```text
Save Settings
Activate
Deactivate
Run Now
Refresh
```

## Step 4 — Last Run card

Add components bound to:

```text
LastRunStatus
LastRunDate
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

Do not rely on Background Task History to communicate business result.

## Step 5 — Queue KPI row

Read-only dashboard values:

```text
ReadyCount
WaitingBackoffCount
ExhaustedCount
SucceededToday
FailedToday
```

Use large numeric fields or labels if possible.

## Step 6 — Queue grid

Columns:

```text
ShipmentId
QueueStatus
AttemptCount
MaxAttempts
NextAttemptDate
LastHttpCode
LastError
```

`AttemptCount` is required and was missing from an earlier form iteration.

## Step 7 — Register remaining control SP methods if not already registered

On `ue_SMK069ShipmentTransport` register:

```text
SMK069SaveShipmentScheduleSp
SMK069SetShipmentSchedulerEnabledSp
SMK069RequestShipmentRunNowSp
```

Use Stored Procedure - Standard Method and Resync Parameters.

## Step 8 — Save Settings action

Invoke:

```text
SMK069SaveShipmentScheduleSp
```

Inputs:

```text
ScheduleCode    = primary.ScheduleCode
ScheduleName    = primary.ScheduleName
IntervalMinutes = primary.IntervalMinutes
MaxShipments    = primary.MaxShipments
IsEnabled       = primary.IsEnabled
StartAt         = NULL
```

Outputs:

```text
Success
Infobar
```

After success refresh primary + dashboard + queue.

## Step 9 — Activate action

Do not direct-update the database row.

Event chain:

```text
Set IsEnabled component/property to 1
Invoke SMK069SaveShipmentScheduleSp using current settings
Refresh primary
Refresh Dashboard
Refresh Queue
```

Expected result after activation:

```text
IsEnabled   = 1
NextRunDate = calculated by server
```

Keep `MaxShipments = 1` for first live UAT.

## Step 10 — Deactivate action

Event chain:

```text
Set IsEnabled to 0
Invoke SMK069SaveShipmentScheduleSp
Refresh all collections
```

Expected:

```text
IsEnabled    = 0
NextRunDate  = NULL
RunRequested = 0
RunState     = I
```

## Step 11 — Master admin switch

For UAT, register/use:

```text
SMK069SetShipmentSchedulerEnabledSp
```

Input:

```text
Enabled = 1
```

Once UAT is complete, MasterEnabled normally stays 1. Operator should use Activate/Deactivate on HOURLY instead.

If MasterEnabled = 0, the dashboard should clearly say:

```text
SYSTEM DISABLED BY ADMIN
```

Run Now must not be available.

## Step 12 — Run Now

Final operator action invokes:

```text
SMK069RequestShipmentRunNowSp
```

Input:

```text
ScheduleCode = HOURLY
```

It does not call HTTP. It sets the schedule due immediately.

Production TaskMan heartbeat will later call:

```text
ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule
```

Run Now should be enabled only when MasterEnabled=1, IsEnabled=1, RunState<>R.

## Step 13 — Refresh button

Refresh sequence:

```text
Refresh Primary Collection
Refresh Secondary Collection 2 (Dashboard)
Refresh Secondary Collection 3 (Queue)
```

The same secondary refreshes should occur after form initialization.

## Step 14 — Current UAT target

Before the first real Shipment send:

```text
MasterEnabled = 1
IsEnabled     = 1
MaxShipments  = 1
ReadyCount    >= 1
```

Current observed READY Shipment:

```text
P96329
```

After Run Now + next TaskMan heartbeat, prove the business execution through:

```text
LastRunDate populated
LastCandidates = 1
LastSucceeded / LastFailed updated
Queue row changes or disappears
Retry state updates if failed
```

A TaskMan `Task Succeeded` with `LastCandidates=0` is only a successful no-op, not a successful Shipment transmission.
