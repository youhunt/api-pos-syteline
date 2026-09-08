# Evidence — Scheduler Form State After TaskMan Heartbeat

Date: 2026-09-08

Tenant screenshot confirms the custom `Shipment Scheduler Control Center` form is now loading both Dashboard and Queue collections.

Observed state:

```text
ScheduleCode      = HOURLY
ScheduleName      = Every 60 Minutes
IntervalMinutes   = 60
MaxShipments      = blank
IsEnabled         = 0
RunState          = I
LastRunStatus     = N

Master Scheduler  = 0
Api Active        = 1
Ready             = 1
Waiting Retry     = 0
Exhausted         = 0
Default Max       = 50
```

Current visible queue:

```text
P96329 | READY | MaxAttempts 5
```

Interpretation:

- TaskMan heartbeat is working, but both scheduler gates are OFF.
- `Master Scheduler = 0` means `SchedulerEnabled` is OFF at API config level.
- `IsEnabled = 0` means the `HOURLY` schedule itself is OFF.
- Therefore a TaskMan invocation can finish successfully as a clean no-op without claiming or sending a Shipment.
- `LastRunStatus = N` confirms the HOURLY schedule has not completed a real run yet.
- Dashboard/Queue collection loading is now proven by the visible `Ready = 1` and queue row `P96329`.

For first actual send UAT, keep `MaxShipments = 1`, then enable in this order:

```text
1. Master Scheduler = ON
2. HOURLY IsEnabled = 1
3. Request Run Now / make schedule due
4. Submit the TaskMan heartbeat
```

Expected proof of a real run:

```text
LastStartDate changes
LastRunDate changes
LastRunStatus changes from N to S/W/E
LastCandidates = 1 for the first UAT
Queue P96329 either disappears on success or changes retry state on failure
```
