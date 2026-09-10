# SMK069 Shipment Scheduler — API Hit History

Date: 2026-09-10

## Goal

Operator should be able to diagnose Shipment outbound results from the same `ue_SMK069ShipmentScheduler` form without opening SMK Query Select or Background Task History.

The existing form already has the Shipment Queue and TaskMan runtime truth. This revision adds a second tab-style view in the same grid area:

```text
[ SHIPMENT QUEUE ] [ API HIT HISTORY ]
```

The implementation deliberately uses two buttons plus show/hide of two grids instead of introducing a new notebook dependency. This is safer for the existing Cloud/Web Client export and keeps the operator on one form.

## Collection

New secondary collection:

```text
object5 : ue_SMK069ShipmentApiLogs
          FILTERPERM(SiteRef = FP(SiteRef))
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

## API Hit History grid

Columns:

```text
Date / Time
DN No
Result (S/E/N)
HTTP
Retry
Error Message
Response
```

Legend:

```text
S = SUCCESS
E = ERROR
N = PENDING / NEW
HTTP 0 = local validation / transport did not reach HTTP response
```

Examples from current UAT evidence:

```text
P96331  E  HTTP 0    STORE_ORDER_NO kosong.
P96350  E  HTTP 503  nginx Service Temporarily Unavailable
```

This distinction lets the operator immediately see whether a failure occurred locally before HTTP or after reaching the POS/API infrastructure.

## Detail actions

Two buttons are available while API HIT HISTORY is selected:

```text
VIEW ERROR
VIEW RESPONSE
```

They show the selected log row's DN, ProcessStatus, HTTP code and full ErrorMessage / ResponseJson in a message dialog, avoiding the need to widen grid columns excessively.

## Refresh behavior

`object5` is refreshed on:

```text
REFRESH STATUS
RUN ONCE
SAVE SCHEDULE
RefreshAllSchedulerCollections
opening API HIT HISTORY
```

The form defaults to SHIPMENT QUEUE on initial load.

## Form artifact

Conversation artifact generated from tenant export `FS_20260910_085925.XML`:

```text
SMK069ShipmentScheduler_WITH_API_HIT_HISTORY.xml
```

The artifact preserves the current runtime-truth / TaskMan logic and adds only the API history secondary collection, tab-style switcher, history grid and detail actions.

## Acceptance

Before import, verify the IDO `ue_SMK069ShipmentApiLogs` exists and exposes the properties listed above.

After import:

1. Open `ue_SMK069ShipmentScheduler`.
2. Default view must show SHIPMENT QUEUE.
3. Click API HIT HISTORY.
4. Latest log rows must appear newest first.
5. `P96331` should show HTTP 0 with local validation error when applicable.
6. `P96350` should show HTTP 503 and nginx response from the latest UAT test.
7. VIEW ERROR and VIEW RESPONSE must show the selected row details.
8. Switching back to SHIPMENT QUEUE must restore the original queue grid and Reset Retry button.
