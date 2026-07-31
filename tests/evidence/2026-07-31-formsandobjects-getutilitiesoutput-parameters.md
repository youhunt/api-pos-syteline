# Evidence — FormsAndObjects.GetUtilitiesOutput Parameters

Date: 31 July 2026

## Purpose

Record the tenant-published parameter contract for:

```text
FormsAndObjects.GetUtilitiesOutput
```

The request read metadata only. The method was not invoked.

## Tenant Result

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : 2
```

| Sequence | Parameter | Data Type | Input | Output | Message |
| ---: | --- | --- | ---: | ---: | ---: |
| 0 | `SessionID` | `VARIANT` | 1 | 0 | 0 |
| 1 | `SegmentNumber` | `VARIANT` | 1 | 0 | 0 |

## Confirmed Interpretation

`GetUtilitiesOutput` reads output by session and segment. It has no output or message parameter; therefore the generated content is expected to be returned through the method's custom-load result collection rather than scalar output parameters.

Combined with the generator contract:

```text
UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
→ SegmentCount input/output
→ output stored in a SQL temporary table
→ GetUtilitiesOutput(SessionID, SegmentNumber)
```

The exact execution sequence remains unconfirmed because no method has been invoked.

## User Direction

The user requested that discovery continue directly in the cloud environment rather than through additional passive metadata searches.

The active next path is controlled Cloud UI observation through the `Form Control` form and its `Utilities` area. The UI should be used to reveal tenant-valid values for configuration, source, object type, scope, object list, version, and options before any REST method invocation is attempted.

## Safety Result

```text
No GetUtilitiesOutput invocation
No pseudo-code generation
No SQL temporary-table generation
No CreateCoAndLines invocation
No metadata edit
No Customer Order payload
No SQL execution
```
