# Load Shipment Scheduler Secondary Collections on Form Open

Date: 2026-09-08
Form: `SMK069ShipmentScheduler`

## Observed tenant symptom

At runtime the primary Schedule collection loads correctly:

```text
HOURLY | Every 60 Minutes | 60 | IsEnabled=0 | RunState=I | LastRunStatus=N
```

But Dashboard fields remain blank and the Queue grid shows only an empty client row, even though both IDOs/views were already verified independently.

This is not a database/view/IDO defect.

## Mongoose behavior

The form Initial Command (for example `Refresh`) applies to the **primary collection only**. Independent secondary collections are not automatically queried just because controls are bound to them.

Therefore the form must explicitly refresh the independent secondary collections.

Collections:

```text
Primary   : ue_SMK069ShipmentSchedules
Secondary : ue_SMK069ShipmentSchedulerDashboard
Secondary : ue_SMK069ShipmentSchedulerQueue
Later     : ue_SMK069ShipmentApiConfigs
```

These collections remain independent Site-level collections. Do not add Schedule -> Dashboard or Schedule -> Queue LinkBy relationships just to make them load.

## Quick diagnosis before changing events

At runtime:

1. Click a Dashboard-bound component such as `MasterEnabled` so the Dashboard collection becomes current.
2. Press F5 / Refresh.
3. Expected Dashboard values for the current baseline:

```text
MasterEnabled       0
ApiActive           1
ReadyCount          2
WaitingBackoffCount 0
ExhaustedCount      0
DefaultMaxBatchSize 50
MaxAttempts         5
```

4. Click the Queue grid so the Queue collection becomes current.
5. Press F5 / Refresh.
6. Expected rows:

```text
P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

If this succeeds, the IDO, binding, filter and view are confirmed; only automatic secondary-collection loading is missing.

## Collection settings

For both Dashboard and Queue secondary collections:

```text
Refresh standard operation       : enabled
Defer Refresh Until Visible      : False for current single-screen layout
Filter (temporary UAT)           : SiteRef = 'Default'
```

Queue must be read-only. Do not enable New/Copy, Save or Delete for Queue.

Dashboard is also read-only.

## Recommended form event wiring

After the primary collection has completed its initial Refresh, explicitly refresh the independent secondary collections.

Recommended event:

```text
Event: StdFormRefreshCompleted
```

Add handlers in this order:

```text
Sequence 10
Response Type : Collection Refresh
Collection    : ue_SMK069ShipmentSchedulerDashboard

Sequence 20
Response Type : Collection Refresh
Collection    : ue_SMK069ShipmentSchedulerQueue
```

If the Config collection is later placed on this same screen/tab, add:

```text
Sequence 30
Response Type : Collection Refresh
Collection    : ue_SMK069ShipmentApiConfigs
```

To avoid unintended execution when another collection is refreshed manually, restrict these handlers to the primary Schedule collection if the tenant Event Handler dialog exposes `Only When Current Collection Is`:

```text
ue_SMK069ShipmentSchedules
```

Do not use a LinkBy relationship as a substitute for these refresh handlers.

## Expected form after event wiring

```text
Schedule Code       HOURLY
Schedule Name       Every 60 Minutes
Interval Minutes    60
Is Enabled          0
Run State           I
Last Status         N

Master Scheduler    0
API Active          1
Ready               2
Waiting Retry       0
Exhausted           0
Default Max         50

P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

Scheduler and HOURLY schedule must remain OFF during this UI verification.
