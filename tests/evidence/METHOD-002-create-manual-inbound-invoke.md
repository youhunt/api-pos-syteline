# METHOD-002 — CreateManualInbound Invoke Evidence

## Status

```text
PASS
```

## Endpoint

```text
IDO    : ue_SMKRSCPosIntegration
Method : ue_CreateManualInbound
Type   : Stored Procedure - Standard Method
SP     : dbo.SMKRSCPosCreateManualInboundSp
```

## Input

```text
SourceSystem    : PIZZAHUT_POS
OutletCode      : PH-SBY-001
SourceReference : pos_20260724.csv
PayloadVersion  : POS_MINIMAL_V1
```

## Actual Response

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "PIZZAHUT_POS",
    "PH-SBY-001",
    "pos_20260724.csv",
    "POS_MINIMAL_V1",
    "b47d7a69-f896-4592-91c6-1da76612c69f",
    "MAN-20260724-142607-6612C69F",
    "Manual inbound berhasil dibuat. Request ID: MAN-20260724-142607-6612C69F"
  ],
  "ReturnValue": "0"
}
```

## Verification

```text
REST service reachable : PASS
IDO method recognized  : PASS
Stored procedure invoked: PASS
Transactional execution: PASS
ReturnValue             : 0
InboundId generated     : PASS
RequestId generated     : PASS
Infobar returned        : PASS
```

## Generated Identifiers

```text
InboundId : b47d7a69-f896-4592-91c6-1da76612c69f
RequestId : MAN-20260724-142607-6612C69F
```

## Conclusion

The first service method has completed a successful end-to-end invocation through Mongoose REST API and created a manual inbound request.

The next verification is to load `ue_SMKRSCPosInbounds` using the generated `InboundId` or `RequestId` and confirm that the persisted values match the method output.
