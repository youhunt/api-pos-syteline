# 45 — Shipment Scheduler Control Center REV7 UX Finish

Date: 2026-09-11
Scope: Shipment outbound SyteLine -> POS API only

## Goal

REV7 finishes the operator experience on `ue_SMK069ShipmentScheduler` without changing the Shipment API contract, retry SQL policy, or DN contract.

The design goal is that an operator can understand:

- whether API/config is active;
- whether business scheduling is enabled;
- whether TaskMan is actually registered;
- what action should be taken next;
- current business interval / batch size / retry budget / heartbeat;
- current retry state per DN;
- historical API attempts and error responses.

## UX changes

### 1. Dynamic OPERATOR ACTION

A new read-only `OperatorAction` display gives a plain-language recommendation based on runtime state.

Examples:

```text
Credential POS bermasalah. STOP SCHEDULER -> update credential -> START SCHEDULER.
Scheduler stopped. Review setting lalu tekan START SCHEDULER bila siap.
4 DN ready. Scheduler akan memproses sesuai Shipments / Run.
Scheduler healthy. Menunggu Shipment due / retry berikutnya.
```

The recommendation uses the already-proven REV6 runtime sources:

```text
Primary schedule collection
ue_SMK069ShipmentSchedulerDashboard
ActiveBGTasks
```

No new SQL object is introduced.

### 2. Operational settings clarified

The main schedule area now exposes only the values that matter to an operator:

```text
Business Interval (min)
Shipments / Run
Retry Max Attempts
TaskMan Heartbeat (min)
```

`Default Batch Size` is hidden from the main UI because it was repeatedly confused with retry attempts and the active `Shipments / Run` value.

Current confirmed UAT policy after Patch 21:

```text
Business Interval  = 1 minute
Retry backoff       = fixed 1 minute
Retry Max Attempts  = 1440 per DN
TaskMan Heartbeat   = 1 minute after recreating the recurring task
```

`Shipments / Run` remains an explicit operational setting and is not silently forced to 50.

### 3. Actions made unambiguous

Buttons are presented as:

```text
SAVE SCHEDULE
START SCHEDULER
STOP SCHEDULER
RUN ONCE (AUTO SAVE)
RESET SELECTED RETRY
```

`RUN ONCE (AUTO SAVE)` preserves the REV6 behavior: save current schedule values first, then request and submit the one-shot run.

Credential or heartbeat changes still require:

```text
STOP until ACTUAL TASKMAN = NOT REGISTERED
-> update local credential / form artifact
-> START SCHEDULER
```

A one-shot run must not silently mutate the already-registered recurring TaskMan instance.

### 4. Retry and API history sections cleaned up

The current-state grid is renamed:

```text
RETRY STATUS — CURRENT STATE PER DN
```

Legend:

```text
P = Pending / Retry
S = Success
X = Exhausted
HTTP 0 = local failure / API not hit
```

The historical grid is renamed:

```text
API EXECUTION HISTORY — AUDIT / TROUBLESHOOTING
```

The selected error and selected response areas remain below the history grid.

### 5. Layout cleanup

REV7 removes the overlap between the retry section heading and the TaskMan restart guide, widens / realigns the Task Number + Refresh Status area, hides the low-value runner indicator from the top-right, and gives the lower grids more breathing room.

## Runtime safety

REV7 intentionally does **not** change:

- `dbo.SMK069_ShipmentAPI_mst`;
- `SMK069BuildShipmentJsonSp`;
- retry table schema;
- Patch 21 retry values;
- Shipment endpoint;
- success contract;
- DN mapping;
- TaskMan task name;
- the core REV6 START / STOP / RUN ONCE orchestration.

The existing REV6 VB form script is retained and only extended with the `OperatorAction` computation. The extension uses the same helper methods and collections already compiled successfully in the tenant.

## Artifact generation

Tool:

```text
tools/shipment/upgrade_scheduler_rev7_ux.py
```

Usage:

```text
python tools/shipment/upgrade_scheduler_rev7_ux.py \
  SMK069ShipmentScheduler_REV6_AUTOSAVE_1MIN_TASKMAN.xml \
  SMK069ShipmentScheduler_REV7_UX_10_OF_10.xml
```

The generated XML keeps credential placeholders:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Replace them locally before import. Never commit real credentials.

## Import / test checklist

1. If an old recurring scheduler is registered with wrong credentials or old recurrence, press `STOP SCHEDULER` and refresh until `ACTUAL TASKMAN = NOT REGISTERED`.
2. Replace `__POS_USERNAME__` and `__POS_PASSWORD__` locally in the REV7 XML.
3. Import REV7, replacing `ue_SMK069ShipmentScheduler`.
4. Reopen the form and press `REFRESH STATUS`.
5. Confirm current policy displays:

```text
Business Interval    1
Retry Max Attempts   1,440
TaskMan Heartbeat    1
```

6. Keep `Shipments / Run = 1` for controlled UAT, or set a larger agreed batch value later.
7. Press `START SCHEDULER`.
8. Confirm a new Task Number appears and TaskMan is `REGISTERED / WAITING`.
9. For a controlled test use `RUN ONCE (AUTO SAVE)`.
10. Refresh and verify Retry Status + API Execution History.
11. If login fails, `OPERATOR ACTION` should direct the operator to STOP -> update credential -> START.

## Acceptance target

The form should answer, without needing SQL knowledge:

```text
Is the API active?
Is scheduling enabled?
Is TaskMan truly registered?
Is it waiting or running?
What should the operator do next?
How often does the business schedule run?
How often can a failed DN retry?
How many DN can one run process?
How many attempts remain conceptually before Exhausted?
What happened on the last API attempts?
```
