# SyteLine Cloud SQL Execution Model — Apply Database vs Query Select

Date: 2026-09-08

This tenant does **not** behave like SSMS for ad-hoc batches.

## Confirmed tenant behavior

### Apply Database

Treat one submission as **one executable database command/object definition**.

Do not assume this works as a single paste:

```sql
CREATE OR ALTER PROCEDURE dbo.ProcA ...
GO
CREATE OR ALTER PROCEDURE dbo.ProcB ...
GO
CREATE OR ALTER VIEW dbo.ViewC ...
```

For deployment instructions, split these into separate Apply Database executions.

Likewise, do not use SSMS-style verification batches such as:

```sql
DECLARE ...;
EXEC dbo.SomeProcedure ... OUTPUT;
SELECT ...;
```

The SQL may be valid SQL Server syntax, but it is not a valid interactive test shape for this tenant UI.

### SMK Query Select / Query Select

Use it for a queryable object such as a view. Do not depend on a stored procedure with OUTPUT parameters to produce an SSMS-style result grid.

For Shipment Scheduler, use these read models:

```text
dbo.SMK069_ShipmentSchedulerDashboard_vw
dbo.SMK069_ShipmentSchedulerQueue_vw
```

Each view is supplied as its own single-statement Apply Database file.

---

## Shipment Scheduler verification after Patch 08 Rev.2 + Patch 09

Patch 08 Rev.2 and Patch 09 are already applied in the current tenant. Do not re-run them only to obtain verification output.

Apply separately:

```text
database/patches/2026-09-08-smk069-10a-shipment-scheduler-dashboard-view.sql
database/patches/2026-09-08-smk069-10b-shipment-scheduler-queue-view.sql
```

Then inspect through Query Select.

### Dashboard view expected first UAT state

For Site `Default`, before enabling scheduler:

```text
MasterEnabled       = 0
ApiActive           = 1
ScheduleCount       >= 1
ActiveScheduleCount = 0
DefaultMaxBatchSize = 50
MaxAttempts         = 5
NextRunDate         = NULL
```

`ReadyCount`, `WaitingBackoffCount`, `ExhaustedCount`, `SucceededToday`, and `FailedToday` depend on current Shipment data.

### Queue view

The queue view exposes one row per pending DN and classifies it as:

```text
READY
WAITING_BACKOFF
EXHAUSTED
INCONSISTENT_SUCCESS
OTHER
```

This is also the preferred read-only source for an early visible form/grid while the final IDO wiring is being completed.

---

## Repository rule going forward

For SyteLine Cloud deployment artifacts:

1. One Apply Database file should represent one executable object/command whenever practical.
2. Do not put multiple `CREATE OR ALTER` objects in a file intended for direct tenant paste.
3. `GO` is documentation/source-control separation only unless the target tenant tool explicitly supports it.
4. Verification meant for the tenant UI should be based on views / IDOs, not `DECLARE + EXEC + SELECT` batches.
5. Stored procedures with OUTPUT parameters remain valid runtime contracts for IDO methods; they are simply not the preferred interactive verification mechanism in this tenant.

The older combined Patch 08/09 files remain useful as source bundles/history, but future deployment instructions must explicitly identify each required Apply Database execution rather than saying "paste the whole SSMS batch".
