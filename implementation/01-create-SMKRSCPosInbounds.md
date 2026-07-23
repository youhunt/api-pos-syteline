# Implementation 01 — Create `SMKRSCPosInbounds`

## Scope

Dokumen ini hanya mencakup pembuatan IDO pertama:

```text
IDO Project        : SMKRSCPos
IDO Name           : SMKRSCPosInbounds
Architectural Role : Entity IDO
Primary Base Table : SMK_RSC_POS_Inbound_mst
Physical Table     : dbo.ue_SMK_RSC_POS_Inbound_mst
Table Alias        : i
Primary Key        : InboundId -> inbound_id
```

Form import CSV, subcollection, custom methods, security detail, dan REST exposure belum dibuat pada langkah ini.

## Correction: IDO Project Name

Candidate documentation sebelumnya menggunakan `SMK_RSC_POS` sebagai IDO Project. Nama implementasi diganti menjadi:

```text
SMKRSCPos
```

Alasannya: IDO Project harus menggunakan nama alphanumeric tanpa spasi. Nama table/object tetap menggunakan pola `SMK_RSC_POS_...`.

```text
IDO Project : SMKRSCPos
Table Object: SMK_RSC_POS_Inbound_mst
IDO Name    : SMKRSCPosInbounds
```

## Prerequisite Check

Sebelum menjalankan IDO Wizard, pastikan:

```text
[ ] Table metadata SMK_RSC_POS_Inbound_mst tersedia
[ ] Physical table Cloud dbo.ue_SMK_RSC_POS_Inbound_mst tersedia
[ ] inbound_id adalah primary key sequence 1
[ ] RecordDate tersedia
[ ] RowPointer tersedia dan unik
[ ] SiteRef tersedia
[ ] IDO Project SMKRSCPos tersedia
[ ] User memiliki authorization untuk IDO metadata development
```

### Multi-site warning

Periksa pada SQL Tables/Application Schema metadata apakah table dibuat sebagai multi-site table.

- Bila **tidak** menggunakan multi-site view, primary base table candidate adalah `SMK_RSC_POS_Inbound_mst`.
- Bila table ditandai **Multi-Site**, verifikasi view tanpa suffix `_mst` dan bangun IDO di atas view tersebut sesuai standard tenant. Jangan lanjut menggunakan table langsung sampai view dan key/index `SiteRef` telah diverifikasi.

## Step 1 — Create or Verify IDO Project

Buka form:

```text
IDO Projects
```

Cari:

```text
SMKRSCPos
```

Bila belum ada, buat record baru:

```text
Project Name : SMKRSCPos
Description  : RSC POS Integration Custom IDOs
```

Save.

## Step 2 — Launch New IDO Wizard

Dari form `IDO Projects` atau `IDOs`:

```text
New IDO
```

Isi halaman pertama:

```text
Project Name       : SMKRSCPos
Primary Base Table : SMK_RSC_POS_Inbound_mst
Table Alias        : i
IDO Name           : SMKRSCPosInbounds
Extends             : kosong
```

Catatan:

- Gunakan nama metadata table, bukan nama physical table `ue_...`.
- Jangan isi `Extends`, karena IDO ini dibuat langsung dari custom table.
- Bila primary base table tidak muncul, hentikan wizard dan periksa table metadata/project/access-as.

Klik `Next`.

## Step 3 — Generate Bound Properties

Pada halaman property:

1. Biarkan seluruh column yang diperlukan tetap dicentang pada kolom `Inc`.
2. Gunakan `Massage Property Names` bila tersedia untuk membentuk PascalCase.
3. Periksa manual setiap property name sebelum `Finish`.

Mapping yang harus dihasilkan:

| Column | IDO Property |
|---|---|
| `inbound_id` | `InboundId` |
| `request_id` | `RequestId` |
| `idempotency_key` | `IdempotencyKey` |
| `correlation_id` | `CorrelationId` |
| `source_system` | `SourceSystem` |
| `source_reference` | `SourceReference` |
| `outlet_code` | `OutletCode` |
| `endpoint_name` | `EndpointName` |
| `http_method` | `HttpMethod` |
| `content_type` | `ContentType` |
| `payload_version` | `PayloadVersion` |
| `payload_format` | `PayloadFormat` |
| `storage_mode` | `StorageMode` |
| `payload_text` | `PayloadText` |
| `payload_location` | `PayloadLocation` |
| `content_length` | `ContentLength` |
| `payload_sha256` | `PayloadSha256` |
| `client_ip` | `ClientIp` |
| `user_agent` | `UserAgent` |
| `received_date` | `ReceivedDate` |
| `stat` | `Stat` |
| `parsed_date` | `ParsedDate` |
| `batch_num` | `BatchNum` |
| `row_count` | `RowCount` |
| `accepted_count` | `AcceptedCount` |
| `rejected_count` | `RejectedCount` |
| `response_code` | `ResponseCode` |
| `response_message` | `ResponseMessage` |
| `error_msg` | `ErrorMsg` |
| `retry_count` | `RetryCount` |
| `retention_date` | `RetentionDate` |
| `purged_flag` | `PurgedFlag` |
| `purged_date` | `PurgedDate` |
| `CreateDate` | `CreateDate` |
| `CreatedBy` | `CreatedBy` |
| `InWorkflow` | `InWorkflow` |
| `NoteExistsFlag` | `NoteExistsFlag` |
| `RecordDate` | `RecordDate` |
| `RowPointer` | `RowPointer` |
| `SiteRef` | `SiteRef` |
| `UpdatedBy` | `UpdatedBy` |

`PayloadText` tetap boleh menjadi property IDO, tetapi tidak akan dimasukkan ke default property list/form grid karena ukuran dan security.

Klik `Finish`.

## Step 4 — Review the Created IDO

Setelah wizard selesai, IDO biasanya terbuka dan checked out.

Periksa pada form `IDOs`, `IDO Tables`, `IDO Properties`, atau metadata terkait:

```text
IDO Name     : SMKRSCPosInbounds
Project      : SMKRSCPos
Primary Table: SMK_RSC_POS_Inbound_mst
Alias        : i
```

### Key review

Pastikan:

```text
InboundId
- Bound Column : inbound_id
- Key          : Yes
- Key Sequence : 1
- Nullable     : No
```

Jangan mengubah `RowPointer` menjadi business primary key.

### Framework property review

Pastikan property ini tersedia:

```text
RecordDate
RowPointer
SiteRef
CreateDate
CreatedBy
UpdatedBy
```

### Long-text review

Periksa bahwa `PayloadText` berhasil terbentuk dari column `payload_text`. Bila long-text/domain tidak didukung tenant, catat sebagai blocked issue; jangan mengganti tipe diam-diam.

## Step 5 — Save and Check In

Setelah metadata benar:

```text
Save
Check In
```

Gunakan comment/check-in note:

```text
Create SMKRSCPosInbounds entity IDO for POS inbound request staging
```

## Step 6 — Smoke Test

Gunakan `IDO Data Viewer`, form test, atau tool collection test yang tersedia pada tenant.

Test minimum:

```text
IDO          : SMKRSCPosInbounds
Properties   : InboundId, RequestId, SourceSystem, ReceivedDate, Stat, RowPointer, SiteRef
Filter       : kosong
Expected     : LoadCollection berhasil; 0 row tetap dianggap PASS bila table belum berisi data
```

Test metadata:

```text
[ ] IDO dapat dipilih
[ ] LoadCollection tidak error
[ ] Property names sesuai mapping
[ ] InboundId dikenali sebagai key
[ ] RowPointer dan RecordDate tersedia
[ ] PayloadText tidak diperlukan pada smoke-test query
[ ] IDO sudah checked in
```

## Not Yet Implemented

Langkah pertama ini belum mencakup:

```text
- direct insert dari API
- CSV browse/upload
- CreateManualInbound
- ValidateAttachedCsv
- ImportAttachedCsv
- RetryParse
- PurgePayload
- Generated Batch subcollection
- custom form
```

Fitur tersebut ditambahkan setelah entity IDO minimum dapat di-load tanpa error.

## Completion Evidence

Simpan bukti:

```text
1. Screenshot IDO Wizard page 1
2. Screenshot property page
3. Screenshot IDO Properties showing InboundId key
4. Screenshot successful LoadCollection/IDO Data Viewer
5. Check-in note or deployment record
```
