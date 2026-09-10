# ue_SMK069ShipmentScheduler — API Hit History extension

Date: 2026-09-10

## Current tenant-safe design

The first history artifact used extra VB form-script methods to switch between two grids. Tenant validation failed with:

```text
Error compiling script ue_SMK069ShipmentScheduler
```

That artifact is withdrawn.

The current design keeps the existing scheduler form script unchanged and adds API history as a second section below the Shipment Queue.

Artifact:

```text
SMK069ShipmentScheduler_API_HISTORY_COMPILE_SAFE.xml
```

## Secondary collection

```text
object5 : ue_SMK069ShipmentApiLogs
          ORDERBY(ResponseDate DESC)
```

Required properties:

```text
SiteRef
ShipmentId
ProcessStatus
ResponseHttpCode
ResponseDate
RetryCount
ErrorMessage
ResponseJson
RowPointer
```

## Layout

```text
SHIPMENT QUEUE
...

API HIT HISTORY / TROUBLESHOOTING
Response Date | DN No | Result | HTTP | Retry | Error Message | Response

SELECTED ERROR
<selected object5.ErrorMessage>

SELECTED RESPONSE
<selected object5.ResponseJson>
```

Legend:

```text
S = SUCCESS
E = ERROR
N = PENDING / NEW
HTTP 0 = local validation or no HTTP response reached
HTTP 2xx = HTTP request succeeded
HTTP 4xx/5xx = API / gateway / service failure
```

`object5` refreshes on form initialization, REFRESH STATUS, RUN ONCE, SAVE SCHEDULE and RefreshAllSchedulerCollections using standard form event responses only.

The existing Scheduler Status / START / STOP / RUN ONCE VB code is not modified by this revision.

See `docs/shipment/41-api-hit-history-on-control-center.md` for setup and acceptance notes.
