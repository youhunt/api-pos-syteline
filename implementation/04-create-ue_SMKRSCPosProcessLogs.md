# Implementation 04 — Create `ue_SMKRSCPosProcessLogs`

## Identity

```text
IDO Project        : ue_SMKRSCPos
IDO Name           : ue_SMKRSCPosProcessLogs
Architectural Role : Entity IDO
Primary Base Table : ue_SMK_RSC_POS_ProcessLog_mst
Logical Table      : SMK_RSC_POS_ProcessLog_mst
Physical Table     : dbo.ue_SMK_RSC_POS_ProcessLog_mst
Table Alias        : pl
Primary Key        : LogId -> log_id
```

Use the exact base-table name shown by the tenant dropdown when it differs from the candidate name above.

## Wizard Values

```text
Project Name       : ue_SMKRSCPos
Primary Base Table : ue_SMK_RSC_POS_ProcessLog_mst
Table Alias        : pl
IDO Name           : ue_SMKRSCPosProcessLogs
Extends             : empty
```

Avoid a duplicated prefix such as `ue_ue_SMKRSCPosProcessLogs`.

## Property Mapping

| Column | IDO Property |
|---|---|
| `log_id` | `LogId` |
| `batch_num` | `BatchNum` |
| `trans_num` | `TransNum` |
| `line_num` | `LineNum` |
| `payment_seq` | `PaymentSeq` |
| `request_id` | `RequestId` |
| `correlation_id` | `CorrelationId` |
| `process_level` | `ProcessLevel` |
| `process_name` | `ProcessName` |
| `process_status` | `ProcessStatus` |
| `message_type` | `MessageType` |
| `error_code` | `ErrorCode` |
| `message_text` | `MessageText` |
| `technical_detail` | `TechnicalDetail` |
| `processed_count` | `ProcessedCount` |
| `success_count` | `SuccessCount` |
| `error_count` | `ErrorCount` |
| `attempt_num` | `AttemptNum` |
| `started_date` | `StartedDate` |
| `completed_date` | `CompletedDate` |
| `duration_ms` | `DurationMs` |
| `processed_by` | `ProcessedBy` |
| `syteline_ref` | `SyteLineRef` |
| `CreateDate` | `CreateDate` |
| `CreatedBy` | `CreatedBy` |
| `InWorkflow` | `InWorkflow` |
| `NoteExistsFlag` | `NoteExistsFlag` |
| `RecordDate` | `RecordDate` |
| `RowPointer` | `RowPointer` |
| `SiteRef` | `SiteRef` |
| `UpdatedBy` | `UpdatedBy` |

Review `DurationMs` and `SyteLineRef` manually after using Massage Property Names.

## Primary Key

The Advanced Attributes dialog must show:

```text
1. LogId
```

`LogId` is bound to `log_id`, is non-null, and uses `RowPointerType` / `uniqueidentifier` with default `newid()`.

`RowPointer` remains the framework identifier and is not the business primary key for this table.

## Intended Behavior

This IDO is primarily read-only for monitoring and audit. Process-log records are written by controlled server-side methods. Existing log records are not deleted when retry or correction occurs.

## Check In

```text
Create ue_SMKRSCPosProcessLogs entity IDO for POS processing audit trail
```

## Smoke Test

Use IDO Data Viewer:

```text
IDO : ue_SMKRSCPosProcessLogs
```

Select at least:

```text
LogId
BatchNum
TransNum
ProcessLevel
ProcessName
ProcessStatus
MessageType
ErrorCode
MessageText
AttemptNum
StartedDate
CompletedDate
DurationMs
ProcessedBy
RowPointer
SiteRef
```

Expected:

```text
IDO discovery      : PASS
Property discovery : PASS
Primary key        : LogId
Load Collection    : PASS
Empty collection   : EXPECTED until processing runs
```

After check-in, use the tenant's web-client workflow: discard the IDO runtime cache and start a new session when the new IDO is not yet visible.
