# IDO 01 — SMKRSCPosInbounds

## Identity

```text
IDO Project       : SMK_RSC_POS
IDO Name          : SMKRSCPosInbounds
Display Name      : POS Inbound Requests
Base Object       : SMK_RSC_POS_Inbound_mst
Physical Table    : dbo.ue_SMK_RSC_POS_Inbound_mst
Primary Key       : InboundId
Default Order     : ReceivedDate DESC
Design Status     : Candidate / PoC
```

IDO ini digunakan untuk monitoring request yang diterima, duplicate/idempotency tracing, parsing result, optional raw-payload access, retry, dan retention/purge administration.

## Responsibility

IDO ini bertanggung jawab untuk:

- menampilkan daftar inbound request;
- menampilkan request identity dan status parsing;
- menautkan request dengan batch yang dihasilkan;
- menampilkan accepted/rejected counts;
- membantu investigasi error penerimaan;
- menyediakan controlled retry dan controlled payload purge;
- mempertahankan audit metadata walaupun payload gagal diparsing.

IDO ini **bukan endpoint utama untuk direct insert request POS**. Penerimaan API nantinya diarahkan melalui service IDO `SMKRSCPosIntegration`.

## Collection Behavior

| Capability | Candidate Setting |
|---|---|
| Load/query | Enabled sesuai authorization |
| Insert dari form | Disabled secara default |
| Insert dari public REST | Disabled |
| Update source metadata | Disabled setelah receive |
| Update process result | Server-side only |
| Delete | Disabled |
| Retry parse | Custom method |
| Read raw payload | Restricted custom method |
| Purge raw payload | Restricted custom method |

## Primary Key

| IDO Property | Table Column | Type | Key |
|---|---|---|---:|
| `InboundId` | `inbound_id` | `RowPointerType` / `uniqueidentifier` | 1 |

`RequestId` dan `IdempotencyKey` tetap business identifiers, tetapi tidak dijadikan primary key sampai format dan uniqueness dari source resmi dipastikan.

## Property Mapping

| IDO Property | Column | Data Type | Required | Update Policy | Default Collection |
|---|---|---|---:|---|---:|
| `InboundId` | `inbound_id` | RowPointerType | Yes | Read-only after insert | Yes |
| `RequestId` | `request_id` | nvarchar(50) | Yes | Immutable | Yes |
| `IdempotencyKey` | `idempotency_key` | nvarchar(100) | No | Immutable | Yes |
| `CorrelationId` | `correlation_id` | nvarchar(50) | No | Immutable | Yes |
| `SourceSystem` | `source_system` | nvarchar(30) | Yes | Immutable | Yes |
| `SourceReference` | `source_reference` | nvarchar(100) | No | Immutable | Yes |
| `OutletCode` | `outlet_code` | nvarchar(20) | No | Immutable | Yes |
| `EndpointName` | `endpoint_name` | nvarchar(100) | No | Immutable | Yes |
| `HttpMethod` | `http_method` | nvarchar(10) | Yes | Immutable | No |
| `ContentType` | `content_type` | nvarchar(100) | Yes | Immutable | Yes |
| `PayloadVersion` | `payload_version` | nvarchar(20) | Yes | Immutable | Yes |
| `PayloadFormat` | `payload_format` | nchar(1) | Yes | Immutable | Yes |
| `StorageMode` | `storage_mode` | nchar(1) | Yes | Server-controlled | Yes |
| `PayloadText` | `payload_text` | nvarchar(max) | No | Restricted/server-controlled | No |
| `PayloadLocation` | `payload_location` | nvarchar(500) | No | Restricted/server-controlled | No |
| `ContentLength` | `content_length` | bigint | Yes | Immutable | Yes |
| `PayloadSha256` | `payload_sha256` | nvarchar(64) | No | Immutable | No |
| `ClientIp` | `client_ip` | nvarchar(45) | No | Immutable | No |
| `UserAgent` | `user_agent` | nvarchar(500) | No | Immutable | No |
| `ReceivedDate` | `received_date` | CurrentDateType | Yes | Read-only | Yes |
| `Stat` | `stat` | nchar(1) | Yes | Server-controlled | Yes |
| `ParsedDate` | `parsed_date` | DateType | No | Server-controlled | Yes |
| `BatchNum` | `batch_num` | nvarchar(30) | No | Server-controlled | Yes |
| `RowCount` | `row_count` | int | Yes | Server-controlled | Yes |
| `AcceptedCount` | `accepted_count` | int | Yes | Server-controlled | Yes |
| `RejectedCount` | `rejected_count` | int | Yes | Server-controlled | Yes |
| `ResponseCode` | `response_code` | int | No | Server-controlled | Yes |
| `ResponseMessage` | `response_message` | nvarchar(1000) | No | Server-controlled | Yes |
| `ErrorMsg` | `error_msg` | nvarchar(4000) | No | Server-controlled | Yes |
| `RetryCount` | `retry_count` | int | Yes | Method-controlled | Yes |
| `RetentionDate` | `retention_date` | DateType | No | Admin/method-controlled | Yes |
| `PurgedFlag` | `purged_flag` | FlagNyType | Yes | Method-controlled | Yes |
| `PurgedDate` | `purged_date` | DateType | No | Method-controlled | Yes |
| `CreateDate` | `CreateDate` | CurrentDateType | Yes | Framework | No |
| `CreatedBy` | `CreatedBy` | UsernameType | Yes | Framework | No |
| `InWorkflow` | `InWorkflow` | FlagNyType | Yes | Framework | No |
| `NoteExistsFlag` | `NoteExistsFlag` | FlagNyType | Yes | Framework | No |
| `RecordDate` | `RecordDate` | CurrentDateType | Yes | Framework | Yes |
| `RowPointer` | `RowPointer` | RowPointerType | Yes | Framework/read-only | Yes |
| `SiteRef` | `SiteRef` | SiteType | Yes | Framework/site-controlled | Yes |
| `UpdatedBy` | `UpdatedBy` | UsernameType | Yes | Framework | No |

## Default Property List

Default list untuk form monitoring dan query normal:

```text
InboundId
RequestId
IdempotencyKey
CorrelationId
SourceSystem
SourceReference
OutletCode
ContentType
PayloadVersion
PayloadFormat
StorageMode
ContentLength
ReceivedDate
Stat
ParsedDate
BatchNum
RowCount
AcceptedCount
RejectedCount
ResponseCode
ResponseMessage
ErrorMsg
RetryCount
RetentionDate
PurgedFlag
PurgedDate
RecordDate
RowPointer
SiteRef
```

Property berikut dikeluarkan dari default collection karena security, ukuran, atau kebutuhan yang jarang:

```text
PayloadText
PayloadLocation
PayloadSha256
ClientIp
UserAgent
HttpMethod
```

## Status Values

| Value | Meaning |
|---|---|
| `R` | Received |
| `P` | Parsed |
| `V` | Validated and linked to batch |
| `E` | Receive/parse/validation error |
| `C` | Cancelled |

Status transition yang diperbolehkan secara umum:

```text
R → P → V
R → E
P → E
E → P/V melalui controlled retry
R/P/E → C melalui controlled cancellation
```

Record `V` tidak boleh diubah kembali menjadi `R` melalui direct update.

## Subcollection

### Generated Batch

```text
Parent IDO       : SMKRSCPosInbounds
Child IDO        : SMKRSCPosBatches
Parent Property  : BatchNum
Child Property   : BatchNum
Cardinality      : 0..1
```

Inbound dapat tidak memiliki batch ketika request ditolak atau parsing gagal.

Subcollection batch bersifat read-only dari form inbound. Pembuatan batch dilakukan oleh service method.

## Candidate Derived Properties

Derived properties dapat ditambahkan pada monitor IDO atau sebagai calculated property, bukan wajib pada entity IDO awal.

| Property | Logic |
|---|---|
| `PayloadAvailable` | `PurgedFlag = 0` dan payload text/location tersedia |
| `HasError` | `Stat = 'E'` atau `ErrorMsg` tidak kosong |
| `IsLinkedToBatch` | `BatchNum` tidak kosong |
| `IsPartialAccept` | `AcceptedCount > 0` dan `RejectedCount > 0` |
| `CanRetry` | status/error memenuhi retry policy |
| `CanPurge` | retention date terlewati dan payload belum dipurge |

## Custom Methods

### 1. GetInboundPayload

Purpose: mengambil raw payload secara terbatas untuk troubleshooting.

```text
Method Name : GetInboundPayload
Security    : SMK_RSC_POS_PAYLOAD_VIEW atau SMK_RSC_POS_ADMIN
Transaction : Read-only
```

Input:

| Parameter | Type | Required |
|---|---|---:|
| `InboundId` | uniqueidentifier/string | Yes |

Output:

| Parameter | Type | Description |
|---|---|---|
| `StorageMode` | string | D/E/N |
| `PayloadText` | long text | Hanya bila diizinkan dan belum dipurge |
| `PayloadLocation` | string | Hanya approved location/reference |
| `PayloadSha256` | string | Hash payload |
| `PurgedFlag` | boolean | Payload sudah dipurge atau belum |
| `Message` | string | Hasil akses |

Rules:

- authorization wajib diperiksa;
- payload harus sudah dimasking;
- secret/token/card data dilarang dikembalikan;
- access dapat dicatat ke process/security log;
- record `PurgedFlag = 1` tidak mengembalikan payload.

### 2. RetryParse

Purpose: mencoba ulang parsing request yang gagal tanpa membuat duplicate batch.

```text
Method Name : RetryParse
Security    : SMK_RSC_POS_PROCESS atau SMK_RSC_POS_ADMIN
```

Input:

| Parameter | Type | Required |
|---|---|---:|
| `InboundId` | uniqueidentifier/string | Yes |
| `ForceFlag` | boolean | No |

Output:

| Parameter | Type | Description |
|---|---|---|
| `Success` | boolean | Hasil retry |
| `Stat` | string | Status terbaru |
| `BatchNum` | string | Batch yang ada/terbentuk |
| `RetryCount` | int | Jumlah retry terbaru |
| `AcceptedCount` | int | Row diterima |
| `RejectedCount` | int | Row ditolak |
| `Message` | string | Ringkasan hasil |

Rules:

- inbound harus tersedia;
- payload harus masih tersedia;
- idempotency diperiksa sebelum pembuatan batch;
- batch existing tidak boleh dibuat ulang tanpa controlled recovery rule;
- retry membuat process log baru;
- `RetryCount` dinaikkan;
- source payload tidak diubah.

### 3. PurgePayload

Purpose: menghapus raw payload sesuai retention policy tanpa menghapus audit metadata.

```text
Method Name : PurgePayload
Security    : SMK_RSC_POS_ADMIN
```

Input:

| Parameter | Type | Required |
|---|---|---:|
| `InboundId` | uniqueidentifier/string | Yes |
| `Reason` | string | Yes |

Output:

| Parameter | Type |
|---|---|
| `Success` | boolean |
| `PurgedFlag` | boolean |
| `PurgedDate` | datetime |
| `Message` | string |

Rules:

- retention policy harus terpenuhi kecuali approved override;
- payload text/location dibersihkan sesuai storage mode;
- metadata request, hash bila diizinkan, counts, status, batch reference, dan audit columns tetap dipertahankan;
- operasi purge dicatat pada log;
- purge kedua bersifat idempotent dan tidak menghasilkan error yang menyesatkan.

## Event/Validation Rules

### Before Insert

Direct insert normalnya disabled. Bila digunakan untuk administrative test:

- `InboundId` harus tersedia atau dibuat oleh framework;
- `RequestId` dan `SourceSystem` wajib;
- validate payload format dan storage mode;
- content length tidak boleh negatif;
- prohibited secret/card data tidak boleh disimpan;
- duplicate/idempotency check tetap dilakukan.

### Before Update

- source identity dan request metadata immutable;
- direct change `Stat`, `BatchNum`, counts, response, retry, atau purge fields ditolak kecuali berasal dari approved server-side process;
- `PurgedFlag = 1` mensyaratkan `PurgedDate` terisi;
- record yang linked ke processed/posted batch tidak boleh di-reset secara manual.

### Before Delete

Delete ditolak. Koreksi menggunakan status, retention, atau controlled archival process.

## Authorization Matrix

| Action | VIEW | PROCESS | PAYLOAD_VIEW | ADMIN |
|---|---:|---:|---:|---:|
| Query metadata | Yes | Yes | Yes | Yes |
| View raw payload | No | No | Yes | Yes |
| Retry parse | No | Yes | No | Yes |
| Purge payload | No | No | No | Yes |
| Direct insert/update/delete | No | No | No | Normally No; controlled only |

Final authorization tetap mengikuti security model tenant.

## Default Filters and Index Alignment

Form/query utama harus mendukung filter:

```text
SiteRef
SourceSystem
RequestId
IdempotencyKey
CorrelationId
OutletCode
ReceivedDate range
Stat
BatchNum
PurgedFlag
```

Filter tersebut selaras dengan candidate indexes tabel inbound:

```text
SiteRef, source_system, request_id
SiteRef, source_system, idempotency_key
SiteRef, payload_sha256
SiteRef, stat, received_date
SiteRef, batch_num
```

## Suggested Form Usage

Candidate form:

```text
SMK RSC POS Inbound Requests
```

Grid utama:

```text
Received Date
Request ID
Source System
Outlet
Payload Version
Status
Batch Number
Rows
Accepted
Rejected
Response Code
Retry Count
Purged
```

Detail tabs:

```text
1. Request Metadata
2. Parsing Result
3. Error Detail
4. Generated Batch
5. Process Log
6. Raw Payload — restricted
```

## API Exposure

Query metadata dapat dipertimbangkan untuk authorized internal clients. Penerimaan request tidak menggunakan direct `UpdateCollection` ke IDO ini.

Recommended flow:

```text
Client
  → SMKRSCPosIntegration.ReceiveCompleteBatch()
  atau
  → SMKRSCPosIntegration.ReceiveMinimalBatch()
        → create SMKRSCPosInbounds record internally
```

## Test Scenarios

1. Query inbound by date and status.
2. Request valid linked to one batch.
3. Parsing error with `BatchNum = NULL`.
4. Duplicate `IdempotencyKey` does not create second batch.
5. Same payload hash detected according to policy.
6. Retry error request successfully creates/links batch.
7. Retry request with existing batch does not duplicate staging.
8. Unauthorized user cannot read payload.
9. Authorized payload access returns masked content only.
10. Purge removes payload but preserves metadata.
11. Purge executed twice remains idempotent.
12. Direct update to source identity/status is rejected.
13. Direct delete is rejected.
14. Site isolation prevents cross-site access.
15. Large payload behavior is verified against tenant limits.

## Open Verification Items

- Exact IDO project and naming standard accepted by tenant.
- Whether `nvarchar(max)` can be exposed safely as an IDO property.
- Maximum load/serialization size for payload property.
- Tenant authorization class implementation.
- Best server-side implementation for retry and purge methods.
- Audit requirement when raw payload is viewed.
- Exact relationship implementation to `SMKRSCPosBatches`.
- Whether raw payload should remain outside normal entity IDO entirely.
