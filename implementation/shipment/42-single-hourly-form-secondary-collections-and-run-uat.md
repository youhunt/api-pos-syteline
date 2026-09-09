# SMK069 Shipment Scheduler - Single HOURLY Form, Secondary Collections, and UAT Run

Date: 2026-09-08

This is the active implementation decision for the current tenant.

## 1. UI scope: one fixed schedule only

The operator-facing form uses the existing seeded schedule:

```text
ScheduleCode = HOURLY
```

Do not expose New/Copy/Delete schedule operations on `SMK069ShipmentScheduler`.

Editable fields:

```text
ScheduleName      optional/read-only if desired
IntervalMinutes   editable
MaxShipments      editable; blank = config default
IsEnabled         editable
```

System/read-only fields:

```text
ScheduleCode
RunState
NextRunDate
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

The database remains capable of multiple schedules, but this tenant form intentionally exposes only the seeded `HOURLY` schedule.

## 2. Dashboard and Queue are FORM SECONDARY COLLECTIONS

Current form collections:

```text
Primary Collection      : ue_SMK069ShipmentSchedules
Secondary Collection 2  : ue_SMK069ShipmentSchedulerDashboard
Secondary Collection 3  : ue_SMK069ShipmentSchedulerQueue
```

Important correction:

The Form Designer `Collections` tab does NOT provide a Parent/Child or LinkBy setting for these top-level secondary collections.

A true Mongoose **Subcollection** is a different mechanism. It is defined as a Subcollection property on a parent IDO in IDO metadata. Do not confuse a Form Secondary Collection with an IDO Subcollection.

For the current tenant form, keep Dashboard and Queue as secondary collections. Do NOT redesign the IDOs just to make the form load.

### Secondary Collection settings

For Secondary Collection 2 and Secondary Collection 3:

```text
Refresh standard operation       : enabled
Defer Refresh Until Visible      : False
Read-only / Save disabled        : recommended
New/Copy/Delete                  : disabled
```

Temporary UAT filters:

```text
Dashboard : SiteRef = 'Default'
Queue     : SiteRef = 'Default'
```

Dashboard and Queue are Site-level data. Queue is not linked by ScheduleCode.

## 3. Explicitly refresh secondary collections on form open

The normal form Refresh primarily refreshes the primary collection. The two secondary collections must be refreshed explicitly.

Use Form Event Handlers.

Recommended event:

```text
StdFormInitCompleted
```

Handler sequence:

```text
Sequence 10
Response Type : Collection Refresh
Collection    : Secondary Collection 2 / ue_SMK069ShipmentSchedulerDashboard

Sequence 20
Response Type : Collection Refresh
Collection    : Secondary Collection 3 / ue_SMK069ShipmentSchedulerQueue
```

Infor Mongoose Collection Refresh is specifically designed to refresh a named collection on a form.

Optionally repeat the same two handlers on:

```text
StdFormRefreshCompleted
```

if the dashboard/queue must also follow a later manual refresh of the primary schedule.

Do not create a Parent/Child link in the Form Collections tab; that option does not exist for normal secondary collections.

### Alternative only if later needed: IDO Subcollection

If explicit secondary refresh proves unreliable, a true Subcollection can be created on `ue_SMK069ShipmentSchedules` in the IDO definition:

```text
New Property
Property Type : Subcollection
Child IDO     : ue_SMK069ShipmentSchedulerDashboard or ue_SMK069ShipmentSchedulerQueue
LinkBy        : SiteRef = SiteRef
```

That is an IDO metadata change, not a Form Secondary Collection setting. Do not do this unless needed.

Current expected Dashboard:

```text
MasterEnabled       = 0
ApiActive           = 1
ReadyCount          = 2
WaitingBackoffCount = 0
ExhaustedCount      = 0
DefaultMaxBatchSize = 50
MaxAttempts         = 5
```

Current expected Queue:

```text
P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

## 4. Extension class source to use

Do NOT use `extension-classes/SMK069ShipmentSenderExtension.cs` for the scheduler rollout. That file is the older source and still contains the pre-revision DN/route model.

Use the tenant source that corresponds to:

```text
extension-classes/SMK069ShipmentSenderExtension.rev3.cs
```

Revision 3 already contains:

```text
SMK069SendPendingShipments
DN_No as String
Infor -> POS route semantics
retry attempt recording
one-login-per-batch behavior
```

Before replacing tenant source, diff against the current tenant extension class because tenant-side edits may be newer than the repo copy.

## 5. Add scheduler runner into the same extension class

Paste the members from:

```text
extension-classes/SMK069ShipmentSchedulerRunner.snippet.cs
```

inside the existing:

```text
SMK069ShipmentTransportExtension
```

Do not create another `[IDOExtensionClass("ue_SMK069ShipmentTransport")]` class.

The runner method is:

```text
SMK069RunDueShipmentSchedule
```

Flow:

```text
TaskMan heartbeat
  -> claim due HOURLY schedule
  -> resolve MaxShipments
  -> SMK069SendPendingShipments
  -> each DN is sent independently
  -> record retry/success per DN
  -> complete schedule and calculate NextRunDate
```

## 6. Required IDO methods on ue_SMK069ShipmentTransport

Patch 08 Rev.2 methods required by the batch sender:

```text
SMK069GetShipmentConfigSp
SMK069GetPendingShipmentsSp
SMK069RecordShipmentAttemptSp
```

Patch 09 methods required by the scheduler runner:

```text
SMK069ClaimDueShipmentScheduleSp
SMK069CompleteShipmentScheduleSp
```

Extension method:

```text
SMK069RunDueShipmentSchedule
Transactional = OFF / not checked
```

Parameters:

| Seq | Name | Direction | Type |
|---:|---|---|---|
| 1 | Username | Input | String |
| 2 | Password | Input | String |
| 3 | ScheduleCode | Output | String |
| 4 | Candidates | Output | Int32 |
| 5 | Succeeded | Output | Int32 |
| 6 | Failed | Output | Int32 |
| 7 | Exhausted | Output | Int32 |
| 8 | Infobar | Output | String |

Credentials must be supplied by TaskMan parameters only. Do not expose them on the form.

## 7. First UAT - send only one Shipment

Before enabling automatic execution:

```text
MaxShipments = 1
```

Current READY queue is:

```text
P96327
P96328
```

First UAT must therefore process at most one DN.

Enable in this order:

```text
1. Set HOURLY IsEnabled = 1
2. Set master SchedulerEnabled = 1
3. Request Run Now OR make NextRunDate due
4. TaskMan heartbeat invokes SMK069RunDueShipmentSchedule
```

Expected after first successful UAT run:

```text
Candidates <= 1
Succeeded + Failed <= 1
HOURLY LastRunStatus updated
Dashboard ReadyCount decreases or retry state changes
Queue reflects SUCCESS removal / WAITING_BACKOFF / EXHAUSTED as applicable
```

Do not raise `MaxShipments` to 50 until one-DN UAT proves:

```text
login works
correct infor_dn endpoint is used
success contract is recognized
Api_post only changes on confirmed success
failure enters retry/backoff
Dashboard and Queue refresh correctly
```

## 8. TaskMan

After the runner compiles and IDO method metadata is registered:

```text
Heartbeat : every 5 minutes
Method    : SMK069RunDueShipmentSchedule
Username  : TaskMan parameter
Password  : TaskMan parameter
```

TaskMan is only the heartbeat. `IntervalMinutes` on `HOURLY` remains the business schedule.

## 9. Form actions after read collections work

Current form should provide:

```text
Save / update schedule settings
Active / Non Active
Master ON / OFF
Run Now
Refresh
```

No New Schedule action is required.
