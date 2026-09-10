# SMK069 Shipment Scheduler — API Hit History

Date: 2026-09-10

## Goal

Operator must be able to diagnose Shipment outbound results from the same `ue_SMK069ShipmentScheduler` form without opening SMK Query Select or Background Task History.

## Revision after tenant compile test

The first API-history artifact used extra VB form-script methods to dynamically show/hide two grids. The tenant import opened with:

```text
Error compiling script ue_SMK069ShipmentScheduler
```

Therefore that dynamic-tab artifact is WITHDRAWN for this tenant.

The corrected artifact is intentionally **metadata-only for API history**: it keeps the existing scheduler VB script unchanged and adds a second history section below the Shipment Queue. This removes the new script-compile risk while keeping all troubleshooting on one form.

Conversation artifact:

```text
SMK069ShipmentScheduler_API_HISTORY_COMPILE_SAFE.xml
```

## Collection

New secondary collection:

```text
object5 : ue_SMK069ShipmentApiLogs
          ORDERBY(ResponseDate DESC)
```

IDO source:

```text
dbo.ue_SMK069_shipment_api_log_mst
```

Reuse `ue_SMK069ShipmentApiLogs` if it already exists. If not, create it as a read-only IDO with `RowPointer` as key and expose at minimum:

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

Do not expose authorization headers, access tokens, POS username or password.

## API HIT HISTORY section

The form keeps the original Shipment Queue and adds a second grid underneath it:

```text
API HIT HISTORY / TROUBLESHOOTING
Response Date | DN No | Result | HTTP | Retry | Error Message | Response
```

Legend:

```text
S = SUCCESS
E = ERROR
N = PENDING / NEW
HTTP 0 = local validation / no HTTP response reached
HTTP 2xx = HTTP request succeeded
HTTP 4xx/5xx = API / gateway / service failure
```

Examples from current UAT evidence:

```text
P96331  E  HTTP 0    STORE_ORDER_NO kosong.
P96350  E  HTTP 503  nginx Service Temporarily Unavailable
```

Below the grid, two read-only detail fields are bound directly to the selected row:

```text
SELECTED ERROR    -> object5.ErrorMessage
SELECTED RESPONSE -> object5.ResponseJson
```

No extra form-script function is required to view those details.

## Refresh behavior

`object5` is refreshed through standard collection-refresh event responses on:

```text
form initialization
REFRESH STATUS
RUN ONCE
SAVE SCHEDULE
RefreshAllSchedulerCollections
```

No new VB method is introduced for history switching or detail dialogs.

## Acceptance

Before import, verify the IDO `ue_SMK069ShipmentApiLogs` exists and exposes the required properties.

After import:

1. Open `ue_SMK069ShipmentScheduler`; there must be no form-script compile error.
2. Existing Scheduler Status / START / STOP / RUN ONCE logic must remain unchanged.
3. Shipment Queue remains visible.
4. API HIT HISTORY must appear below the queue.
5. Latest log rows must be newest first.
6. Selecting a history row must populate SELECTED ERROR and SELECTED RESPONSE.
7. P96331 should show HTTP 0 with local validation error when applicable.
8. P96350 should show HTTP 503 and nginx response from the latest UAT test.

## Withdrawn artifact

Do not use:

```text
SMK069ShipmentScheduler_WITH_API_HIT_HISTORY.xml
```

It added dynamic show/hide VB methods and failed the tenant form-script compile gate.
