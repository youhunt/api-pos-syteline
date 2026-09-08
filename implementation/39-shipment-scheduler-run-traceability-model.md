# Shipment Scheduler Run Traceability Model

Date: 2026-09-08

## Why this model is needed

A READY Shipment Queue row is **not owned by a schedule yet**.

Example current queue:

```text
Default | P96327 | READY
Default | P96328 | READY
```

At this stage it is intentionally impossible to say that `P96327` belongs to `HOURLY` or another schedule. The queue is a Site-level work queue that may be consumed by whichever enabled schedule becomes due and successfully claims work first.

Likewise, Dashboard is not the owner of a Shipment. Dashboard is only a Site-level summary.

Therefore the business model is:

```text
SITE
├─ Dashboard (summary only)
├─ Schedules (one or more definitions)
├─ Pending Queue (unassigned work)
└─ Run History
   ├─ Run Header -> identifies which Schedule executed
   └─ Run Detail -> identifies which Shipment was processed in that Run
```

## Pending Queue semantics

Before processing:

```text
ShipmentId : P96327
QueueStatus: READY
Schedule   : <not assigned yet>
RunId      : <none>
```

Do not add a permanent `ScheduleCode` directly to the READY queue as if the DN belongs to one schedule. That would be incorrect if multiple schedules can consume the same Site queue.

## Required Run Header

Add a durable run-history header object in the next database hardening phase, conceptually:

```text
ue_SMK069_shipment_schedule_run_mst

SiteRef
RunId
ScheduleCode
TriggerType      -- A=automatic, M=manual/run-now
StartDate
EndDate
RunStatus        -- R=running, S=success, W=warning/partial, E=error
MaxShipments
Candidates
Succeeded
Failed
Exhausted
Message
standard Mongoose audit columns
```

Example:

```text
SiteRef      Default
RunId        RUN-20260908-143000-001
ScheduleCode HOURLY
TriggerType  A
StartDate    2026-09-08 14:30:00
RunStatus    S
Candidates   2
Succeeded    2
Failed       0
```

## Required Run Detail

Add a durable run-detail object, conceptually:

```text
ue_SMK069_shipment_schedule_run_dtl

SiteRef
RunId
ShipmentId
SequenceNo
AttemptNo
ValidationStatus
SendStatus
HttpCode
ErrorMessage
StartDate
EndDate
standard Mongoose audit columns
```

Example:

```text
RUN-20260908-143000-001 | 1 | P96327 | SUCCESS | 201
RUN-20260908-143000-001 | 2 | P96328 | FAILED  | 400
```

This creates the traceability relationship:

```text
Schedule HOURLY
  -> Run RUN-20260908-143000-001
      -> P96327
      -> P96328
```

## Claiming / concurrency implication

When a schedule starts a run, a Shipment must be claimed by that Run before HTTP processing so that another due schedule cannot send the same DN concurrently.

The implementation phase must therefore introduce a per-DN active claim/lease tied to `RunId` (either in a dedicated claim object or a carefully controlled durable run-detail state).

A READY Shipment has no owner.
A CLAIMED/RUNNING Shipment has an active `RunId` and therefore a known `ScheduleCode` through the Run Header.
A completed Shipment keeps the historical RunId relationship for audit.

## Correct UI model

The main form should distinguish current queue from execution history.

### Dashboard

Site-level summary only:

```text
API Active
Master Scheduler
Ready
Waiting Retry
Exhausted
Next Run
```

### Schedules

Schedule definitions:

```text
HOURLY
FAST-15
...
```

### Shipment Queue

Current unassigned/claimed work:

```text
DN      Status            Current Run     Schedule
P96327  READY             -               -
P96328  WAITING_BACKOFF   -               -
P96329  RUNNING           RUN-...         HOURLY
```

### Run History

Filterable by selected Schedule:

```text
RunId                       Schedule  Start                Result
RUN-20260908-143000-001     HOURLY    2026-09-08 14:30     SUCCESS
```

### Run Detail

Child of selected Run, not child of current Queue:

```text
Sequence  ShipmentId  Result   HTTP  Error
1         P96327      SUCCESS  201
2         P96328      FAILED   400   ...
```

This is how operators can answer exactly:

> "P96327 was processed by which scheduler, in which run, at what time, and what was the result?"

## Important correction to earlier form-parent discussion

Using `SiteRef` as a Form `LinkBy` between Dashboard, Schedule and Queue can be useful for Mongoose loading/navigation, but it must **not** be interpreted as ownership.

The actual business ownership/tracing relationship begins only when a Run is created:

```text
Schedule -> Run Header -> Run Detail -> Shipment
```

Dashboard remains summary-only.

## Next implementation step

Before enabling multiple schedules or production TaskMan execution:

1. Add Run Header table/object.
2. Add Run Detail table/object.
3. Add per-DN claim/lease tied to RunId.
4. Update claim/runner logic to create Run Header before selecting DNs.
5. Record every selected DN in Run Detail.
6. Update Run Header totals on completion.
7. Expose Run History and Run Detail in the Shipment Scheduler form.
8. Only then consider enabling more than one active schedule.

For first UAT, keeping only one active schedule and `MaxShipments = 1` remains the safest path.