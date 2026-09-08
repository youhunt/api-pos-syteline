# Build Minimum Shipment Scheduler Form in SyteLine Tenant

Date: 2026-09-08

Goal: get a visible, demonstrable Shipment Scheduler form on screen before wiring TaskMan/HTTP automation.

## Confirmed prerequisite IDOs

```text
ue_SMK069ShipmentSchedules
ue_SMK069ShipmentApiConfigs
ue_SMK069ShipmentSchedulerDashboard
ue_SMK069ShipmentSchedulerQueue
```

The current verified tenant queue is:

```text
Default | P96327 | 0 | 5 | P | READY
Default | P96328 | 0 | 5 | P | READY
```

The scheduler must remain OFF during this form-build milestone.

## Important: collection relationship model

The four collections on this form are **not** a master-detail chain.

They represent different views of the same Site-level Shipment Scheduler subsystem:

```text
Schedules  = schedule definitions for the Site
Dashboard  = aggregate Site-level scheduler status
Queue      = all eligible/pending Shipment DN for the Site
Config     = SHIPMENT API/scheduler configuration for the Site
```

Therefore:

- do **not** link Queue to the selected Schedule;
- do **not** link Dashboard to the selected Schedule;
- do **not** make Config a child of one Schedule;
- all of them may load independently on the same form;
- each collection must be constrained by the current `SiteRef`;
- Config must additionally be constrained to `ApiName = 'SHIPMENT'`.

This is intentional. Every active schedule consumes the same Site-level Shipment queue. A DN does not belong to one specific schedule.

For current UAT evidence the Site is `Default`. If the tenant form expression for the current Site has not yet been confirmed, using a temporary `SiteRef = 'Default'` collection filter is acceptable for this UAT form only; replace it with the current-site expression before production/multi-site rollout.

## 1. Create the base form

Use the Form Wizard / New Form flow.

```text
Form Name          : SMK069ShipmentScheduler
Caption            : Shipment Scheduler Control Center
Primary Collection : ue_SMK069ShipmentSchedules
Form Type          : MultiView if available; otherwise use a standard detail/grid form that can be edited in Design Mode
Device Type        : Any
```

Use the existing custom project/scope used by SMK069 tenant customizations.

Do not create a new database object from the Form Wizard.

Primary Schedule collection filter for current UAT:

```text
SiteRef = Default
```

## 2. Primary Schedule fields for first visible version

Show these fields first:

```text
ScheduleCode
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
NextRunDate
RunState
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

Keep these system-managed fields read-only:

```text
ScheduleCode       (read-only after creation for the seeded HOURLY row)
NextRunDate
RunState
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

For the first visible milestone, it is acceptable for `ScheduleName`, `IntervalMinutes`, `MaxShipments`, and `IsEnabled` to be displayed even before the controlled Save method is wired. Do not use the form to enable production execution yet.

Expected seeded row:

```text
ScheduleCode     = HOURLY
ScheduleName     = Every 60 Minutes
IntervalMinutes  = 60
MaxShipments     = blank
IsEnabled        = 0
RunState         = I
LastRunStatus    = N
```

## 3. Add Dashboard independent collection

In Design Mode add a collection using:

```text
IDO : ue_SMK069ShipmentSchedulerDashboard
```

This is an **independent Site-level collection**, not a child of Schedule.

Current UAT filter:

```text
SiteRef = Default
```

Bind visible components to:

```text
MasterEnabled
ApiActive
DefaultMaxBatchSize
MaxAttempts
ReadyCount
WaitingBackoffCount
ExhaustedCount
SucceededToday
FailedToday
NextRunDate
```

Recommended labels:

```text
Master Scheduler
API Active
Default Max / Run
Max Attempts
Ready
Waiting Retry
Exhausted
Success Today
Failed Today
Next Run
```

Current expected values:

```text
Master Scheduler = 0 / OFF
API Active       = 1 / ACTIVE
Default Max/Run  = 50
Max Attempts     = 5
Ready            = 2
Waiting Retry    = 0
Exhausted        = 0
```

## 4. Add Queue independent collection/grid

Add another collection:

```text
IDO : ue_SMK069ShipmentSchedulerQueue
```

This is also an **independent Site-level collection**. It must show the whole current Shipment queue for the Site, regardless of which schedule row is selected.

Current UAT filter:

```text
SiteRef = Default
```

Display a read-only grid with:

```text
ShipmentId
QueueStatus
AttemptCount
MaxAttempts
RetryState
NextAttemptDate
LastHttpCode
LastError
```

Recommended first columns:

```text
DN No
Status
Attempts
Max Attempts
Retry After
HTTP
Last Error
```

Expected current rows:

```text
P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

This grid is read-only. Do not allow direct editing of retry state.

## 5. Configuration independent collection/tab

Use:

```text
IDO : ue_SMK069ShipmentApiConfigs
```

This is not linked to the selected Schedule. It represents the Site-level SHIPMENT configuration.

Current UAT filter:

```text
SiteRef = Default
AND ApiName = SHIPMENT
```

Show:

```text
EndpointUrl
LoginUrl
TimeoutSeconds
SuccessMode
MaxBatchSize
MaxAttempts
BackoffBaseMinutes
BackoffCapMinutes
IsActive
SchedulerEnabled
```

Never display or bind:

```text
AuthValue
```

`AuthType` and `AuthHeader` may be shown read-only for troubleshooting.

## 6. Minimum screen target

```text
SHIPMENT SCHEDULER CONTROL CENTER

API               ACTIVE
Master Scheduler  OFF
Ready              2
Waiting Retry      0
Exhausted          0
Default Max / Run  50
Max Attempts       5

Schedule
HOURLY | Every 60 Minutes | 60 | Default | OFF

Shipment Queue
P96327 | READY | 0/5
P96328 | READY | 0/5
```

This is enough for the first stakeholder screenshot/demo.

## 7. Expected runtime behavior with independent collections

It is correct for all sections to be visible at once:

```text
Schedule area  -> one or more Site schedule rows
Dashboard      -> one Site summary row
Queue          -> all current Site pending/retry DN rows
Config         -> one SHIPMENT config row for the Site
```

Changing the selected schedule must **not** hide or change the queue just because of a collection link. Only schedule-specific fields such as `LastRunStatus`, `LastSucceeded`, `LastFailed`, etc. belong to the selected Schedule row.

## 8. Do not wire yet in this milestone

Do not yet enable:

```text
Master Scheduler ON
Run Now
TaskMan heartbeat
automatic HTTP sending
Reset Retry
```

Those are wired after the form proves all four IDOs load correctly with the proper Site filters.

## 9. Next phase after visible form

```text
1. Confirm Site filters on all four collections.
2. Register form-control stored procedure methods on ue_SMK069ShipmentTransport.
3. Wire Save Schedule.
4. Wire Master ON/OFF.
5. Wire Run Now (mark due only; no credentials on form).
6. Add Retry Reset action.
7. Add/verify SMK069RunDueShipmentSchedule extension method.
8. Create TaskMan heartbeat.
9. UAT first with MaxShipments = 1.
```
