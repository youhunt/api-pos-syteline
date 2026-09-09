# SMK069 Shipment Scheduler — Visible-First Delivery Order

> Date: 2026-09-08
> Goal: make the scheduler visible and demonstrable first, while keeping the runtime design production-safe.

## Delivery priority

Build in this order:

1. **Visible Control Center form** — operator can open the menu and see/edit the important parameters.
2. **Stored procedures + schedule data** — Patch 08 revision 2 and Patch 09.
3. **Background runner / TaskMan heartbeat** — execute due schedules automatically.
4. **Retry Queue + API Log detail** — operational troubleshooting and reset actions.
5. **Concurrency hardening** — explicit per-shipment claim/lease before allowing multiple active schedules in production.

The first demonstrable target is therefore not the final polished form. It is a minimum working form that answers the questions the business is already asking.

---

## Menu placement

Recommended custom menu path:

```text
SMK069
  -> POS Integration
      -> Shipment Scheduler
```

Form:

```text
Form Name    : SMK069ShipmentScheduler
Display Name : Shipment Scheduler Control Center
```

If the tenant already has a different SMK069 custom menu hierarchy, place it under the existing SMK069 / POS Integration folder rather than creating a competing root menu.

---

## What must be visible in the first form version

### Header / status

```text
Master Scheduler : OFF / ON
API Config        : ACTIVE / INACTIVE
Next Run          : date/time
Ready             : count
Waiting Retry     : count
Exhausted         : count
```

### Parameters

Configuration tab:

```text
Default Max / Run     -> MaxBatchSize
Maximum Attempts      -> MaxAttempts
Backoff Base (Minute) -> BackoffBaseMinutes
Backoff Cap (Minute)  -> BackoffCapMinutes
Timeout (Second)      -> TimeoutSeconds
Shipment Endpoint     -> EndpointUrl
Login Endpoint        -> LoginUrl
```

Schedules tab:

```text
Schedule Code
Schedule Name
Run Every (Minutes)
Max Shipments / Run
Active
Next Run
Last Run
Last Status
```

Parameter rule:

```text
Schedule.MaxShipments has priority when filled.
If blank, use Configuration.MaxBatchSize.
```

So the answer to "maksimal ini hardcode atau parameter?" is:

> Parameter. Default is stored in Shipment Scheduler Configuration, and a schedule can optionally override the maximum per run.

---

## Validation strategy — PER SHIPMENT

Do **not** validate the whole queue first and then block the whole run because one Shipment is invalid.

The required runtime behavior is:

```text
Scheduler selects up to MaxShipments eligible DN numbers
        |
        +-- DN P96325
        |     Build / Prepare validation
        |     -> valid   -> send -> Complete -> success/failure result
        |     -> invalid -> record failure/retry -> continue
        |
        +-- DN P96326
        |     Build / Prepare validation
        |     -> continue independently
        |
        +-- DN P96327
              ...
```

Why:

- one malformed Shipment must not delay every valid Shipment;
- validation and payload construction are naturally scoped to one `DN_No`;
- retry state is already stored per `SiteRef + ShipmentId`;
- the run summary can still report total candidates, succeeded, failed and exhausted.

### Selection validation vs business validation

There are two levels:

1. **Queue selection filter** before processing:
   - current Site only;
   - `Api_post = 0`;
   - quantity > 0;
   - DN is not blank;
   - not exhausted;
   - retry backoff has elapsed.

2. **Per-Shipment Build/Prepare validation** immediately before HTTP send.

A per-Shipment validation failure must not stop the loop.

---

## Minimum visible form milestone

The first form build is considered successful when the user can open:

```text
SMK069 > POS Integration > Shipment Scheduler
```

and see:

```text
Master Scheduler : OFF
Default Max / Run: 50
Max Attempts     : 5
Run Every        : 60 minutes
Schedule         : HOURLY
Active           : OFF
Ready / Retry / Exhausted counts
```

No HTTP sending is required to demonstrate this first visual milestone.

After that, connect:

```text
Run Now
TaskMan heartbeat
Last Result
Retry Queue
API Log
```

---

## Backend order for tenant deployment

Assuming Patch 07 revision 2 is already applied:

```text
1. Apply 2026-09-08-smk069-08-shipment-scheduler-procs.sql
2. Apply 2026-09-08-smk069-09-shipment-scheduler-control-center.sql
3. Verify config + HOURLY schedule rows
4. Create/refresh IDOs required by forms/02-SMK069ShipmentScheduler.md
5. Build minimum form and menu entry
6. Add/register SMK069RunDueShipmentSchedule
7. Create TaskMan heartbeat
8. UAT with Max Shipments = 1 first
9. UAT mixed result: one success + one invalid Shipment
10. Increase Max Shipments after evidence is clean
```

Keep both master and HOURLY schedule OFF until the sender UAT succeeds.

---

## UAT evidence expected

### Test A — parameter visibility

```text
Default Max / Run = 50
HOURLY Interval   = 60
HOURLY Max / Run  = blank
Effective max     = 50
```

Then set:

```text
HOURLY Max / Run = 1
```

and verify the runner takes at most one DN.

### Test B — validation independence

Prepare at least two pending Shipments:

```text
DN A = valid
DN B = intentionally invalid in a controlled UAT way
```

Expected:

```text
DN A -> success
DN B -> failed / retry state
Run  -> completes with WARNING, not aborted
```

The API log and retry queue must show which DN failed and why.

---

## Stakeholder answer reference

For current questions:

```text
Maximum per run:
  parameter, not hardcoded.
  Default in Configuration; optional override per Schedule.

Parameter menu:
  SMK069 > POS Integration > Shipment Scheduler.

Validation:
  per Shipment immediately before send.
  One invalid Shipment does not block the other valid Shipments.
```
