# SMK069 Shipment Scheduler Dashboard IDO — Tenant Property Confirmation

Date: 2026-09-08
Tenant project: `ue_SMKRSCPOS`
IDO: `ue_SMK069ShipmentSchedulerDashboard`

The SyteLine form/IDO property tree was visually confirmed to expose the dashboard read-model properties required by the minimum Shipment Scheduler form.

Confirmed properties visible in the tenant:

```text
ActiveScheduleCount
ApiActive
DefaultMaxBatchSize
ExhaustedCount
FailedToday
MasterEnabled
MaxAttempts
NextRunDate
ReadyCount
ScheduleCount
SiteRef
SucceededToday
WaitingBackoffCount
```

The dashboard IDO is therefore ready to be used as a read-only secondary collection on `SMK069ShipmentScheduler`.

First visible bindings should use:

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

Current baseline values previously verified through Query Select:

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

Do not enable the scheduler yet. This evidence only confirms the read-model property surface needed by the visible form milestone.
