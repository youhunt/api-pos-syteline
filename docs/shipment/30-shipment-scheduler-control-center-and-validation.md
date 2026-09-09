# 30 — Shipment Scheduler Control Center and Validation Strategy

> Date: 8 September 2026  
> Status: active design / tenant implementation in progress  
> Related: `docs/29-shipment-scheduler.md`, `forms/02-SMK069ShipmentScheduler.md`, `ido/03-SMK069ShipmentScheduler.md`, `implementation/30-deploy-shipment-scheduler-control-center.md`, `implementation/31-visible-first-shipment-scheduler-delivery.md`

## 1. Current delivery decision

The Shipment Scheduler is being delivered **visible-first** so the business can see and understand the configuration before the background runtime is enabled.

Delivery order:

```text
1. Patch 08 revision 2
2. Patch 09 control-center SQL
3. Minimum Mongoose Shipment Scheduler form + menu
4. IDO/service method registration
5. Background runner / TaskMan heartbeat
6. Retry Queue + API Log detail
7. Concurrency hardening before multiple active schedules are allowed
```

The minimum visible milestone is a working form that can be opened from the recommended menu:

```text
SMK069
  -> POS Integration
      -> Shipment Scheduler
```

Form name:

```text
SMK069ShipmentScheduler
```

Display name:

```text
Shipment Scheduler Control Center
```

## 2. Scheduler scope

A scheduler is **not created per Shipment**.

One schedule processes a queue of eligible Shipment DN numbers.

Example:

```text
HOURLY schedule
    |
    v
select eligible Shipment DNs
    |
    +-- P96325 -> validate -> send -> success/failure
    +-- P96326 -> validate -> send -> success/failure
    +-- P96327 -> validate -> send -> success/failure
    +-- ... up to effective MaxShipments
```

A failure on one Shipment must not stop processing of the remaining Shipments in the same run.

## 3. Maximum Shipment parameter

The maximum number of Shipment DNs processed in one run is **parameterized, not hardcoded**.

There are two levels:

```text
Configuration.MaxBatchSize
    = system/default maximum per run

Schedule.MaxShipments
    = optional override for one schedule
```

Effective rule:

```text
if Schedule.MaxShipments is filled
    use Schedule.MaxShipments
else
    use Configuration.MaxBatchSize
```

Initial safe defaults:

```text
MaxBatchSize = 50
MaxAttempts = 5
BackoffBaseMinutes = 15
BackoffCapMinutes = 480
TimeoutSeconds = 60
```

For first sender UAT, set `MaxShipments = 1` even when the default is 50.

## 4. Queue eligibility filter

Before per-Shipment business validation, the queue picker selects only DNs that are eligible for automatic processing.

Current rules:

```text
current Site only
Api_post = 0
shipment_qty > 0
DN_No is not blank
RetryState is pending / not exhausted
AttemptCount is below MaxAttempts
NextAttemptDate is NULL or already due
```

The picker returns at most the effective maximum for the run.

## 5. Validation strategy — PER SHIPMENT

Business validation is performed **per Shipment immediately before send**.

Do not validate every Shipment in the queue first and then block the entire run because one DN is invalid.

Expected flow:

```text
P96325
  -> Build / Prepare validation
  -> valid
  -> HTTP POST
  -> Complete
  -> success/failure

P96326
  -> Build / Prepare validation
  -> invalid
  -> record failure / retry
  -> continue to the next DN

P96327
  -> Build / Prepare validation
  -> valid
  -> HTTP POST
  -> Complete
```

Reasons:

- one malformed Shipment must not delay valid Shipments;
- payload construction is naturally scoped by `DN_No`;
- retry state is already tracked by `SiteRef + ShipmentId`;
- the schedule run can still produce a consolidated summary of candidates, succeeded, failed and exhausted.

## 6. Retry behavior

Retry is stored per Shipment, not per schedule.

States:

```text
P = pending / eligible after backoff
X = exhausted / operator action required
S = success / historical state
```

Default attempt behavior:

```text
Attempt 1 failure -> next after 15 minutes
Attempt 2 failure -> next after 30 minutes
Attempt 3 failure -> next after 60 minutes
Attempt 4 failure -> next after 120 minutes
Attempt 5 failure -> exhausted (X)
```

An exhausted Shipment is excluded from automatic processing until an authorized operator resets it after fixing the underlying cause.

## 7. Control Center parameters and status

Minimum form must expose:

### Header

```text
Master Scheduler ON/OFF
API Config ACTIVE/INACTIVE
Next Run
Ready count
Waiting Retry count
Exhausted count
Success Today
Failed Today
```

### Configuration

```text
Shipment Endpoint
Login Endpoint
Timeout (Seconds)
Default Max / Run
Max Attempts
Backoff Base (Minutes)
Backoff Cap (Minutes)
Success Mode
```

### Schedule

```text
Schedule Code
Schedule Name
Run Every (Minutes)
Max Shipments / Run
Active
Next Run
Last Run
Last Status
Last Candidates
Last Succeeded
Last Failed
Last Exhausted
Last Message
```

Credentials and token are never displayed or stored by this form.

## 8. Run Now behavior

`Run Now` must not ask the operator for POS credentials.

It only marks the selected schedule as due:

```text
Run Now
  -> SMK069RequestShipmentRunNowSp
  -> RunRequested = 1 / NextRun due
  -> background runner consumes it
```

The secure background runtime owns the credentials.

## 9. Background runtime

Recommended runtime:

```text
TaskMan heartbeat (for example every 5 minutes)
    |
    v
SMK069RunDueShipmentSchedule
    |
    +-- SMK069ClaimDueShipmentScheduleSp
    +-- SMK069SendPendingShipments
    +-- SMK069CompleteShipmentScheduleSp
```

TaskMan is only the heartbeat. The business cadence comes from the schedule rows maintained by the form.

Example:

```text
TaskMan polls every 5 minutes
HOURLY schedule IntervalMinutes = 60
```

The schedule executes on the first heartbeat at or after its `NextRunDate`.

## 10. Concurrency rule before production multi-schedule

Patch 09 already claims/leases the **schedule** so two runners do not consume the same schedule simultaneously.

Before enabling multiple active schedules in production, add/verify an explicit per-Shipment claim/lease mechanism so two different schedules cannot process the same DN concurrently.

Until that hardening is complete:

```text
production/UAT active schedule count: 1
recommended schedule: HOURLY
```

## 11. First visible milestone

The first form build is accepted when the operator can open:

```text
SMK069 > POS Integration > Shipment Scheduler
```

and see at least:

```text
Master Scheduler : OFF
Default Max / Run: 50
Max Attempts     : 5
Schedule         : HOURLY
Run Every        : 60 minutes
Schedule Active  : OFF
Ready            : count
Waiting Retry    : count
Exhausted        : count
```

No automatic HTTP sending is required for this first visual milestone.

## 12. First functional UAT sequence

After the form is visible:

```text
1. Register/run the background extension method.
2. Set HOURLY MaxShipments = 1.
3. Keep master/schedule OFF while verifying configuration.
4. Enable only after manual sender UAT is clean.
5. Execute one controlled valid Shipment.
6. Verify API log + retry state + Api_post.
7. Test one controlled invalid Shipment.
8. Verify the invalid DN fails/retries without blocking a valid DN.
9. Increase MaxShipments gradually after evidence is clean.
```

## 13. Stakeholder answer reference

Current business answers:

```text
Q: Is maximum per run hardcoded?
A: No. It is a parameter. There is a default configuration and an optional per-schedule override.

Q: Where is the parameter maintained?
A: SMK069 > POS Integration > Shipment Scheduler.

Q: Are all Shipments validated first before any are sent?
A: No. Validation is per Shipment immediately before send. One invalid Shipment does not block other valid Shipments in the same run.

Q: Is there one scheduler per Shipment?
A: No. One schedule processes a queue of eligible Shipment DNs, up to the configured maximum per run.
```
