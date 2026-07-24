# METHOD-004 — CreateManualInbound Negative Transaction Test

## Status

PASS

## Scope

Verify that the tenant method rejects an empty `SourceSystem` and does not persist an inbound record.

## Runtime Objects

```text
IDO              : ue_SMKRSCPosIntegration
IDO Method       : ue_CreateManualInbound
Stored Procedure : dbo.SMKRSCPosCreateManualInboundSp
Entity IDO       : ue_SMKRSCPosInbounds
```

## Test Input

```text
SourceSystem    : blank
OutletCode      : PH-SBY-001
SourceReference : pos_invalid.csv
PayloadVersion  : POS_MINIMAL_V1
```

## Expected Method Result

```text
ReturnValue : 16
Infobar     : Source System wajib diisi.
InboundId   : null/blank
RequestId   : null/blank
```

## Persistence Verification

IDO Data Viewer filter:

```text
SourceReference = 'pos_invalid.csv'
```

Observed result:

```text
No rows returned
```

## Conclusion

```text
Validation failure : PASS
Transactional rollback/no insert : PASS
Invalid inbound persistence       : NOT FOUND (expected)
```

The negative test confirms that an invalid manual inbound request does not create a partial record in `dbo.ue_SMK_RSC_POS_Inbound_mst`.
