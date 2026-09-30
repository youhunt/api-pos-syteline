# PROD Shipment Scheduler form pre-smoke state

Date: 2026-09-30
Environment: PROD
Form: ue_SMK069ShipmentScheduler

Observed on the PROD control center:

```text
API SERVICE       ACTIVE
MASTER            OFF
BUSINESS          DISABLED
ACTUAL TASKMAN    NOT REGISTERED
OVERALL STATUS    STOPPED - TASKMAN NOT REGISTERED

Ready             20
Waiting Retry     0
Exhausted         0
Success Today     0
Failed Today      0

Schedule Code     HOURLY
Schedule Name     Every 1 Minute
Business Interval 1
Default Batch     50
Shipments / Run   1
Retry MaxAttempts 1440
```

The form opened without a visible compile/runtime error.

Safety interpretation:
- recurring scheduler is still OFF;
- there is no PROD ActiveBGTasks instance yet;
- a controlled send must remain limited to one Shipment.

Anomaly to verify before START:
the dashboard reports 20 READY Shipments but the visible Retry/Execution grid
does not show a DN value in the screenshot. Verify the queue view/IDO directly
before enabling TaskMan so the first candidate is known.
