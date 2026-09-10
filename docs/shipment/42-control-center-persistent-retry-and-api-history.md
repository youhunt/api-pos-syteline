# SMK069 Shipment Scheduler Control Center — Persistent Retry + API History

Date: 2026-09-10

## Problem

The existing `SHIPMENT QUEUE` grid is not a history grid. It is driven by the current scheduler candidate view. When a DN is no longer present/eligible in `SMK069_ShipmentAPI_mst`, that DN disappears from the form even though retry state and API log rows still exist.

This made the operator unable to answer two basic questions from the control center:

1. Which DN is currently pending/retrying/exhausted/success?
2. What happened on previous HTTP attempts (HTTP code, error, response)?

Observed example:

- `P96331` still exists in retry state with `AttemptCount=1`, `RetryState=P`, `LastHttpCode=0`, error `STORE_ORDER_NO kosong.`
- `P96350` still exists in retry state with `AttemptCount=1`, `RetryState=P`, `LastHttpCode=503`, error from POS/nginx.
- Both can disappear from the current candidate queue if the source Shipment view no longer exposes them.

## Revised form design

Keep the scheduler form as a single control center, but split the operational lower area into two persistent sections.

### RETRY / EXECUTION STATUS

Source: `ue_SMK069ShipmentRetries` (read-only)

Columns:

- ShipmentId / DN No
- RetryState
- AttemptCount
- LastAttemptDate
- NextAttemptDate
- LastHttpCode
- LastError

This collection is independent of the current candidate view, so retry rows remain visible even when the DN is no longer eligible for a new scheduler pick.

Interpretation:

- `P` = pending / eligible again after backoff
- `S` = success; no automatic retry
- `X` = exhausted; requires operator correction + Reset Retry
- `HTTP 0` = local failure / no HTTP response obtained
- HTTP 2xx = HTTP-level success (business response still must be interpreted by sender contract)
- HTTP 4xx/5xx = API/gateway/server error according to returned response

### API EXECUTION HISTORY / TROUBLESHOOTING

Source: `ue_SMK069ShipmentApiLogs` (read-only)

Columns:

- ResponseDate
- ShipmentId
- ProcessStatus
- ResponseHttpCode
- RetryCount
- ErrorMessage
- ResponseJson

The newest response is displayed first. Selected-row `ErrorMessage` and `ResponseJson` are also bound to detail controls below the history grid so long payloads do not have to fit inside a grid cell.

Interpretation:

- `S` = API processing success
- `E` = error
- `N` = new/pending log row
- HTTP `0` or NULL with an error message = failure before receiving a valid HTTP response

## Form collections

The final form uses:

```text
object   = ue_SMK069ShipmentSchedules
object2  = ue_SMK069ShipmentSchedulerDashboard
object3  = ue_SMK069ShipmentSchedulerQueue        (legacy/current candidate source; still loaded)
object4  = ActiveBGTasks                           (actual TaskMan runtime)
object5  = ue_SMK069ShipmentApiLogs                (persistent API attempt history)
object6  = ue_SMK069ShipmentRetries                (persistent retry state)
```

The existing scheduler VB form script is intentionally left unchanged in this revision. History/retry display is added through Mongoose metadata collections/components only to avoid the script compile regression encountered in the previous dynamic-tab prototype.

## Required IDO properties

### ue_SMK069ShipmentRetries

At minimum:

```text
SiteRef
ShipmentId
AttemptCount
RetryState
FirstAttemptDate
LastAttemptDate
NextAttemptDate
LastHttpCode
LastError
RowPointer
```

### ue_SMK069ShipmentApiLogs

At minimum:

```text
SiteRef
ShipmentId
ProcessStatus
ResponseHttpCode
ResponseDate
RetryCount
ResponseJson
ErrorMessage
RowPointer
```

Both are read-only on the Scheduler Control Center.

## Form artifact

Generated conversation artifact:

```text
SMK069ShipmentScheduler_REV5_RETRY_AND_API_HISTORY.xml
```

It is based on the compile-safe scheduler export and does not modify the existing scheduler VB form script.

## Test

1. Import/replace `ue_SMK069ShipmentScheduler` with the REV5 XML.
2. Open the form and confirm there is no VB compile error.
3. Confirm `RETRY / EXECUTION STATUS` shows retry records even when the old candidate queue is empty.
4. Confirm `P96331` can display the local `STORE_ORDER_NO kosong.` error with HTTP 0.
5. Confirm `P96350` can display HTTP 503 and the nginx error.
6. Confirm `API EXECUTION HISTORY` shows historical attempts newest-first.
7. Select an API history row and verify the full ErrorMessage / ResponseJson appears in the detail controls.
8. Press Refresh Status and confirm both retry state and API history collections refresh.

## No database patch

This is a form/IDO presentation change only. No SQL migration is required, provided both IDOs already exist with the properties above.
