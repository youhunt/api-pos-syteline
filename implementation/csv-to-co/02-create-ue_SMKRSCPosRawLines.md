# Implementation 02 — Create `ue_SMKRSCPosRawLines`

## Scope

Create the third entity IDO for minimal CSV/raw-line staging.

```text
IDO Project        : ue_SMKRSCPos
Logical IDO Name   : SMKRSCPosRawLines
Final IDO Name     : ue_SMKRSCPosRawLines
Architectural Role : Entity IDO
Logical Table      : SMK_RSC_POS_RawLine_mst
Physical Table     : dbo.ue_SMK_RSC_POS_RawLine_mst
Table Alias        : r
Primary Key        : BatchNum + SourceRowNum
```

## Wizard Page 1

```text
Project Name       : ue_SMKRSCPos
Primary Base Table : choose the raw-line table shown by the tenant
Table Alias        : r
IDO Name           : follow the tenant prefix behavior
Extends             : blank
```

Target final IDO name:

```text
ue_SMKRSCPosRawLines
```

Avoid a double prefix such as `ue_ue_SMKRSCPosRawLines`.

## Property Mapping

| Column | IDO Property |
|---|---|
| `batch_num` | `BatchNum` |
| `source_row_num` | `SourceRowNum` |
| `business_date` | `BusinessDate` |
| `trans_num` | `TransNum` |
| `pos_item_code` | `PosItemCode` |
| `pos_qty` | `PosQty` |
| `total_amt` | `TotalAmt` |
| `item` | `Item` |
| `syteline_qty` | `SyteLineQty` |
| `u_m` | `UM` |
| `stat` | `Stat` |
| `validation_msg` | `ValidationMsg` |
| `error_msg` | `ErrorMsg` |
| `process_date` | `ProcessDate` |
| `syteline_ref` | `SyteLineRef` |
| `CreateDate` | `CreateDate` |
| `CreatedBy` | `CreatedBy` |
| `InWorkflow` | `InWorkflow` |
| `NoteExistsFlag` | `NoteExistsFlag` |
| `RecordDate` | `RecordDate` |
| `RowPointer` | `RowPointer` |
| `SiteRef` | `SiteRef` |
| `UpdatedBy` | `UpdatedBy` |

## Key Review

```text
BatchNum
- Bound Column : batch_num
- Key          : Yes
- Key Sequence : 1
- Nullable     : No

SourceRowNum
- Bound Column : source_row_num
- Key          : Yes
- Key Sequence : 2
- Nullable     : No
```

`RowPointer` remains a framework identifier and is not part of the designed business key.

## Save and Check In

```text
Save
Check In
```

Suggested comment:

```text
Create ue_SMKRSCPosRawLines entity IDO for minimal POS CSV staging
```

## Smoke Test

Use IDO Data Viewer:

```text
IDO : ue_SMKRSCPosRawLines
```

Select at least:

```text
BatchNum
SourceRowNum
BusinessDate
TransNum
PosItemCode
PosQty
TotalAmt
Stat
RowPointer
SiteRef
```

Expected:

```text
Load Collection succeeds.
0 records returned is acceptable before CSV import is implemented.
```
