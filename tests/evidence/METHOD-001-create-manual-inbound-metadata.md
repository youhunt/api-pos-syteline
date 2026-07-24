# METHOD-001 — Create Manual Inbound Metadata Smoke Test

## Object

```text
IDO              : ue_SMKRSCPosIntegration
Method           : ue_CreateManualInbound
Method Type      : Stored Procedure - Standard Method
Stored Procedure : SMKRSCPosCreateManualInboundSp
Transactional    : Yes
```

## Evidence Observed

The SyteLine 10 web client IDO Methods form recognized:

```text
SourceSystem     sequence 1
OutletCode       sequence 2
SourceReference  sequence 3
PayloadVersion   sequence 4
InboundId        sequence 5
RequestId        sequence 6
Infobar          sequence 7
```

The tenant automatically applied the `ue_` prefix to the method name. The actual method name to use for Invoke operations is therefore:

```text
ue_CreateManualInbound
```

## Result

```text
Method metadata discovery : PASS
Stored procedure binding  : PASS
Method type                : PASS
Transactional flag         : PASS
Parameter discovery        : PASS
Method invocation          : NOT YET TESTED
```

## Next Test

Invoke the method with:

```text
PIZZAHUT_POS
PH-SBY-001
pos_20260724.csv
POS_MINIMAL_V1
NULL
NULL
NULL
```

Expected return value is `0`, with generated `InboundId`, `RequestId`, and a success message in `Infobar`. One new row must be visible through `ue_SMKRSCPosInbounds`.
