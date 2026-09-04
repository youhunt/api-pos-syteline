# SMK069 Shipment Negative UAT PASS — 2026-09-04

Tenant: Infor SyteLine / Mongoose Cloud
Site: `DEFAULT`
Shipment: `DN 22`

## Invoke

IDO REST pattern used by the tenant:

```text
POST {{ido_base}}/invoke/ue_SMK069ShipmentTransport?method=SMK069SendOneShipment
```

Negative transport target:

```text
https://smk069-pos.invalid/shipment
```

Success mode:

```text
UNCONFIRMED
```

## Runtime response evidence

Confirmed outputs:

```text
LogRowPointer    = 6bd91ac4-533b-4b99-8bd0-ad607ac57e74
HttpCode         = 0
TransportSuccess = 0
BusinessSuccess  = 0
Success          = 0
ReturnValue      = 16
```

Payload build succeeded and retained four separate lot rows for item `AA00024`:

```text
12  260812-002-1B-0
6   260812-003-1B-0
3   260813-008-2A-0
9   260814-015-1C-0
```

The server-side HTTP failure was expected:

```text
The remote name could not be resolved: 'smk069-pos.invalid'
```

## Database result

The existing NEW log row was reused and completed as an error attempt:

```text
SiteRef          = DEFAULT
ShipmentId       = 22
ResponseDate     = Sep 4 2026 3:09AM
ResponseHttpCode = 0
ProcessStatus    = E
RetryCount       = 1
RowPointer       = 6BD91AC4-533B-4B99-8BD0-AD607AC57E74
```

Stored response/error payload:

```json
{"SMK069_TRANSPORT_ERROR":"Shipment sender exception: The remote name could not be resolved: 'smk069-pos.invalid'","METHOD_RETURN":0}
```

## Conclusion

Negative UAT proves the full server-side lifecycle executes end-to-end:

```text
Prepare
-> Build JSON
-> server-side HTTP attempt
-> transport failure detected
-> Complete
-> outbound log E
-> RetryCount +1
```

This is a PASS for the failure/retry path.

## Wrapper return-code observation

`SMK069CompleteShipmentSendSp` returns business `Success=0` for a failed send. The current C# wrapper interprets any Complete `Success=0` as method return `16`, even though Complete successfully persisted the error state.

This is a wrapper-semantics issue, not a failure of the Shipment lifecycle. The desired semantics are:

```text
handled transport/business failure -> ReturnValue 0, Success 0
technical Prepare/Complete failure  -> ReturnValue 16
confirmed POS success               -> ReturnValue 0, Success 1
```

The batch scheduler implementation must use the business `Success` output and must not confuse a handled send failure with an orchestration failure.
