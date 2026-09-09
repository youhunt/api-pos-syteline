# SMK_RSC_POS_Inbound_mst

## Identity

```text
Metadata object : SMK_RSC_POS_Inbound_mst
Physical table  : dbo.ue_SMK_RSC_POS_Inbound_mst
Purpose         : Menyimpan identitas request, metadata penerimaan, raw payload, hasil parsing, dan relasi ke batch
Status          : Candidate design / PoC, menunggu raw payload dan kebijakan retensi resmi
```

Satu record mewakili satu request API, file import, atau submission dari custom form. Record inbound dapat tetap ada walaupun parsing gagal dan `batch_num` belum berhasil dibuat.

## Primary Key

```text
inbound_id
```

`inbound_id` menggunakan `RowPointerType`/`uniqueidentifier` dengan default `newid()` agar setiap request memiliki identifier internal yang aman untuk proses paralel.

## Full Column Structure

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
|---|---|---|---|---|---:|---:|---|---|---:|---:|
| `inbound_id` | dbo | ue_SMK_RSC_POS_Inbound_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 1 | 1 |
| `request_id` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 50 |  |  | NO | 0 |  |
| `idempotency_key` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `correlation_id` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `source_system` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 0 |  |
| `source_reference` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `outlet_code` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `endpoint_name` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `http_method` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 10 |  | `N'POST'` | NO | 0 |  |
| `content_type` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 100 |  | `N'application/json'` | NO | 0 |  |
| `payload_version` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 20 |  | `N'1.0'` | NO | 0 |  |
| `payload_format` | dbo | ue_SMK_RSC_POS_Inbound_mst | nchar | nchar | 1 |  | `N'J'` | NO | 0 |  |
| `storage_mode` | dbo | ue_SMK_RSC_POS_Inbound_mst | nchar | nchar | 1 |  | `N'D'` | NO | 0 |  |
| `payload_text` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | MAX |  |  | YES | 0 |  |
| `payload_location` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 500 |  |  | YES | 0 |  |
| `content_length` | dbo | ue_SMK_RSC_POS_Inbound_mst | bigint | bigint |  |  | `0` | NO | 0 |  |
| `payload_sha256` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 64 |  |  | YES | 0 |  |
| `client_ip` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 45 |  |  | YES | 0 |  |
| `user_agent` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 500 |  |  | YES | 0 |  |
| `received_date` | dbo | ue_SMK_RSC_POS_Inbound_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `stat` | dbo | ue_SMK_RSC_POS_Inbound_mst | nchar | nchar | 1 |  | `N'R'` | NO | 0 |  |
| `parsed_date` | dbo | ue_SMK_RSC_POS_Inbound_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `batch_num` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `row_count` | dbo | ue_SMK_RSC_POS_Inbound_mst | int | int |  |  | `0` | NO | 0 |  |
| `accepted_count` | dbo | ue_SMK_RSC_POS_Inbound_mst | int | int |  |  | `0` | NO | 0 |  |
| `rejected_count` | dbo | ue_SMK_RSC_POS_Inbound_mst | int | int |  |  | `0` | NO | 0 |  |
| `response_code` | dbo | ue_SMK_RSC_POS_Inbound_mst | int | int |  |  |  | YES | 0 |  |
| `response_message` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_Inbound_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `retry_count` | dbo | ue_SMK_RSC_POS_Inbound_mst | int | int |  |  | `0` | NO | 0 |  |
| `retention_date` | dbo | ue_SMK_RSC_POS_Inbound_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `purged_flag` | dbo | ue_SMK_RSC_POS_Inbound_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `purged_date` | dbo | ue_SMK_RSC_POS_Inbound_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_Inbound_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_Inbound_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_Inbound_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_Inbound_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_Inbound_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_Inbound_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_Inbound_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_Inbound_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Tab-delimited Structure

```text
Column Name	Schema	Table Name	Data Type	System Data Type	Length	Decimal Position	Default Value	Is Nullable	Primary Key	Key Sequence
inbound_id	dbo	ue_SMK_RSC_POS_Inbound_mst	RowPointerType	uniqueidentifier			newid()	NO	1	1
request_id	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	50			NO	0	
idempotency_key	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	100			YES	0	
correlation_id	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	50			YES	0	
source_system	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	30		N'POS'	NO	0	
source_reference	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	100			YES	0	
outlet_code	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	20			YES	0	
endpoint_name	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	100			YES	0	
http_method	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	10		N'POST'	NO	0	
content_type	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	100		N'application/json'	NO	0	
payload_version	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	20		N'1.0'	NO	0	
payload_format	dbo	ue_SMK_RSC_POS_Inbound_mst	nchar	nchar	1		N'J'	NO	0	
storage_mode	dbo	ue_SMK_RSC_POS_Inbound_mst	nchar	nchar	1		N'D'	NO	0	
payload_text	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	MAX			YES	0	
payload_location	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	500			YES	0	
content_length	dbo	ue_SMK_RSC_POS_Inbound_mst	bigint	bigint			0	NO	0	
payload_sha256	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	64			YES	0	
client_ip	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	45			YES	0	
user_agent	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	500			YES	0	
received_date	dbo	ue_SMK_RSC_POS_Inbound_mst	CurrentDateType	datetime			getdate()	NO	0	
stat	dbo	ue_SMK_RSC_POS_Inbound_mst	nchar	nchar	1		N'R'	NO	0	
parsed_date	dbo	ue_SMK_RSC_POS_Inbound_mst	DateType	datetime				YES	0	
batch_num	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	30			YES	0	
row_count	dbo	ue_SMK_RSC_POS_Inbound_mst	int	int			0	NO	0	
accepted_count	dbo	ue_SMK_RSC_POS_Inbound_mst	int	int			0	NO	0	
rejected_count	dbo	ue_SMK_RSC_POS_Inbound_mst	int	int			0	NO	0	
response_code	dbo	ue_SMK_RSC_POS_Inbound_mst	int	int				YES	0	
response_message	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	1000			YES	0	
error_msg	dbo	ue_SMK_RSC_POS_Inbound_mst	nvarchar	nvarchar	4000			YES	0	
retry_count	dbo	ue_SMK_RSC_POS_Inbound_mst	int	int			0	NO	0	
retention_date	dbo	ue_SMK_RSC_POS_Inbound_mst	DateType	datetime				YES	0	
purged_flag	dbo	ue_SMK_RSC_POS_Inbound_mst	FlagNyType	tinyint			0	NO	0	
purged_date	dbo	ue_SMK_RSC_POS_Inbound_mst	DateType	datetime				YES	0	
CreateDate	dbo	ue_SMK_RSC_POS_Inbound_mst	CurrentDateType	datetime			getdate()	NO	0	
CreatedBy	dbo	ue_SMK_RSC_POS_Inbound_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
InWorkflow	dbo	ue_SMK_RSC_POS_Inbound_mst	FlagNyType	tinyint			0	NO	0	
NoteExistsFlag	dbo	ue_SMK_RSC_POS_Inbound_mst	FlagNyType	tinyint			0	NO	0	
RecordDate	dbo	ue_SMK_RSC_POS_Inbound_mst	CurrentDateType	datetime			getdate()	NO	0	
RowPointer	dbo	ue_SMK_RSC_POS_Inbound_mst	RowPointerType	uniqueidentifier			newid()	NO	0	
SiteRef	dbo	ue_SMK_RSC_POS_Inbound_mst	SiteType	nvarchar	8		rtrim(CONVERT([nvarchar](8),context_info(),(0)))	NO	0	
UpdatedBy	dbo	ue_SMK_RSC_POS_Inbound_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
```

## Status

| Value | Meaning |
|---|---|
| `R` | Request diterima |
| `P` | Payload berhasil diparsing |
| `V` | Payload tervalidasi dan telah ditautkan ke batch |
| `E` | Parsing atau validasi gagal |
| `C` | Dibatalkan |

## Payload Format

| Value | Meaning |
|---|---|
| `J` | JSON |
| `X` | XML |
| `C` | CSV |
| `T` | Plain text atau format lain |

## Storage Mode

| Value | Meaning |
|---|---|
| `D` | Payload disimpan pada `payload_text` di database |
| `E` | Payload disimpan pada storage yang disetujui dan `payload_location` menyimpan referensinya |
| `N` | Raw payload tidak disimpan; hanya metadata dan hash yang dipertahankan |

Aturan:

```text
storage_mode = D → payload_text wajib tersedia
storage_mode = E → payload_location wajib tersedia
storage_mode = N → payload_text dan payload_location boleh kosong
```

`nvarchar(max)` harus diverifikasi pada SQL Tables/UDD tenant. Bila tidak didukung atau ukuran payload terlalu besar, gunakan storage eksternal yang disetujui atau desain payload-chunk terpisah. Jangan langsung menambah tabel chunk sebelum ukuran payload resmi diketahui.

## Processing Flow

```text
Request diterima
      ↓
Buat inbound record (R)
      ↓
Hitung payload_sha256 dan periksa idempotency
      ↓
Parse payload
      ↓
Gagal ──> stat E, batch_num tetap NULL
      ↓ berhasil
Buat batch + transaction/line/payment staging
      ↓
Isi batch_num, counts, parsed_date
      ↓
stat P/V
```

## Idempotency and Duplicate Control

Prioritas pemeriksaan duplicate:

1. `source_system + idempotency_key`, bila idempotency key diberikan;
2. `source_system + request_id`, sesuai kontrak source;
3. `payload_sha256` sebagai pendukung deteksi exact-payload duplicate.

`payload_sha256` tidak menggantikan authentication dan tidak cukup untuk membuktikan source request. Unique constraint fisik baru ditetapkan setelah kontrak request ID/idempotency resmi diterima.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_Inbound_01
SiteRef, source_system, request_id

IX_ue_SMK_RSC_POS_Inbound_02
SiteRef, source_system, idempotency_key

IX_ue_SMK_RSC_POS_Inbound_03
SiteRef, payload_sha256

IX_ue_SMK_RSC_POS_Inbound_04
SiteRef, stat, received_date

IX_ue_SMK_RSC_POS_Inbound_05
SiteRef, batch_num
```

## Validation Rules

- `request_id` dan `source_system` wajib.
- `content_length` tidak boleh negatif dan harus berada dalam batas interface.
- `payload_format` harus sesuai `content_type`.
- Hanya satu storage source yang dipakai sesuai `storage_mode`.
- `row_count = accepted_count + rejected_count` bila partial acceptance didukung.
- `batch_num` hanya diisi setelah batch berhasil dibuat.
- Inbound error tidak boleh dihapus karena diperlukan untuk troubleshooting dan retry.
- Retry menaikkan `retry_count` dan harus tetap menggunakan idempotency policy.
- Record yang telah dipurge tidak boleh mengklaim raw payload masih tersedia.
- Raw payload tidak boleh ditimpa oleh hasil parsing atau mapping.

## Security and Retention Rules

- Jangan menyimpan Authorization header, password, API secret, bearer token, cookie, PIN, CVV, atau full card number.
- Masking/redaction dilakukan sebelum raw payload disimpan bila source mengandung data sensitif yang tidak diperlukan.
- `user_agent`, `client_ip`, dan request metadata hanya disimpan jika diizinkan kebijakan perusahaan.
- Full payload tidak disalin ke `ProcessLog`; log hanya menyimpan referensi dan pesan yang sudah disanitasi.
- `retention_date`, `purged_flag`, dan `purged_date` mengikuti kebijakan retensi yang disetujui.
- Purge menghapus atau mengosongkan raw payload secara terkendali tanpa menghapus metadata audit yang masih diperlukan.

## Example

```text
inbound_id       : 258845B2-7E71-4AB6-A895-480AE9CA5A72
request_id       : REQ-POS-20260723-000001
idempotency_key  : PH-SBY-001-20260723-001
source_system    : PIZZAHUT_POS
outlet_code      : PH-SBY-001
payload_version  : 1.0
payload_format   : J
storage_mode     : D
content_length   : 245780
payload_sha256   : <64-character SHA-256 hex>
received_date    : 2026-07-23 08:00:00
stat             : V
batch_num        : SMKPOS-20260723-000001
row_count        : 1000
accepted_count   : 995
rejected_count   : 5
response_code    : 202
```

## Open Decisions

- Apakah raw payload wajib disimpan atau hanya hash dan metadata?
- Berapa ukuran maksimum request?
- Berapa lama raw payload dipertahankan?
- Apakah partial acceptance diperbolehkan?
- Apakah payload disimpan dalam database atau storage lain yang disetujui?
- Apakah `request_id` atau `idempotency_key` dijamin unik oleh source?
- Apakah client IP dan user agent boleh disimpan?
- Domain/UDD apa yang tersedia untuk long text pada tenant Cloud?
