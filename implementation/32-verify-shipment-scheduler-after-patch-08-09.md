# Shipment Scheduler — Tenant Verification After Patch 08/09

Date: 2026-09-08

Status:

```text
Patch 08 Rev.2 : APPLIED
Patch 09       : APPLIED
```

Do not re-run them just to obtain dashboard output.

## Next visible step

Apply these two files separately in Apply Database:

```text
1. database/patches/2026-09-08-smk069-10a-shipment-scheduler-dashboard-view.sql
2. database/patches/2026-09-08-smk069-10b-shipment-scheduler-queue-view.sql
```

Each file contains exactly one `CREATE OR ALTER VIEW` statement.

Then use SMK Query Select / Query Select to open:

```text
SMK069_ShipmentSchedulerDashboard_vw
```

Expected initial configuration before enabling UAT:

```text
SiteRef             Default
MasterEnabled       0
ApiActive           1
ScheduleCount       1 or more
ActiveScheduleCount 0
DefaultMaxBatchSize 50
MaxAttempts         5
```

Then open:

```text
SMK069_ShipmentSchedulerQueue_vw
```

This gives the per-DN operational queue state and is easier to demonstrate than an OUTPUT-parameter stored procedure.

## Why we changed verification style

The tenant UI is not SSMS. A test like:

```sql
DECLARE ...;
EXEC ... OUTPUT;
SELECT ...;
```

cannot be treated as a single normal interactive batch here.

Runtime procedures remain unchanged and are still used by IDO/TaskMan. Only the **human verification path** changes to views.

## After the views are visible

Next implementation order:

```text
1. create IDO for dashboard/read models where needed;
2. create minimum SMK069ShipmentScheduler form;
3. expose Configuration + Schedules;
4. add Run Now / master switch methods;
5. wire TaskMan runner;
6. UAT MaxShipments = 1;
7. UAT mixed success/failure;
8. activate larger batches only after evidence is clean.
```
