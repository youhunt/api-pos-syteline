# SMK069 Shipment Scheduler Queue Baseline

Date: 2026-09-08
Tenant Site: `Default`

Source:

```text
dbo.SMK069_ShipmentSchedulerQueue_vw
```

Observed Query Select result after Patch 08 Rev.2, Patch 09, Patch 10a and Patch 10b:

| SiteRef | ShipmentId | AttemptCount | MaxAttempts | RetryState | QueueStatus | FirstAttemptDate | LastAttemptDate | NextAttemptDate | LastHttpCode | LastError |
|---|---|---:|---:|---|---|---|---|---|---|---|
| Default | P96327 | 0 | 5 | P | READY | NULL | NULL | NULL | NULL | NULL |
| Default | P96328 | 0 | 5 | P | READY | NULL | NULL | NULL | NULL | NULL |

Interpretation:

- both pending Shipment DNs are visible through the scheduler queue read model;
- both are first-attempt candidates (`AttemptCount = 0`);
- both are eligible to send immediately (`QueueStatus = READY`);
- retry policy resolves correctly to `MaxAttempts = 5`;
- no prior HTTP/error state exists yet for either DN;
- this result matches the dashboard baseline `ReadyCount = 2`.

This is the approved baseline before enabling the Shipment scheduler or running the TaskMan sender.

Next milestone:

1. create the minimum Mongoose IDOs needed by `SMK069ShipmentScheduler`;
2. build the visible Shipment Scheduler Control Center form with master status, configuration, schedule and queue grid;
3. keep the master scheduler OFF during this visual milestone;
4. wire `SMK069RunDueShipmentSchedule` and TaskMan only after the form/read model is confirmed;
5. perform first sender UAT with `MaxShipments = 1`.
