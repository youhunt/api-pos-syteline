# Evidence — FormsAndObjects Pseudo-Code Method Parameters

Date: 30 July 2026

## Purpose

Compare the tenant-published parameter contracts for:

```text
FormsAndObjects.UtilitiesGeneratePseudoCode
FormsAndObjects.UtilitiesGeneratePseudoCode2
```

The request read metadata only. Neither method was invoked.

## Tenant Result

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : 24
```

Each method publishes 12 `VARIANT` parameters.

## UtilitiesGeneratePseudoCode

| Sequence | Parameter | Input | Output | Message |
| ---: | --- | ---: | ---: | ---: |
| 0 | `SessionID` | 1 | 0 | 0 |
| 1 | `SourceConfig` | 1 | 0 | 0 |
| 2 | `TargetConfig` | 1 | 0 | 0 |
| 3 | `Source` | 1 | 0 | 0 |
| 4 | `DatabaseName` | 1 | 0 | 0 |
| 5 | `Type` | 1 | 0 | 0 |
| 6 | `Scope` | 1 | 0 | 0 |
| 7 | `RelativePosition` | 1 | 0 | 0 |
| 8 | `ObjectList` | 1 | 0 | 0 |
| 9 | `Version` | 1 | 0 | 0 |
| 10 | `SegmentCount` | 1 | 1 | 0 |
| 11 | `CompareIncludeSettings` | 1 | 0 | 0 |

## UtilitiesGeneratePseudoCode2

| Sequence | Parameter | Input | Output | Message |
| ---: | --- | ---: | ---: | ---: |
| 0 | `SessionID` | 1 | 0 | 0 |
| 1 | `SourceConfig` | 1 | 0 | 0 |
| 2 | `TargetConfig` | 1 | 0 | 0 |
| 3 | `Source` | 1 | 0 | 0 |
| 4 | `DatabaseName` | 1 | 0 | 0 |
| 5 | `Type` | 1 | 0 | 0 |
| 6 | `Scope` | 1 | 0 | 0 |
| 7 | `Options` | 1 | 0 | 0 |
| 8 | `ObjectList` | 1 | 0 | 0 |
| 9 | `Version` | 1 | 0 | 0 |
| 10 | `SegmentCount` | 1 | 1 | 0 |
| 11 | `CompareIncludeSettings` | 1 | 0 | 0 |

## Confirmed Comparison

The contracts are identical except for sequence 7:

```text
UtilitiesGeneratePseudoCode  : RelativePosition
UtilitiesGeneratePseudoCode2 : Options
```

`SegmentCount` is the only input/output parameter. All other parameters are input-only. No parameter is marked as a message parameter.

## Current Interpretation

Both methods require configuration, source, database, object type, scope, object list, version, and session context. The tenant metadata does not yet define the valid values or serialization format for these `VARIANT` inputs.

The method descriptions state that generated pseudo-code is stored in a SQL temporary table. `GetUtilitiesOutput` is therefore the strongest current candidate for retrieving that output, but this remains an inference until its parameter contract is inspected.

## Next Read-Only Step

Read `GetUtilitiesOutput` parameter metadata:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27FormsAndObjects%27%20AND%20MethodName%20%3D%20%27GetUtilitiesOutput%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Safety Result

```text
No pseudo-code method invocation
No SQL temporary-table generation
No FormsAndObjects object load
No CreateCoAndLines invocation
No metadata edit
No Customer Order payload
No SQL execution
```