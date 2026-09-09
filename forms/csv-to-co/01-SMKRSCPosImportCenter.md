# SMKRSCPosImportCenter

## Identity

```text
Form Name       : SMKRSCPosImportCenter
Display Name    : RSC POS Import Center
IDO Project     : SMK_RSC_POS
Primary IDO     : SMKRSCPosInbounds
Architectural Role : Manual import / process form
Status          : Candidate design / PoC
```

## Purpose

Form ini menjadi titik masuk manual untuk file CSV POS. User dapat membuat inbound request, memilih file CSV, memvalidasi format, mengimpor ke staging, dan meninjau hasil tanpa memasukkan data langsung satu per satu.

## Recommended Layout

```text
+------------------------------------------------------------------+
| RSC POS Import Center                                            |
+------------------------------------------------------------------+
| Source System [________]  Outlet [________]  Profile [Minimal v1] |
| Source Ref    [____________________]  Idempotency Key [________]  |
|                                                                  |
| [New Import] [Download Template] [Browse / Attach CSV]            |
| File Name [____________________________]  Status [________]       |
|                                                                  |
| [Validate File] [Import to Staging] [Cancel Import]               |
+------------------------------------------------------------------+
| Validation Summary                                               |
| Rows [___] Valid [___] Error [___] Transactions [___]             |
| Period [________] to [________] Total [____________]               |
| Message [____________________________________________________]    |
+------------------------------------------------------------------+
| Tabs                                                             |
| [Imported Rows] [Errors / Logs] [Generated Batch] [Attachment]    |
+------------------------------------------------------------------+
```

## Collections

### Primary Collection

```text
IDO        : SMKRSCPosInbounds
Alias      : Inbound
Order By   : ReceivedDate DESC
Purpose    : Current import request and import history
```

### Secondary Collection — Raw Lines

```text
IDO        : SMKRSCPosRawLines
Filter     : BatchNum = Inbound.BatchNum
Order By   : SourceRowNum
Read Only  : Yes on this form
```

### Secondary Collection — Process Logs

```text
IDO        : SMKRSCPosProcessLogs
Filter     : RequestId = Inbound.RequestId OR BatchNum = Inbound.BatchNum
Order By   : StartedDate DESC, LogId DESC
Read Only  : Yes
```

### Optional Secondary Collection — Batch

```text
IDO        : SMKRSCPosBatches
Filter     : BatchNum = Inbound.BatchNum
Cardinality: 0..1
Read Only  : Yes on this form
```

## Header Components

| Component | Binding / Variable | Required | Notes |
|---|---|---:|---|
| Source System | form variable before create; then `SourceSystem` | Yes | Default may be `PIZZAHUT_POS` |
| Outlet Code | form variable; then `OutletCode` | Yes | Lookup to outlet map when available |
| Import Profile | form variable | Yes | Initial value `POS_MINIMAL_V1` |
| Source Reference | `SourceReference` | No | File/business reference |
| Idempotency Key | `IdempotencyKey` | No | May be generated or supplied |
| Request ID | `RequestId` | System | Read-only |
| Inbound ID | `InboundId` | System | Hidden/read-only |
| File Name | form variable / attachment metadata | System | Read-only after attach |
| Status | `Stat` | System | Read-only |
| Batch Number | `BatchNum` | System | Read-only with drilldown |

## Validation Summary Components

These values are returned by `ValidateAttachedCsv` and held in form variables until import:

```text
ValidationRowCount
ValidationValidCount
ValidationErrorCount
ValidationTransCount
ValidationPeriodStart
ValidationPeriodEnd
ValidationTotalAmt
ValidationMessage
ValidationPassedFlag
SelectedDocumentId
SelectedFileName
```

After import, authoritative values come from inbound and batch records.

## Buttons and Events

### New Import

Event:

```text
SMKPosNewManualImport
```

Action:

```text
Invoke SMKRSCPosIntegration.CreateManualInbound
Refresh primary collection by returned InboundId
Enable attachment action
```

### Download Template

Event:

```text
SMKPosDownloadMinimalTemplate
```

Action candidate:

- open/download an approved document object;
- or open a controlled URL/resource containing `pos-minimal-v1.csv`.

No editable template is generated from the current table metadata. Template version is explicit and controlled.

### Browse / Attach CSV

Event:

```text
SMKPosAttachCsv
```

PoC response:

```text
Open Attached Documents for current SMKRSCPosInbounds row
User clicks Import and selects local .csv file
Return/select the attachment reference
```

Button is disabled until `InboundId` exists.

### Validate File

Event:

```text
SMKPosValidateCsv
```

Action:

```text
Invoke SMKRSCPosIntegration.ValidateAttachedCsv
Set validation form variables
Refresh process logs
Enable Import to Staging only when validation passes
```

### Import to Staging

Event:

```text
SMKPosImportCsv
```

Action:

```text
Prompt confirmation
Invoke SMKRSCPosIntegration.ImportAttachedCsv
Refresh inbound
Refresh generated batch
Refresh raw lines
Refresh process logs
Disable re-import after success
```

### View Errors

Changes active notebook tab to Errors / Logs and filters by current request or batch.

### Open Batch

Opens the batch form filtered by `BatchNum`.

### Review Raw Lines

Opens the raw-line review form filtered by `BatchNum` or activates the Imported Rows tab.

### Cancel Import

Calls controlled cancel method only when no processed/posted batch exists.

## Button Enablement

| Button | Enabled When |
|---|---|
| New Import | user has PROCESS authorization |
| Download Template | always for authorized import user |
| Browse / Attach CSV | current inbound exists and is not purged/cancelled |
| Validate File | attachment selected and inbound is not successfully imported |
| Import to Staging | validation passed and no batch already exists |
| Cancel Import | batch is empty/not posted and inbound is cancellable |
| Open Batch | `BatchNum` is not blank |
| Review Raw Lines | `BatchNum` is not blank |

## Status Display

Recommended visual text:

```text
R = File/request received
P = File parsed
V = Import completed and linked to valid staging batch
E = Validation/import error
C = Cancelled
```

Do not let users edit status directly.

## Attachment Rules

- accept `.csv` only for `POS_MINIMAL_V1`;
- retain attachment until configured retention date;
- never store authorization header, password, token, API key, PIN, CVV, or full card data;
- do not allow user to type a server path;
- select/upload the file through the attachment mechanism;
- attachment name and hash are used for audit and duplicate checking;
- deleting an attachment after import requires admin-controlled purge logic.

## Form Authorization

| Security Class | Permission |
|---|---|
| `SMK_RSC_POS_VIEW` | View import history and results |
| `SMK_RSC_POS_PROCESS` | Create, attach, validate, and import |
| `SMK_RSC_POS_PAYLOAD_VIEW` | Open/download retained source file |
| `SMK_RSC_POS_ADMIN` | Cancel, purge, and administer |

## PoC Implementation Order

```text
1. Create minimum tables
2. Create minimum entity IDOs
3. Create service IDO shell
4. Implement CreateManualInbound
5. Build Import Center form header
6. Connect Attached Documents
7. Implement ValidateAttachedCsv
8. Implement ImportAttachedCsv
9. Add raw-line and process-log tabs
10. Execute minimal CSV tests
```

## Acceptance Test

Using `pos-minimal-v1.csv`:

```text
Expected inbound count    : 1
Expected batch count      : 1
Expected raw-line count   : 3
Expected transaction count: 2
Expected total amount     : 350000
Expected error count      : 0
```

Re-uploading the same file with the same idempotency identity must not create a second batch.
