# Implementation 01 — Create First Inbound IDO

## Scope

Dokumen ini hanya mencakup pembuatan IDO pertama pada tenant yang menggunakan Access As/object prefix `ue_`.

```text
IDO Project        : ue_SMKRSCPos
Logical IDO Name   : SMKRSCPosInbounds
Final IDO Name     : ue_SMKRSCPosInbounds
Architectural Role : Entity IDO
Logical Table      : SMK_RSC_POS_Inbound_mst
Physical Table     : dbo.ue_SMK_RSC_POS_Inbound_mst
Table Alias        : i
Primary Key        : InboundId -> inbound_id
```

Form import CSV, subcollection, custom methods, REST API, dan service processing belum dibuat pada langkah ini.

## Access As and Prefix Rule

Environment ini menggunakan prefix custom object:

```text
Access As / Object Prefix : ue_
IDO Project               : ue_SMKRSCPos
Final IDO                  : ue_SMKRSCPosInbounds
```

Ketika process default **Enforce prefix from Access As** aktif, Mongoose menambahkan prefix Access As pada IDO dan table yang dibuat.

Aturan penting:

```text
Jangan sampai menjadi:
ue_ue_SMKRSCPosInbounds
```

Pada IDO Wizard:

1. pilih project persis seperti yang tersedia: `ue_SMKRSCPos`;
2. lihat nilai read-only `Access As`;
3. lihat isi field `IDO Name` setelah memilih primary base table;
4. bila wizard sudah menampilkan `ue_SMKRSCPosInbounds`, jangan tambah `ue_` lagi;
5. bila field hanya meminta nama dasar, isi `SMKRSCPosInbounds`, lalu verifikasi hasil akhirnya menjadi `ue_SMKRSCPosInbounds` setelah Finish.

Nama aktual yang tampil pada tenant menjadi sumber kebenaran.

## Prerequisite Check

Sebelum menjalankan wizard, pastikan:

```text
[ ] IDO Project ue_SMKRSCPos tersedia
[ ] Access As pada project sesuai tenant
[ ] Enforce prefix behavior sudah dipahami
[ ] Inbound table tersedia pada Primary Base Table list
[ ] inbound_id adalah primary key sequence 1
[ ] RecordDate tersedia
[ ] RowPointer tersedia dan unik
[ ] SiteRef tersedia
[ ] User memiliki authorization development metadata
```

## Step 1 — Verify IDO Project

Buka form:

```text
IDO Projects
```

Cari:

```text
ue_SMKRSCPos
```

Gunakan project tersebut. Jangan membuat project baru bernama `SMKRSCPos` karena project aktual tenant sudah memakai prefix `ue_`.

Periksa field:

```text
Project Name : ue_SMKRSCPos
Access As    : nilai aktual tenant, kemungkinan ue_
Description  : RSC POS Integration Custom IDOs
```

## Step 2 — Launch New IDO Wizard

Dari form `IDO Projects` atau `IDOs`, klik:

```text
New IDO
```

Isi halaman pertama:

```text
Project Name       : ue_SMKRSCPos
Primary Base Table : pilih inbound table yang benar-benar tampil di dropdown
Table Alias        : i
IDO Name           : ikuti prefix behavior wizard
Extends             : kosong
```

### Primary Base Table

Nama yang mungkin tampil bergantung pada metadata tenant:

```text
SMK_RSC_POS_Inbound_mst
```

atau:

```text
ue_SMK_RSC_POS_Inbound_mst
```

Pilih object yang memang terhubung ke physical table:

```text
dbo.ue_SMK_RSC_POS_Inbound_mst
```

Jangan menebak nama. Gunakan yang tersedia pada dropdown dan cocok dengan Application Schema/SQL Tables metadata.

### IDO Name

Target final:

```text
ue_SMKRSCPosInbounds
```

Kemungkinan tampilan wizard:

```text
Kasus A — wizard sudah memberi prefix
IDO Name : ue_SMKRSCPosInbounds
Action   : biarkan
```

```text
Kasus B — wizard meminta nama dasar dan menambah prefix saat Finish
IDO Name : SMKRSCPosInbounds
Action   : verifikasi hasil final sesudah Finish
```

Klik `Next` hanya setelah memastikan prefix tidak akan menjadi ganda.

## Step 3 — Generate Bound Properties

Pada halaman properties:

1. biarkan seluruh column yang dibutuhkan tetap dicentang;
2. gunakan `Massage Property Names` bila tersedia;
3. ubah property menjadi PascalCase;
4. periksa key dan nullable setelah wizard selesai.

Mapping utama:

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

`PayloadText` tetap dibuat sebagai property, tetapi tidak digunakan pada grid/default collection awal.

Klik `Finish`.

## Step 4 — Review the Created IDO

Target hasil akhir:

```text
IDO Name      : ue_SMKRSCPosInbounds
Project       : ue_SMKRSCPos
Primary Table : inbound table aktual tenant
Alias         : i
Access As     : sesuai tenant
```

### Key Review

```text
Property     : InboundId
Bound Column : inbound_id
Key          : Yes
Key Sequence : 1
Nullable     : No
```

`RowPointer` tetap framework identifier dan tidak menggantikan `InboundId` sebagai primary key rancangan.

### Framework Properties

Pastikan tersedia:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
SiteRef
UpdatedBy
```

## Step 5 — Save and Check In

```text
Save
Check In
```

Candidate check-in comment:

```text
Create ue_SMKRSCPosInbounds entity IDO for POS inbound staging
```

## Step 6 — Smoke Test

Gunakan IDO Data Viewer atau collection test tool.

```text
IDO        : ue_SMKRSCPosInbounds
Properties : InboundId, RequestId, SourceSystem, ReceivedDate, Stat, RowPointer, SiteRef
Filter     : kosong
Expected   : LoadCollection berhasil
```

`0 records returned` tetap PASS bila tabel belum memiliki data.

## Stop Point

Langkah pertama selesai ketika:

```text
[ ] Project ue_SMKRSCPos dipilih
[ ] Final IDO name ue_SMKRSCPosInbounds
[ ] Tidak terjadi prefix ganda
[ ] InboundId key sequence 1
[ ] Framework properties tersedia
[ ] Object sudah Check In
[ ] LoadCollection berhasil
```

Belum membuat:

```text
CSV Browse/Upload
Import Form
Custom Methods
Service IDO
Subcollection Batch
REST API
```

## Evidence

Simpan:

```text
1. Screenshot IDO Wizard halaman pertama
2. Screenshot field Access As dan IDO Name
3. Screenshot property generation
4. Screenshot InboundId sebagai key
5. Screenshot successful LoadCollection
6. Check-in record
```
