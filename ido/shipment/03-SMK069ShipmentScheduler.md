# SMK069 Shipment Scheduler IDOs

## Scope

This document defines the Mongoose IDOs needed by
`forms/02-SMK069ShipmentScheduler.md`.

Patch dependency:

```text
Patch 07 rev2  -> existing API config + retry table
Patch 08 rev2  -> scheduler policy procedures
Patch 09       -> schedule table + dashboard/control procedures
```

---

## 1. ue_SMK069ShipmentApiConfigs

```text
IDO Name    : ue_SMK069ShipmentApiConfigs
Base Table  : dbo.ue_SMK069_shipment_api_config_mst
Primary Key : RowPointer
Update      : Yes, restricted by form authorization
```

Expose these properties:

```text
SiteRef
ApiName
EndpointUrl
HttpMethod
ContentType
AuthType
AuthHeader
TimeoutSeconds
IsActive
LoginUrl
SuccessMode
SchedulerEnabled
MaxBatchSize
MaxAttempts
BackoffBaseMinutes
BackoffCapMinutes
RowPointer
RecordDate
UpdatedBy
```

Do **not** expose `AuthValue` on the Scheduler Control Center form.

Recommended default form filter:

```text
SiteRef = current site
AND ApiName = 'SHIPMENT'
```

---

## 2. ue_SMK069ShipmentSchedules

```text
IDO Name    : ue_SMK069ShipmentSchedules
Base Table  : dbo.ue_SMK069_shipment_schedule_mst
Primary Key : RowPointer
Update      : Prefer controlled methods for business fields
```

Properties:

```text
SiteRef
ScheduleCode
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
NextRunDate
RunRequested
RunState
LeaseUntil
LastStartDate
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
CreatedBy
UpdatedBy
CreateDate
RecordDate
RowPointer
NoteExistsFlag
InWorkflow
```

On the form, system-managed properties are read-only:

```text
NextRunDate
RunRequested
RunState
LeaseUntil
LastStartDate
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage
```

Use `SMK069SaveShipmentScheduleSp` for create/update so interval validation and
next-run calculation stay server-side.

---

## 3. ue_SMK069ShipmentRetries

```text
IDO Name    : ue_SMK069ShipmentRetries
Base Table  : dbo.ue_SMK069_shipment_retry_mst
Primary Key : RowPointer
Update      : Read-only on form
```

Properties:

```text
SiteRef
ShipmentId
AttemptCount
RetryState
FirstAttemptDate
LastAttemptDate
NextAttemptDate
LastHttpCode
LastError
CreatedBy
UpdatedBy
CreateDate
RecordDate
RowPointer
NoteExistsFlag
InWorkflow
```

Never let the form directly change `AttemptCount`, `RetryState`, or
`NextAttemptDate`. Use `SMK069ResetShipmentRetrySp`.

---

## 4. ue_SMK069ShipmentApiLogs

Use the tenant's existing Shipment API log table:

```text
Base Table : dbo.ue_SMK069_shipment_api_log_mst
Mode       : read-only on Scheduler Control Center
```

If an IDO already exists for this table, reuse it. Do not create a second IDO
just for the scheduler form.

At minimum expose the existing operational fields that support troubleshooting:

```text
SiteRef
ShipmentId
Status
RetryCount
RowPointer
CreateDate / RecordDate
HTTP / response / error fields that exist in the tenant
```

Never surface password/token/authorization header in this collection.

---

# 5. Service Methods on ue_SMK069ShipmentTransport

## Existing / Patch 08

### SMK069GetShipmentConfigSp

```text
Method Type   : Stored Procedure
Transactional : Yes/standard SQL
```

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | IsEnabled | Output | Int32 |
| 2 | LoginUrl | Output | String |
| 3 | EndpointUrl | Output | String |
| 4 | SuccessMode | Output | String |
| 5 | TimeoutSeconds | Output | Int32 |
| 6 | MaxBatchSize | Output | Int32 |
| 7 | Infobar | Output | String |

### SMK069GetPendingShipmentsSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | MaxRows | Input | Int32 |
| 2 | PendingList | Output | String |
| 3 | PendingCount | Output | Int32 |
| 4 | DueLaterCount | Output | Int32 |
| 5 | ExhaustedCount | Output | Int32 |
| 6 | Infobar | Output | String |

### SMK069RecordShipmentAttemptSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | DN_No | Input | String |
| 2 | IsSuccess | Input | Int32 |
| 3 | HttpCode | Input | Int32 |
| 4 | ErrorMessage | Input | String |
| 5 | AttemptCount | Output | Int32 |
| 6 | NextAttemptDate | Output | DateTime |
| 7 | Exhausted | Output | Int32 |
| 8 | Infobar | Output | String |

`DN_No` must be String. Values such as `P96325` cannot be registered as Int64.

---

# 6. Patch 09 Form Methods

## SMK069GetShipmentSchedulerDashboardSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | MasterEnabled | Output | Int32 |
| 2 | ApiActive | Output | Int32 |
| 3 | ScheduleCount | Output | Int32 |
| 4 | ActiveScheduleCount | Output | Int32 |
| 5 | NextRunDate | Output | DateTime |
| 6 | ReadyCount | Output | Int32 |
| 7 | WaitingBackoffCount | Output | Int32 |
| 8 | ExhaustedCount | Output | Int32 |
| 9 | SucceededToday | Output | Int32 |
| 10 | FailedToday | Output | Int32 |
| 11 | Infobar | Output | String |

Used by form load and Refresh.

---

## SMK069SaveShipmentScheduleSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | ScheduleCode | Input | String |
| 2 | ScheduleName | Input | String |
| 3 | IntervalMinutes | Input | Int32 |
| 4 | MaxShipments | Input | Int32 |
| 5 | IsEnabled | Input | Int32 |
| 6 | StartAt | Input | DateTime |
| 7 | Success | Output | Int32 |
| 8 | Infobar | Output | String |

Form uses this rather than direct insert/update.

---

## SMK069SetShipmentSchedulerEnabledSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | Enabled | Input | Int32 |
| 2 | Success | Output | Int32 |
| 3 | Infobar | Output | String |

Master switch only.

---

## SMK069RequestShipmentRunNowSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | ScheduleCode | Input | String |
| 2 | Success | Output | Int32 |
| 3 | Infobar | Output | String |

This method does not perform HTTP and takes no credentials. It only sets the
selected active schedule due for the next background poll.

---

## SMK069ResetShipmentRetrySp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | DN_No | Input | String |
| 2 | Success | Output | Int32 |
| 3 | Infobar | Output | String |

Use only after the operator fixes the underlying failure.

---

# 7. Patch 09 Background Runner Methods

These are internal scheduling methods and normally are not invoked by a user form.

## SMK069ClaimDueShipmentScheduleSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | ScheduleCode | Output | String |
| 2 | MaxShipments | Output | Int32 |
| 3 | HasWork | Output | Int32 |
| 4 | Infobar | Output | String |

This method uses SQL locking and a 15-minute lease so two TaskMan executions do
not claim the same schedule at the same time.

## SMK069CompleteShipmentScheduleSp

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | ScheduleCode | Input | String |
| 2 | ResultCode | Input | Int32 |
| 3 | Candidates | Input | Int32 |
| 4 | Succeeded | Input | Int32 |
| 5 | Failed | Input | Int32 |
| 6 | Exhausted | Input | Int32 |
| 7 | Message | Input | String |
| 8 | Success | Output | Int32 |
| 9 | Infobar | Output | String |

This releases the schedule lease, writes the last result, and calculates
`NextRunDate`.

---

# 8. Extension Method Still Needed for TaskMan Heartbeat

The form SQL is complete with Patch 09. To make the form-defined schedules drive
the existing HTTP sender, add one standard extension method to the same
`ue_SMK069ShipmentTransport` extension class:

```text
SMK069RunDueShipmentSchedule
```

Flow:

```text
ClaimDueShipmentSchedule
    -> HasWork=0: return cleanly
    -> HasWork=1:
         call existing SMK069SendPendingShipments
         call CompleteShipmentSchedule
```

Credentials remain only two TaskMan inputs:

```text
Username
Password
```

The form itself must never invoke this method because Mongoose echoes input
parameters in method responses.

TaskMan can then run a small fixed heartbeat (for example every five minutes).
The editable cadence is in `ue_SMK069ShipmentSchedules.IntervalMinutes`, so
changing "60 minutes" to "30 minutes" no longer requires editing TaskMan.

---

# 9. Build Order

```text
1. Apply Patch 08 rev2.
2. Apply Patch 09.
3. Create/reuse ue_SMK069ShipmentApiConfigs.
4. Create ue_SMK069ShipmentSchedules.
5. Create ue_SMK069ShipmentRetries.
6. Reuse/create read-only API Log IDO.
7. Register Patch 09 SP methods on ue_SMK069ShipmentTransport.
8. Build SMK069ShipmentScheduler form.
9. Test form with master OFF.
10. Wire SMK069RunDueShipmentSchedule into the extension class.
11. Create TaskMan heartbeat only after the manual tests pass.
```
