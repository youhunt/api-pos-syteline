# SMK_RSC_POS_ProcessLog_mst

## Identity

```text
Metadata object : SMK_RSC_POS_ProcessLog_mst
Physical table  : dbo.ue_SMK_RSC_POS_ProcessLog_mst
Purpose         : Audit trail proses receive, validate, preview, post, retry, dan error
```

## Primary Key

```text
log_id
```

`log_id` menggunakan `RowPointerType`/`uniqueidentifier` dengan default `newid()`.

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `log_id` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 1 | 1 |
| `batch_num` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 30 |  |  | NO | 0 |  |
| `trans_num` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `line_num` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  |  | YES | 0 |  |
| `payment_seq` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  |  | YES | 0 |  |
| `request_id` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `correlation_id` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `process_level` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nchar | nchar | 1 |  | `N'B'` | NO | 0 |  |
| `process_name` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 30 |  |  | NO | 0 |  |
| `process_status` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nchar | nchar | 1 |  | `N'R'` | NO | 0 |  |
| `message_type` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nchar | nchar | 1 |  | `N'I'` | NO | 0 |  |
| `error_code` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `message_text` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `technical_detail` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `processed_count` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  | `0` | NO | 0 |  |
| `success_count` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  | `0` | NO | 0 |  |
| `error_count` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  | `0` | NO | 0 |  |
| `attempt_num` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  | `1` | NO | 0 |  |
| `started_date` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `completed_date` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `duration_ms` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | int | int |  |  | `0` | NO | 0 |  |
| `processed_by` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_ProcessLog_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Logging Rules

- Log bersifat append/audit trail.
- Retry membuat log baru dan menaikkan `attempt_num`.
- Jangan menghapus error lama ketika mapping diperbaiki.
- Log `Running` boleh diperbarui menjadi final status.
- Technical detail tidak perlu dikirim penuh ke client API.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_ProcessLog_01
SiteRef, batch_num, started_date

IX_ue_SMK_RSC_POS_ProcessLog_02
SiteRef, batch_num, trans_num, started_date

IX_ue_SMK_RSC_POS_ProcessLog_03
SiteRef, process_status, started_date

IX_ue_SMK_RSC_POS_ProcessLog_04
SiteRef, request_id, correlation_id
```

## Example

```text
process_level  : L
process_name   : VALIDATE
process_status : E
message_type   : E
error_code     : ITEM_NOT_MAPPED
message_text   : POS item PIZZA001 has no active mapping for site SBY.
attempt_num    : 1
```
