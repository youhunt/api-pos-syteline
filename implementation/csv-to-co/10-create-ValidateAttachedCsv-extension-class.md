# Implementation 10 — Create `ue_ValidateAttachedCsv` Extension Method

## Confirmed Attachment Retrieval

The tenant can retrieve the uploaded source file through:

```text
IDO      : DocumentObjectAndRefViews
Property : DocumentObject
Format   : Base64
```

The selected attachment returned a populated `DocumentObject` beginning with `YnVzaW5lc3Nf...`, which decodes to the expected CSV header beginning with `business_...`.

The REST download endpoint experiment is not used by the parser. The extension class calls `DocumentObjectAndRefViews` directly inside the IDO runtime.

## Why an Extension Class

`ValidateAttachedCsv` must:

1. load the inbound record;
2. obtain its framework `RowPointer`;
3. load the attached `DocumentObject` Base64 value;
4. decode UTF-8 CSV bytes;
5. parse and validate CSV rows;
6. update the inbound validation metadata.

This is application/runtime logic rather than a simple SQL insert, so it is implemented as an IDO extension class standard method.

## Assembly Identity

Create a Build From Source assembly:

```text
Assembly Name : ue_SMKRSCPosExtensions
Assembly Type : Build From Source
Language      : C#
References    : use the tenant default minimum references
```

## Source File

Repository source:

```text
extension-classes/SMKRSCPosIntegrationExtension.cs
```

Source identity:

```text
Namespace      : SMKRSCPos
Class Name     : SMKRSCPosIntegrationExtension
Target IDO     : ue_SMKRSCPosIntegration
Public Method  : ue_ValidateAttachedCsv
Method Type    : Extension Class - Standard Method
```

## Build From Source Steps

1. Open `IDO Extension Class Assemblies`.
2. Create a new record.
3. Fill:

```text
Assembly Name : ue_SMKRSCPosExtensions
Assembly Type : Build From Source
Language      : C#
```

4. Save.
5. Click `Source Code`.
6. Create a new source record:

```text
File Name : SMKRSCPosIntegrationExtension.cs
```

7. Open `Code Editor`.
8. Paste the complete source from:

```text
extension-classes/SMKRSCPosIntegrationExtension.cs
```

9. Save the source.
10. Return to `IDO Extension Class Assemblies`.
11. Click `Build Assembly`.
12. Resolve all compiler errors before continuing.
13. Check In the source and assembly.

## Link the Assembly to the IDO

Open `IDOs`, select:

```text
ue_SMKRSCPosIntegration
```

Check out the IDO and set:

```text
IDO Assembly Name  : ue_SMKRSCPosExtensions
Ext Class Namespace: SMKRSCPos
Ext Class Name     : SMKRSCPosIntegrationExtension
```

Save and check in.

## Add the Method Metadata

Create a new method on `ue_SMKRSCPosIntegration`:

```text
Method Type : Extension Class - Standard Method
Method Name : ue_ValidateAttachedCsv
Transactional: not checked
```

The method is intentionally non-transactional for validation. A structurally invalid CSV must still persist status `E`, counts, and error information on the inbound record.

### Parameters

Use this exact order:

| Sequence | Parameter | Direction | Suggested Type |
|---:|---|---|---|
| 1 | `InboundId` | Input | string / GUID text |
| 2 | `DocumentName` | Input | string |
| 3 | `ProfileCode` | Input | string |
| 4 | `RowCount` | Input/Output | integer |
| 5 | `ValidCount` | Input/Output | integer |
| 6 | `ErrorCount` | Input/Output | integer |
| 7 | `PeriodStart` | Input/Output | string |
| 8 | `PeriodEnd` | Input/Output | string |
| 9 | `TransCount` | Input/Output | integer |
| 10 | `TotalAmt` | Input/Output | decimal |
| 11 | `Infobar` | Input/Output | string |

The actual tenant may automatically add the `ue_` prefix to the method name. The source method already uses the final name `ue_ValidateAttachedCsv`.

## Validation Rules Implemented

### File/Header

```text
Profile       : POS_MINIMAL_V1
Encoding      : UTF-8
Required header:
business_date,trans_num,pos_item_code,pos_qty,total_amt
```

### Row Rules

- blank trailing rows are ignored;
- exactly five fields are required;
- `business_date` must use `yyyy-MM-dd`;
- `trans_num` is required;
- `pos_item_code` is required;
- `pos_qty` must be numeric and greater than zero;
- `total_amt` must be numeric and not negative;
- quoted CSV fields and doubled quotes are supported.

## Inbound Updates

On valid CSV:

```text
StorageMode    = E
PayloadLocation= DOC:ue_SMKRSCPosInbounds:<RowPointer>:<DocumentName>
ContentLength  = decoded byte length
ParsedDate     = current datetime
RowCount       = all nonblank data rows
AcceptedCount  = valid rows
RejectedCount  = 0
Stat           = P
ResponseCode   = 200
```

On invalid CSV:

```text
StorageMode    = E
RowCount       = all nonblank data rows
AcceptedCount  = valid rows
RejectedCount  = error count
Stat           = E
ResponseCode   = 422
ErrorMsg       = validation details
```

`StorageMode = E` is used because the file is stored as a standard Mongoose document object referenced through `PayloadLocation`; it is not stored in the custom `payload_text` column.

## Expected Positive Test

Inputs:

```text
InboundId    : b47d7a69-f896-4592-91c6-1da76612c69f
DocumentName : POS_MINIMAL_V1
ProfileCode  : POS_MINIMAL_V1
```

Expected outputs:

```text
RowCount    : 3
ValidCount  : 3
ErrorCount  : 0
PeriodStart : 2026-07-23
PeriodEnd   : 2026-07-23
TransCount  : 2
TotalAmt    : 350000
ReturnValue : 0
```

Expected inbound state:

```text
Stat           : P
StorageMode    : E
RowCount       : 3
AcceptedCount  : 3
RejectedCount  : 0
ResponseCode   : 200
```

## Stop Point

Do not implement `ImportAttachedCsv` until:

```text
[ ] Assembly builds successfully
[ ] Assembly is linked to ue_SMKRSCPosIntegration
[ ] ue_ValidateAttachedCsv metadata exists
[ ] REST Invoke returns RowCount=3 and TotalAmt=350000
[ ] Inbound status changes from R to P
```
