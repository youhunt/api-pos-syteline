# Evidence — CreateCoAndLines Parameter Directions

Date: 30 July 2026

## Read-Only Metadata Request

The tenant loaded `IdoMethodParameters` rows filtered to:

```text
CollectionName = SLCos
MethodName     = CreateCoAndLines
```

No business method was invoked and no Customer Order was created or modified.

## Confirmed Parameter Contract

| Sequence | Parameter | Data Type | InputFlag | OutputFlag | MessageFlag |
| ---: | --- | --- | ---: | ---: | ---: |
| 1 | `CoAndLineInfoJson` | `VARIANT` | 1 | 0 | 0 |
| 2 | `CoResult` | `VARIANT` | 1 | 1 | 1 |

## Confirmed Interpretation

```text
CoAndLineInfoJson
- input parameter
- not an output parameter
- not a message parameter

CoResult
- input/output parameter
- message parameter
```

This confirms parameter direction only. It does not yet confirm the JSON schema, required fields, Customer Order number behavior, success response, failure response, or whether header and lines are created atomically.

## Safety Status

```text
CreateCoAndLines execution : NOT ATTEMPTED
Customer Order creation    : NOT STARTED
co_mst direct insert       : PROHIBITED
coitem_mst direct insert   : PROHIBITED
```
