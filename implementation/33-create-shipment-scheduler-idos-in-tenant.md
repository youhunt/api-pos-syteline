# Create Shipment Scheduler IDOs in SyteLine Tenant

Date: 2026-09-08
Tenant project confirmed from IDO Wizard: `ue_SMKRSCPOS`

This guide records the actual wizard settings used in the tenant so the Shipment Scheduler form can be built consistently.

## 1. Schedule IDO

Create with IDO Wizard:

```text
Project Name       : ue_SMKRSCPOS
Access As          : ue_
Primary Base Table : ue_SMK069_shipment_schedule_mst
Table Alias        : shpsch
IDO Name           : ue_SMK069ShipmentSchedules
Extends            : blank
Extend And Replace : unchecked
```

The wizard automatically exposes the table columns. Keep the generated bound properties, including:

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

Do not set `SiteRef` alone as a pseudo key. The table business key is `SiteRef + ScheduleCode`; Mongoose row identity also has `RowPointer`.

Expected first row after Load Collection:

```text
SiteRef          = Default
ScheduleCode     = HOURLY
ScheduleName     = Every 60 Minutes
IntervalMinutes  = 60
MaxShipments     = blank
IsEnabled        = 0
RunState         = I
LastRunStatus    = N
```

## 2. API Config IDO

Create with IDO Wizard:

```text
Project Name       : ue_SMKRSCPOS
Access As          : ue_
Primary Base Table : ue_SMK069_shipment_api_config_mst
Table Alias        : shpapi
IDO Name           : ue_SMK069ShipmentApiConfigs
Extends            : blank
Extend And Replace : unchecked
```

Keep the generated properties. The Scheduler form will use at least:

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
RecordDate
RowPointer
```

Security rule: `AuthValue` may exist on the IDO because the wizard exposes the table, but **do not bind it to or display it on the Shipment Scheduler form**.

Expected row filter for form/runtime testing:

```text
SiteRef = Default
ApiName = SHIPMENT
```

Expected baseline values include:

```text
IsActive           = 1
SchedulerEnabled   = 0
MaxBatchSize       = 50
MaxAttempts        = 5
BackoffBaseMinutes = 15
BackoffCapMinutes  = 480
SuccessMode        = KACS_V1
```

## 3. Queue IDO

For the first visible form, prefer the queryable read model already verified in the tenant:

```text
dbo.SMK069_ShipmentSchedulerQueue_vw
```

Create a read-only IDO from this view:

```text
Project Name       : ue_SMKRSCPOS
Access As          : ue_
Primary Base Table : SMK069_ShipmentSchedulerQueue_vw
Table Alias        : shpque
IDO Name           : ue_SMK069ShipmentSchedulerQueue
Extends            : blank
Extend And Replace : unchecked
```

Expose:

```text
SiteRef
ShipmentId
AttemptCount
MaxAttempts
RetryState
QueueStatus
FirstAttemptDate
LastAttemptDate
NextAttemptDate
LastHttpCode
LastError
```

This IDO is read-only and is intended for the form queue grid.

Current verified tenant rows:

```text
Default | P96327 | 0 | 5 | P | READY
Default | P96328 | 0 | 5 | P | READY
```

## 4. Dashboard IDO

For the visible form header, use the verified view:

```text
dbo.SMK069_ShipmentSchedulerDashboard_vw
```

Create a read-only IDO:

```text
Project Name       : ue_SMKRSCPOS
Access As          : ue_
Primary Base Table : SMK069_ShipmentSchedulerDashboard_vw
Table Alias        : shpdsh
IDO Name           : ue_SMK069ShipmentSchedulerDashboard
Extends            : blank
Extend And Replace : unchecked
```

Current verified tenant baseline:

```text
SiteRef             = Default
MasterEnabled       = 0
ApiActive           = 1
ScheduleCount       = 1
ActiveScheduleCount = 0
DefaultMaxBatchSize = 50
MaxAttempts         = 5
ReadyCount          = 2
WaitingBackoffCount = 0
ExhaustedCount      = 0
SucceededToday      = 0
FailedToday         = 0
```

## 5. Build order from here

```text
1. Verify ue_SMK069ShipmentSchedules loads HOURLY.
2. Create/verify ue_SMK069ShipmentApiConfigs.
3. Create read-only ue_SMK069ShipmentSchedulerDashboard.
4. Create read-only ue_SMK069ShipmentSchedulerQueue.
5. Build minimum SMK069ShipmentScheduler form.
6. Keep scheduler OFF while building/testing the form.
7. Register control SP methods and runner only after the visible form is stable.
```

## Form editability rule

Editable through controlled actions / later form wiring:

```text
ScheduleName
IntervalMinutes
MaxShipments
IsEnabled
```

System/read-only display:

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

Do not expose POS username/password/token on the form.