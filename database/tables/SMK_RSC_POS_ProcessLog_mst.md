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

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `log_id` | `RowPointerType` | No | `newid()` | ID log |
| `batch_num` | `nvarchar(30)` | No |  | Batch terkait |
| `trans_num` | `nvarchar(50)` | Yes |  | Transaction terkait |
| `line_num` | `int` | Yes |  | Line terkait |
| `payment_seq` | `int` | Yes |  | Payment terkait |
| `request_id` | `nvarchar(50)` | Yes |  | Request ID |
| `correlation_id` | `nvarchar(50)` | Yes |  | Correlation ID |
| `process_level` | `nchar(1)` | No | `N'B'` | B=Batch, T=Tran, L=Line, P=Payment, S=System |
| `process_name` | `nvarchar(30)` | No |  | RECEIVE/PARSE/VALIDATE/PREVIEW/POST/RETRY/CANCEL |
| `process_status` | `nchar(1)` | No | `N'R'` | R=Running, S=Success, W=Warning, E=Error, C=Cancelled |
| `message_type` | `nchar(1)` | No | `N'I'` | I=Info, W=Warning, E=Error |
| `error_code` | `nvarchar(50)` | Yes |  | Kode error terstruktur |
| `message_text` | `nvarchar(4000)` | Yes |  | Pesan operasional |
| `technical_detail` | `nvarchar(4000)` | Yes |  | Detail teknis internal |
| `processed_count` | `int` | No | `0` | Total yang diproses |
| `success_count` | `int` | No | `0` | Total sukses |
| `error_count` | `int` | No | `0` | Total error |
| `attempt_num` | `int` | No | `1` | Percobaan ke-n |
| `started_date` | `CurrentDateType` | No | `getdate()` | Waktu mulai |
| `completed_date` | `DateType` | Yes |  | Waktu selesai |
| `duration_ms` | `int` | No | `0` | Durasi milidetik |
| `processed_by` | `UsernameType` | No | `suser_sname()` | User/proses |
| `syteline_ref` | `nvarchar(50)` | Yes |  | Referensi hasil proses |

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
