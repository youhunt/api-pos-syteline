# 11 — IDO Design Overview

## Status

Dokumen ini merupakan **candidate design / PoC** untuk IDO Infor SyteLine/Mongoose. Nama IDO, property, method, security class, dan konfigurasi akhirnya tetap harus diverifikasi pada tenant Cloud yang digunakan.

## Tujuan

IDO menjadi lapisan resmi antara custom table, custom form, stored procedure/server-side logic, dan REST API.

```text
Custom Form / REST Client / Postman
                 |
                 v
       Service IDO + Custom Methods
                 |
        Validate / Parse / Process
                 |
                 v
        Entity IDO / Monitor IDO
                 |
                 v
       Custom Tables / SyteLine Modules
```

## Prinsip Pemisahan IDO

### 1. Entity IDO

Satu entity IDO mewakili satu custom table dan digunakan untuk:

- query data;
- binding custom form;
- filtering dan sorting;
- controlled insert/update bila diizinkan;
- relasi primary collection dan subcollection.

Entity IDO tidak otomatis boleh digunakan sebagai endpoint write publik.

### 2. Service IDO

Service IDO tidak berfungsi sebagai CRUD table langsung. Service IDO menyediakan custom method untuk proses bisnis, misalnya:

```text
ReceiveInbound
ReceiveCompleteBatch
ReceiveMinimalBatch
ValidateBatch
RetryBatch
GeneratePostingPreview
ApprovePostingPreview
PostBatch
CancelBatch
PurgeInboundPayload
```

Seluruh operasi yang memerlukan transaksi lintas tabel, idempotency, validation, logging, dan rollback harus diarahkan melalui service IDO.

Candidate service IDO:

```text
SMKRSCPosIntegration
```

### 3. Monitor/Composite IDO

Monitor IDO bersifat read-only dan dapat menggabungkan beberapa table atau derived property untuk dashboard/form monitoring.

Candidate monitor IDO:

```text
SMKRSCPosInboundMonitor
SMKRSCPosBatchMonitor
SMKRSCPosPostingMonitor
SMKRSCPosErrorMonitor
```

Monitor IDO tidak digunakan untuk posting atau perubahan source data.

## Candidate Entity IDO Catalog

| No. | IDO Name | Base Object | Purpose |
|---:|---|---|---|
| 1 | `SMKRSCPosInbounds` | `SMK_RSC_POS_Inbound_mst` | Request, idempotency, raw-payload metadata, parsing result |
| 2 | `SMKRSCPosBatches` | `SMK_RSC_POS_Batch_mst` | Batch header dan status proses |
| 3 | `SMKRSCPosTrans` | `SMK_RSC_POS_Tran_mst` | Transaction header |
| 4 | `SMKRSCPosTranLines` | `SMK_RSC_POS_TranLine_mst` | Transaction detail lines |
| 5 | `SMKRSCPosPayments` | `SMK_RSC_POS_Payment_mst` | Payment lines |
| 6 | `SMKRSCPosProcessLogs` | `SMK_RSC_POS_ProcessLog_mst` | Audit trail, warning, error, retry |
| 7 | `SMKRSCPosOutletMaps` | `SMK_RSC_POS_OutletMap_mst` | Mapping outlet/site/warehouse/dimension |
| 8 | `SMKRSCPosItemMaps` | `SMK_RSC_POS_ItemMap_mst` | Mapping POS item/U-M ke SyteLine item |
| 9 | `SMKRSCPosPaymentMaps` | `SMK_RSC_POS_PaymentMap_mst` | Mapping payment ke account/settlement |
| 10 | `SMKRSCPosTaxMaps` | `SMK_RSC_POS_TaxMap_mst` | Mapping pajak |
| 11 | `SMKRSCPosRevenueMaps` | `SMK_RSC_POS_RevenueMap_mst` | Rule revenue/discount/service account |
| 12 | `SMKRSCPosPostingPreviews` | `SMK_RSC_POS_PostingPreview_mst` | Preview debit-credit dan approval |
| 13 | `SMKRSCPosRawLines` | `SMK_RSC_POS_RawLine_mst` | Alternative minimal/flat source staging |

Nama di atas menggunakan bentuk plural untuk collection IDO. Penamaan final dapat menyesuaikan standard naming pada tenant.

## Proposed IDO Project

```text
Project Name : SMK_RSC_POS
Prefix       : SMKRSCPos
```

Tujuan project terpisah:

- memudahkan deployment dan export/import metadata;
- memisahkan custom object dari standard SyteLine;
- memudahkan source control dan audit perubahan;
- mengurangi risiko perubahan tidak sengaja pada standard object.

## General Property Rules

### Source Properties

Source data yang diterima dari POS harus diperlakukan immutable setelah request diterima, kecuali melalui controlled correction process yang terdokumentasi.

Contoh source properties:

```text
RequestId
SourceSystem
SourceReference
BusinessDate
TransNum
PosItemCode
PosQty
TotalAmt
PaymentCode
```

### Derived/Mapping Properties

Hasil mapping dan processing boleh berubah saat retry atau rebuild, tetapi tidak boleh menimpa source property.

Contoh:

```text
Item
SyteLineQty
UM
Acct
UnitCode1..4
ValidationMsg
PostingStat
SyteLineRef
```

### Framework Properties

Framework properties tetap tersedia sesuai kebutuhan Mongoose:

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

`RowPointer` digunakan sebagai identifier framework, tetapi tidak otomatis menggantikan business primary key yang telah dirancang.

## General Update Policy

| Operation | Default Policy |
|---|---|
| Query | Diizinkan sesuai authorization |
| Insert langsung ke entity IDO | Dibatasi; proses API memakai service method |
| Update source field | Tidak diizinkan setelah receive |
| Update status/result field | Hanya server-side method/process |
| Delete | Tidak diizinkan untuk staging/audit data |
| Purge raw payload | Melalui controlled method dan retention policy |
| Retry | Membuat process log baru dan mempertahankan history |
| Rebuild preview | Membuat generation baru, tidak menimpa approved/posted preview |

## Site Isolation

Seluruh IDO harus menerapkan filter dan authorization berdasarkan `SiteRef`/target site sesuai arsitektur tenant.

Catatan:

```text
SiteRef     = site owner record pada framework
TargetSite  = site tujuan mapping/posting
```

Keduanya tidak boleh dianggap selalu sama tanpa validasi.

## Security Classes — Candidate

| Security Class | Purpose |
|---|---|
| `SMK_RSC_POS_VIEW` | Melihat batch, transaction, raw line, dan status |
| `SMK_RSC_POS_PROCESS` | Validate, retry, dan generate preview |
| `SMK_RSC_POS_APPROVE` | Approve/reject posting preview |
| `SMK_RSC_POS_POST` | Menjalankan posting aktual |
| `SMK_RSC_POS_MAPPING` | Memelihara mapping master |
| `SMK_RSC_POS_PAYLOAD_VIEW` | Melihat raw payload yang telah dimasking |
| `SMK_RSC_POS_ADMIN` | Administrasi penuh dan controlled purge |

Nama dan implementasi authorization harus disesuaikan dengan konfigurasi tenant.

## REST Exposure Policy

Entity IDO dapat diekspos untuk query sesuai authorization, tetapi direct insert/update untuk proses integrasi tidak disarankan.

```text
Recommended:
REST → SMKRSCPosIntegration.ReceiveCompleteBatch()
REST → SMKRSCPosIntegration.ReceiveMinimalBatch()

Not recommended:
REST → direct insert ke SMKRSCPosBatches
REST → direct insert ke SMKRSCPosTranLines
REST → direct update PostingStat
```

Alasan:

- transaksi harus atomic;
- idempotency harus diperiksa sebelum insert;
- relasi parent-child harus divalidasi;
- error harus tercatat pada process log;
- source data dan result data harus dipisahkan;
- posting ganda harus dicegah.

## Method Transaction Boundary

Satu receive method idealnya melakukan:

```text
1. Create inbound record
2. Validate request identity/idempotency
3. Validate payload version and structure
4. Create batch
5. Insert complete-profile or minimal-profile records
6. Reconcile counts and totals
7. Write process log
8. Commit
```

Jika langkah kritis gagal, transaksi harus di-rollback sesuai kemampuan server-side implementation. Inbound error metadata tetap perlu dipertahankan melalui pola error-handling yang disepakati.

## Planned IDO Design Sequence

1. `SMKRSCPosInbounds`
2. `SMKRSCPosBatches`
3. `SMKRSCPosTrans`
4. `SMKRSCPosTranLines`
5. `SMKRSCPosPayments`
6. `SMKRSCPosRawLines`
7. `SMKRSCPosProcessLogs`
8. mapping IDOs
9. `SMKRSCPosPostingPreviews`
10. monitor/composite IDOs
11. `SMKRSCPosIntegration` service methods

Urutan dapat berubah setelah raw data resmi dan target posting module dipastikan.
