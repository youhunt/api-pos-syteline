# 44 — Scheduler REV6: RUN ONCE Auto-Save + TaskMan Recreate

Date: 2026-09-11
Scope: Shipment Outbound SyteLine -> POS API only

## Why REV6

Tenant UAT exposed two different classes of scheduler settings:

1. **Business/retry settings** stored in application tables and read at runtime.
2. **TaskMan submission parameters** captured when a TaskMan row is created.

An already REGISTERED recurring `SMK069ShipmentScheduler` can therefore keep old POS credentials / TaskMan heartbeat even after the database retry policy is changed.

## Parameter ownership

### Runtime DB settings

`dbo.ue_SMK069_shipment_schedule_mst`

- `IntervalMinutes`
- `MaxShipments`
- `NextRunDate`

`dbo.ue_SMK069_shipment_api_config_mst`

- `MaxAttempts`
- `BackoffBaseMinutes`
- `BackoffCapMinutes`
- `MaxBatchSize`

Patch 21 verified tenant values:

```text
MaxAttempts         = 1440
BackoffBaseMinutes  = 1
BackoffCapMinutes   = 1
IntervalMinutes     = 1
```

### TaskMan-captured settings

The TaskMan invocation receives at least:

```text
Username
Password
```

The recurring heartbeat frequency is also applied when the recurring WAITING task is configured.

Changing those values in a new form artifact does **not** mutate an already REGISTERED TaskMan row.

## Correct credential / heartbeat change flow

```text
STOP SCHEDULER
-> Master + business schedule OFF
-> remove old WAITING recurring TaskMan row
-> verify ACTUAL TASKMAN = NOT REGISTERED
-> import form / use locally corrected credentials
-> START SCHEDULER
-> submit fresh recurring TaskMan row
-> configure heartbeat = 1 minute
-> verify exactly one REGISTERED row and a new Task Number
```

If the old task is READY/RUNNING, STOP does not hard-kill the in-flight invocation. Let it finish, refresh, then STOP again after it returns to WAITING.

## RUN ONCE behavior in REV6

REV6 changes `RUN ONCE` to:

```text
1. Save ScheduleName / IntervalMinutes / MaxShipments from the form.
2. Request the business schedule to run now.
3. Submit a one-shot TaskMan invocation using the current form POS credential values.
4. Refresh scheduler, TaskMan, retry and API-history collections.
```

This prevents a user from editing `IntervalMinutes` / `MaxShipments` and then accidentally running with the previous unsaved values.

`RUN ONCE` still does **not** update the already REGISTERED recurring TaskMan row. It only submits a separate one-shot task.

## REV6 UI terminology

To avoid confusing unrelated values:

```text
Default Batch Size    = config MaxBatchSize
Shipments / Run       = schedule MaxShipments
Retry Max Attempts    = config MaxAttempts
Business Interval     = schedule IntervalMinutes
```

`Default Batch Size = 50` is not the retry-attempt limit.

## TaskMan heartbeat

REV6 form template sets:

```text
HeartbeatMinutes = 1
```

The new value takes effect only when a fresh recurring task is created with START after the previous recurring row is removed.

## Credentials

Repository artifacts retain placeholders only:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Replace them locally before importing the form. Never commit real POS credentials.

## Artifact generation

Use:

```text
tools/shipment/upgrade_scheduler_rev6_autosave_1min.py
```

Example:

```text
python tools/shipment/upgrade_scheduler_rev6_autosave_1min.py \
  SMK069ShipmentScheduler_REV5_RETRY_AND_API_HISTORY.xml \
  SMK069ShipmentScheduler_REV6_AUTOSAVE_1MIN_TASKMAN.xml
```

The upgrader asserts that the existing VB script is unchanged.

## UAT sequence

1. Press STOP SCHEDULER.
2. Refresh until `ACTUAL TASKMAN = NOT REGISTERED`.
3. Import REV6 after locally replacing the POS username/password placeholders.
4. Open form and refresh.
5. Verify `Business Interval (Min) = 1` and `Retry Max Attempts = 1440`.
6. Choose `Shipments / Run` appropriate for UAT; keep 1 for a controlled single-DN test.
7. Press START SCHEDULER.
8. Verify a new Task Number and exactly one REGISTERED TaskMan row.
9. For controlled testing, press `SAVE + RUN ONCE`.
10. Refresh status/history after TaskMan completes and inspect retry/API history.
