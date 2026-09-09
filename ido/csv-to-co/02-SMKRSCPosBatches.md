# 02 — SMKRSCPosBatches

## Identity

```text
IDO Project        : SMK_RSC_POS
IDO Name           : SMKRSCPosBatches
Display Name       : POS Batches
Architectural Role : Entity IDO
Primary Base Table : SMK_RSC_POS_Batch_mst
Physical Table     : dbo.ue_SMK_RSC_POS_Batch_mst
Table Alias        : b
Primary Key        : BatchNum
Default Order      : ReceivedDate DESC, BatchNum DESC
Status             : Candidate design / PoC
```

## Purpose

`SMKRSCPosBatches` adalah entity IDO untuk query, form binding, filter, dan penelusuran status satu batch penerimaan data POS.

IDO ini tidak digunakan sebagai endpoint direct-write publik. Penerimaan batch dari REST/Postman diarahkan melalui controlled method pada candidate service IDO `SMKRSCPosIntegration`.

## Create Through IDO Wizard

### Prerequisite

Sebelum menjalankan wizard:

- IDO Project `SMK_RSC_POS` sudah tersedia;
- table metadata `SMK_RSC_POS_Batch_mst` sudah dibuat;
- physical table Cloud telah diverifikasi sebagai `dbo.ue_SMK_RSC_POS_Batch_mst`;
- primary key dan standard Mongoose columns sudah tersedia;
- object telah di-check-in sesuai prosedur tenant.

### Candidate Wizard Values

```text
Project Name       : SMK_RSC_POS
Primary Base Table : SMK_RSC_POS_Batch_mst
IDO Name           : SMKRSCPosBatches
Table Alias         : b
Extends             : kosong
```

Nama field serta urutan halaman dapat berbeda sesuai versi dan konfigurasi tenant, tetapi nilai konseptualnya tetap seperti di atas.

### Wizard Flow

```text
Open IDOs / IDO Projects
        ↓
New IDO
        ↓
Select Project: SMK_RSC_POS
        ↓
Select Primary Base Table: SMK_RSC_POS_Batch_mst
        ↓
Set IDO Name: SMKRSCPosBatches
        ↓
Set table alias: b
        ↓
Create/select properties from table columns
        ↓
Review key and property metadata
        ↓
Finish
        ↓
Check In
```

Wizard hanya membuat metadata awal. Setelah selesai, lakukan review manual pada property names, key, update policy, default property list, subcollections, security, dan methods.

## Property Mapping

| IDO Property | Table Column | Data Role | Default Collection | Update Policy |
|---|---|---|---:|---|
| `BatchNum` | `batch_num` | Source/business key | Yes | Server-controlled |
| `ExtBatchNum` | `ext_batch_num` | Source reference | Yes | Immutable after receive |
| `RequestId` | `request_id` | Inbound request reference | Yes | Immutable after receive |
| `SourceSystem` | `source_system` | Source identity | Yes | Immutable after receive |
| `InputType` | `input_type` | Complete/minimal/other profile | Yes | Server-controlled |
| `OutletCode` | `outlet_code` | Source outlet | Yes | Immutable after receive |
| `PeriodStart` | `period_start` | Source period | Yes | Immutable after receive |
| `PeriodEnd` | `period_end` | Source period | Yes | Immutable after receive |
| `ReceivedDate` | `received_date` | Receive timestamp | Yes | Read-only |
| `TransCount` | `trans_count` | Reconciled transaction count | Yes | Server-controlled |
| `GrossAmt` | `gross_amt` | Reconciled gross amount | Yes | Server-controlled |
| `DiscountAmt` | `discount_amt` | Reconciled discount | Yes | Server-controlled |
| `TaxAmt` | `tax_amt` | Reconciled tax | Yes | Server-controlled |
| `ServiceAmt` | `service_amt` | Reconciled service amount | Yes | Server-controlled |
| `RoundingAmt` | `rounding_amt` | Reconciled rounding | Yes | Server-controlled |
| `NetAmt` | `net_amt` | Reconciled net amount | Yes | Server-controlled |
| `PaymentAmt` | `payment_amt` | Reconciled payment amount | Yes | Server-controlled |
| `Stat` | `stat` | Process status | Yes | Server-controlled |
| `ValidationMsg` | `validation_msg` | Validation summary | Yes | Server-controlled |
| `ErrorMsg` | `error_msg` | Last error | Yes | Server-controlled |
| `ValidateDate` | `validate_date` | Validation timestamp | Yes | Server-controlled |
| `ProcessDate` | `process_date` | Processing timestamp | Yes | Server-controlled |
| `ProcessedBy` | `processed_by` | Processing user/service | Yes | Server-controlled |
| `SyteLineRef` | `syteline_ref` | Result reference | Yes | Server-controlled |
| `RetryCount` | `retry_count` | Retry counter | Yes | Server-controlled |
| `CreateDate` | `CreateDate` | Framework audit | No | Framework |
| `CreatedBy` | `CreatedBy` | Framework audit | No | Framework |
| `InWorkflow` | `InWorkflow` | Framework flag | No | Framework |
| `NoteExistsFlag` | `NoteExistsFlag` | Framework flag | No | Framework |
| `RecordDate` | `RecordDate` | Optimistic/audit timestamp | Yes | Framework |
| `RowPointer` | `RowPointer` | Framework identifier | Yes | Read-only |
| `SiteRef` | `SiteRef` | Site owner | Yes | Framework/server-controlled |
| `UpdatedBy` | `UpdatedBy` | Framework audit | No | Framework |

## Primary Key and Identity

```text
Business Primary Key : BatchNum
Framework Identifier : RowPointer
```

`RowPointer` tidak menggantikan `BatchNum` sebagai business key.

Candidate key review after wizard:

```text
Property : BatchNum
Key      : Yes
Sequence : 1
Nullable : No
```

Kebutuhan memasukkan `SiteRef` ke business key harus diverifikasi terhadap standard tenant sebelum produksi.

## Default Property List

Untuk grid monitoring, property list awal yang disarankan:

```text
BatchNum,
ExtBatchNum,
RequestId,
SourceSystem,
InputType,
OutletCode,
PeriodStart,
PeriodEnd,
ReceivedDate,
TransCount,
GrossAmt,
DiscountAmt,
TaxAmt,
ServiceAmt,
RoundingAmt,
NetAmt,
PaymentAmt,
Stat,
ValidationMsg,
ErrorMsg,
ValidateDate,
ProcessDate,
ProcessedBy,
SyteLineRef,
RetryCount,
RecordDate,
RowPointer,
SiteRef
```

Framework fields yang tidak diperlukan pada grid tidak perlu dimuat secara default.

## Status Model

| Value | Meaning |
|---|---|
| `N` | New |
| `R` | Received |
| `V` | Validated / Ready |
| `I` | In Process |
| `P` | Processed |
| `E` | Error |
| `C` | Cancelled |

Candidate normal transition:

```text
N → R → V → I → P
```

Candidate error/retry transition:

```text
R → E
V → E
I → E
E → V setelah controlled retry berhasil
```

Status tidak boleh diedit manual melalui grid.

## Input Type

Candidate values:

| Value | Meaning |
|---|---|
| `C` | Complete profile: transaction, lines, payments |
| `M` | Minimal/flat profile: raw lines |
| `A` | Auto-detected/unspecified candidate |
| `O` | Other future profile |

Nilai final menunggu payload resmi.

## Subcollections

Subcollection tidak harus dibuat pada wizard pertama. Tambahkan bertahap setelah child IDO tersedia.

### Complete Profile

```text
Parent IDO      : SMKRSCPosBatches
Child IDO       : SMKRSCPosTrans
Parent Property : BatchNum
Child Property  : BatchNum
Cardinality     : 1..n
Subcollection   : Transactions
```

### Minimal Profile

```text
Parent IDO      : SMKRSCPosBatches
Child IDO       : SMKRSCPosRawLines
Parent Property : BatchNum
Child Property  : BatchNum
Cardinality     : 1..n
Subcollection   : RawLines
```

`Transactions` dan `RawLines` merupakan alternative source profiles. Form dapat menampilkan tab sesuai `InputType`.

### Process Logs

```text
Parent IDO      : SMKRSCPosBatches
Child IDO       : SMKRSCPosProcessLogs
Parent Property : BatchNum
Child Property  : BatchNum
Cardinality     : 1..n
Subcollection   : ProcessLogs
```

### Posting Preview

```text
Parent IDO      : SMKRSCPosBatches
Child IDO       : SMKRSCPosPostingPreviews
Parent Property : BatchNum
Child Property  : BatchNum
Cardinality     : 1..n
Subcollection   : PostingPreviews
```

## Entity IDO Update Policy

| Operation | Policy |
|---|---|
| `LoadCollection` | Allowed according to authorization/site |
| Direct public insert | Not allowed |
| Direct update source fields | Not allowed after receive |
| Direct update status/result | Not allowed |
| Delete | Not allowed |
| Validate | Call service method |
| Retry | Call service method |
| Generate preview | Call service method |
| Post | Call service method |
| Cancel | Call service method |

Form buttons call methods using `BatchNum`; they do not directly modify `Stat`.

Example:

```text
Button: Validate
Invoke: SMKRSCPosIntegration.ValidateBatch(BatchNum)
```

## Candidate Service Calls from Batch Form

```text
ValidateBatch(BatchNum)
RetryBatch(BatchNum, ForceFlag)
GeneratePostingPreview(BatchNum)
CancelBatch(BatchNum, Reason)
PostBatch(BatchNum)
```

These methods belong to the service IDO layer, not to direct UpdateCollection on `SMKRSCPosBatches`.

## Candidate Security

| Security Class | Access |
|---|---|
| `SMK_RSC_POS_VIEW` | Load batch and child collections |
| `SMK_RSC_POS_PROCESS` | Validate, retry, generate preview, cancel according to policy |
| `SMK_RSC_POS_APPROVE` | Approve/reject preview |
| `SMK_RSC_POS_POST` | Actual posting |
| `SMK_RSC_POS_ADMIN` | Administrative control |

## Candidate Form

```text
Form Name : SMK RSC POS Batch Monitoring
Primary IDO: SMKRSCPosBatches
```

### Header/Grid Columns

```text
Batch Number
External Batch Number
Request ID
Source System
Input Type
Outlet
Period Start
Period End
Received Date
Transaction Count
Net Amount
Payment Amount
Status
Retry Count
SyteLine Reference
```

### Detail Tabs

```text
1. Summary
2. Transactions — complete profile
3. Raw Lines — minimal profile
4. Payments — complete profile
5. Process Logs
6. Posting Preview
7. Error Detail
8. Audit
```

### Candidate Buttons

```text
Validate
Retry
Generate Preview
Approve/Reject Preview
Post
Cancel
Open Inbound Request
Refresh
```

Button visibility and enablement depend on status and authorization.

## Validation Rules Exposed in UI

- `PeriodEnd >= PeriodStart`;
- outlet mapping exists and is active;
- `TransCount` matches complete-profile transaction count or distinct minimal-profile transaction count;
- header totals reconcile to child data;
- complete profile payment amount reconciles;
- batch in `P` status cannot be posted again;
- batch in `E` status requires controlled retry;
- batch with mapping errors cannot generate a final approved preview;
- `SiteRef` access must be enforced.

## Candidate Wizard Review Checklist

After the wizard finishes:

```text
[ ] IDO belongs to SMK_RSC_POS project
[ ] Primary table is SMK_RSC_POS_Batch_mst
[ ] Alias is unique
[ ] BatchNum is key sequence 1
[ ] RowPointer property exists
[ ] RecordDate property exists
[ ] SiteRef property exists
[ ] All amount properties use correct domain/type
[ ] Nullable flags match table metadata
[ ] Property names use agreed PascalCase
[ ] Source fields are not publicly updateable
[ ] Delete is disabled
[ ] Default order is configured
[ ] Entity IDO is not used as public receive endpoint
[ ] Object is checked in
```

## Initial Tests

### Load Test

```text
Filter : BatchNum = 'TEST-BATCH-001'
Expect : exactly one matching record
```

### Sort Test

```text
OrderBy : ReceivedDate DESC
Expect  : latest batch first
```

### Source Immutability Test

Attempt direct update:

```text
OutletCode: TEST01 → TEST02
```

Expected:

```text
Update rejected or blocked by configured policy
```

### Status Protection Test

Attempt direct update:

```text
Stat: R → P
```

Expected:

```text
Update rejected; status only changed by controlled process
```

### Site Isolation Test

User for Site A must not load unauthorized Site B batches.

### Subcollection Test

For minimal batch:

```text
InputType = M
RawLines  = expected child records
Transactions = zero/not used
```

For complete batch:

```text
InputType = C
Transactions = expected child records
RawLines = zero/not used
```

## Open Decisions

- exact wizard labels and behavior on the target Cloud tenant;
- whether `SiteRef` participates in the business key;
- final `InputType` domain values;
- direct collection update restrictions supported by tenant metadata;
- subcollection naming standard;
- whether status descriptions use derived property, string table, or form expression;
- whether amount totals are stored only or recalculated through monitor IDO;
- final service method placement and implementation technology.
