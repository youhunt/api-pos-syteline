# ue_SMK069ShipmentScheduler — API Hit History extension

Date: 2026-09-10

This extends the single Shipment Scheduler Control Center with a second operator view in the existing lower grid area.

```text
[ SHIPMENT QUEUE ] [ API HIT HISTORY ]
```

The API history view uses secondary collection `object5`:

```text
ue_SMK069ShipmentApiLogs
FILTERPERM(SiteRef = FP(SiteRef))
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

Grid columns:

```text
Date / Time
DN No
Result (S/E/N)
HTTP
Retry
Error Message
Response
```

Operator legend:

```text
S = SUCCESS
E = ERROR
N = PENDING / NEW
HTTP 0 = local validation or no HTTP response reached
```

Buttons `VIEW ERROR` and `VIEW RESPONSE` display the selected row's complete ErrorMessage or ResponseJson together with DN, result, and HTTP code.

The artifact generated from the 10 Sep tenant export is:

```text
SMK069ShipmentScheduler_WITH_API_HIT_HISTORY.xml
```

The form defaults to SHIPMENT QUEUE. Opening API HIT HISTORY reloads `object5`, and Refresh/Run Once/Save also refresh the API log collection.

See `docs/shipment/41-api-hit-history-on-control-center.md` for acceptance and IDO setup notes.
