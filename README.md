# API POS SyteLine

> **Current SMK069 handoff as of 3 Sep 2026:** [docs/24-smk069-current-handoff-2026-09-03.md](docs/24-smk069-current-handoff-2026-09-03.md)
>
> Use the 3-Sep handoff as the current continuation source of truth. It records the stable POS inbound baseline, site-aware hardening, Shipment Build/Prepare/Complete status, multi-site rules, UAT findings, unresolved endpoint/mapping items, and the required automatic hourly/adjustable Shipment scheduler.
>
> **Previous recap through 31 Aug 2026:** [docs/23-smk069-development-recap-through-2026-08-31.md](docs/23-smk069-development-recap-through-2026-08-31.md)

Repository dokumentasi dan artefak pengembangan integrasi **POS Pizza Hut / RSC → Infor SyteLine (Mongoose)**.

> Status saat ini: **Proof of Concept / tahap perancangan data staging dan IDO**. Struktur akhir API, jalur posting keuangan, dan format payload resmi masih menunggu flow serta contoh data dari tim POS, Finance, dan SyteLine. Seluruh tabel dan IDO saat ini merupakan candidate design dan masih dapat disederhanakan atau disesuaikan ketika raw data resmi diterima.

## Tujuan

Menyediakan API di dalam SyteLine yang dapat menerima data transaksi POS untuk periode bebas—harian, mingguan, atau rentang tanggal lain—kemudian:

1. menyimpan identitas request dan raw payload sesuai kebijakan keamanan/retensi;
2. menyimpan data pada custom staging table SyteLine;
3. memvalidasi batch, transaksi, item, quantity, nilai, dan pembayaran;
4. melakukan mapping data POS ke master/struktur SyteLine;
5. menyiapkan preview hasil pengolahan;
6. memproses data melalui stored procedure atau server-side IDO logic;
7. menghasilkan transaksi yang dapat berujung pada laporan keuangan SyteLine;
8. menyediakan audit trail, duplicate control, error handling, dan retry.

## Prinsip Arsitektur

```text
POS / Postman / Custom Form SyteLine
                 |
                 v
       Custom REST API / Service IDO
                 |
                 v
       Inbound Request + Raw Payload
                 |
                 v
       Entity IDO + Custom Staging Tables
                 |
        Validate + Map + Summarize
                 |
                 v
        Posting Preview / Processing
                 |
                 v
      GL / AR / Inventory / Financial Report
```

Seluruh integrasi dirancang berada **di dalam ekosistem SyteLine/Mongoose**, bukan aplikasi web terpisah.

## Konvensi SyteLine Cloud

Nama object yang dibuat pada metadata SyteLine menggunakan prefix `SMK_`, misalnya:

```text
SMK_RSC_POS_Batch_mst
```

Pada environment Cloud, tabel fisik otomatis memperoleh prefix `ue_`:

```text
dbo.ue_SMK_RSC_POS_Batch_mst
```

Aturan penggunaan:

- pada form/metadata pembuatan object: gunakan `SMK_...`;
- pada query SQL dan stored procedure: gunakan nama fisik `dbo.ue_SMK_...`;
- jangan menambahkan `ue_` secara manual pada metadata jika environment menambahkannya otomatis.

## Tabel yang Sudah Dirancang

| No. | Object SyteLine | Physical Table Cloud | Fungsi |
|---:|---|---|---|
| 1 | `SMK_RSC_POS_Batch_mst` | `dbo.ue_SMK_RSC_POS_Batch_mst` | Header satu batch/periode data POS |
| 2 | `SMK_RSC_POS_Tran_mst` | `dbo.ue_SMK_RSC_POS_Tran_mst` | Header transaksi/struk |
| 3 | `SMK_RSC_POS_TranLine_mst` | `dbo.ue_SMK_RSC_POS_TranLine_mst` | Detail item dan quantity |
| 4 | `SMK_RSC_POS_Payment_mst` | `dbo.ue_SMK_RSC_POS_Payment_mst` | Metode dan nilai pembayaran |
| 5 | `SMK_RSC_POS_ProcessLog_mst` | `dbo.ue_SMK_RSC_POS_ProcessLog_mst` | Audit trail proses, error, dan retry |
| 6 | `SMK_RSC_POS_OutletMap_mst` | `dbo.ue_SMK_RSC_POS_OutletMap_mst` | Mapping outlet ke site/warehouse/dimensi SyteLine |
| 7 | `SMK_RSC_POS_ItemMap_mst` | `dbo.ue_SMK_RSC_POS_ItemMap_mst` | Mapping item POS ke item dan U/M SyteLine |
| 8 | `SMK_RSC_POS_PaymentMap_mst` | `dbo.ue_SMK_RSC_POS_PaymentMap_mst` | Mapping payment code ke account, dimension, customer, dan settlement |
| 9 | `SMK_RSC_POS_TaxMap_mst` | `dbo.ue_SMK_RSC_POS_TaxMap_mst` | Mapping kode pajak POS ke tax code, account, dimensi, dan aturan perhitungan |
| 10 | `SMK_RSC_POS_RevenueMap_mst` | `dbo.ue_SMK_RSC_POS_RevenueMap_mst` | Rule mapping item/kategori/channel/outlet ke akun revenue, discount, service, dan dimensi |
| 11 | `SMK_RSC_POS_PostingPreview_mst` | `dbo.ue_SMK_RSC_POS_PostingPreview_mst` | Simulasi line debit-credit, approval, balance check, dan referensi sebelum posting aktual |
| 12 | `SMK_RSC_POS_Inbound_mst` | `dbo.ue_SMK_RSC_POS_Inbound_mst` | Identitas request, idempotency, payload metadata/raw payload, parsing result, retensi, dan relasi ke batch |
| 13 | `SMK_RSC_POS_RawLine_mst` | `dbo.ue_SMK_RSC_POS_RawLine_mst` | Alternatif staging minimal untuk source flat: tanggal, transaction number, item, quantity, dan total |

Dokumentasi detail tersedia di folder [`database/tables`](database/tables/).

## Relasi Utama

```text
Inbound Request
   └── 0..1 Batch
           ├── Transactions
           │     ├── Transaction Lines
           │     └── Payments
           ├── Raw Lines (alternatif source minimal)
           ├── Process Logs
           └── Posting Preview Lines

Outlet Map  ──> menentukan target site, warehouse, customer, currency,
                dan unit code

Item Map    ──> menerjemahkan kode item dan U/M POS ke SyteLine

Payment Map ──> menerjemahkan payment code ke account, fee account,
                customer, bank, dimensi, dan aturan settlement

Tax Map     ──> menerjemahkan kode pajak POS ke tax code/account,
                rate, inclusion rule, rounding, dan tolerance

Revenue Map ──> memilih account dan unit code berdasarkan item, kategori,
                outlet, channel, order type, line type, dan priority rule

Posting Preview ──> menggabungkan hasil mapping menjadi line debit-credit
                    yang harus balance sebelum approval/posting
```

Inbound dapat tidak memiliki batch ketika payload gagal diparsing atau ditolak sebelum staging dibuat.

`RawLine` adalah jalur alternatif untuk payload flat/minimal. Tabel ini tidak otomatis dipakai bersamaan dengan `Tran` dan `TranLine`; pilihan akhir mengikuti raw data resmi.

## Minimal Raw-Data Profile

Candidate profile berikut telah didokumentasikan untuk kondisi source hanya mengirim:

```text
business_date
trans_num
pos_item_code
pos_qty
total_amt
```

Data tersebut disimpan pada `SMK_RSC_POS_RawLine_mst` dengan primary key:

```text
batch_num + source_row_num
```

Source fields tidak ditimpa. Hasil mapping ditempatkan pada kolom terpisah:

```text
item
syteline_qty
u_m
```

Transaction summary dapat dibentuk dengan grouping `business_date + trans_num`. Karena profile minimal belum memiliki payment, tax, discount, service charge, atau refund indicator, data yang tidak tersedia tidak boleh diisi menggunakan asumsi tersembunyi.

## IDO Architecture

Desain IDO dibagi menjadi tiga lapisan:

```text
Entity IDO   → query/form binding untuk custom table
Monitor IDO  → read-only composite/dashboard
Service IDO  → receive, validate, retry, generate preview, approve, dan post
```

Candidate service IDO:

```text
SMKRSCPosIntegration
```

Direct insert/update dari REST ke staging entity IDO tidak direkomendasikan. Proses integrasi harus menggunakan service method agar idempotency, transaction boundary, validation, logging, dan rollback dapat dikendalikan.

Dokumentasi arsitektur: [`docs/11-ido-design-overview.md`](docs/11-ido-design-overview.md).

### IDO yang Sudah Dirancang

| No. | IDO | Base Object | Status |
|---:|---|---|---|
| 1 | `SMKRSCPosInbounds` | `SMK_RSC_POS_Inbound_mst` | Candidate design tersedia |

`SMKRSCPosInbounds` dirancang sebagai IDO monitoring inbound request. Direct public insert/delete dinonaktifkan; payload access, retry parsing, dan purge dilakukan melalui controlled methods dan authorization.

Dokumentasi: [`ido/01-SMKRSCPosInbounds.md`](ido/01-SMKRSCPosInbounds.md).

## Status Proses

Status staging utama yang dirancang:

| Kode | Arti |
|---|---|
| `N` | New |
| `R` | Received |
| `V` | Validated / Ready |
| `I` | In Process |
| `P` | Processed |
| `E` | Error |
| `C` | Cancelled |

Alur normal:

```text
N → R → V → I → P
```

Inbound menggunakan status receive/parse tersendiri yang didokumentasikan pada tabel dan IDO inbound.

## Jalur Posting Keuangan

Jalur final belum diputuskan. Kandidat yang akan dianalisis bersama tim Finance/SyteLine:

1. langsung membuat jurnal General Ledger;
2. membuat transaksi Accounts Receivable;
3. membuat Customer Order → Shipment → Invoice → AR;
4. kombinasi nilai penjualan ke Finance dan quantity item ke Inventory.

Keputusan harus didasarkan pada flow resmi, kebutuhan rekonsiliasi, volume transaksi, treatment aggregator, pajak, diskon, void/refund, dan settlement pembayaran.

## Struktur Repository

```text
.
├── README.md
├── CHANGELOG.md
├── docs/
│   ├── 01-project-overview.md
│   ├── 02-architecture-and-flow.md
│   ├── 03-database-design.md
│   ├── 04-syteline-cloud-conventions.md
│   ├── 05-api-contract-draft.md
│   ├── 06-financial-posting-options.md
│   ├── 07-development-roadmap.md
│   ├── 08-development-history.md
│   ├── 09-open-questions.md
│   ├── 10-minimum-data-profile-and-change-strategy.md
│   └── 11-ido-design-overview.md
├── ido/
│   └── 01-SMKRSCPosInbounds.md
└── database/
    └── tables/
        ├── TABLE_DOCUMENTATION_TEMPLATE.md
        ├── SMK_RSC_POS_Batch_mst.md
        ├── SMK_RSC_POS_Tran_mst.md
        ├── SMK_RSC_POS_TranLine_mst.md
        ├── SMK_RSC_POS_Payment_mst.md
        ├── SMK_RSC_POS_ProcessLog_mst.md
        ├── SMK_RSC_POS_OutletMap_mst.md
        ├── SMK_RSC_POS_ItemMap_mst.md
        ├── SMK_RSC_POS_PaymentMap_mst.md
        ├── SMK_RSC_POS_TaxMap_mst.md
        ├── SMK_RSC_POS_RevenueMap_mst.md
        ├── SMK_RSC_POS_PostingPreview_mst.md
        ├── SMK_RSC_POS_Inbound_mst.md
        └── SMK_RSC_POS_RawLine_mst.md
```

## Tahap Berikutnya

1. lanjut desain entity IDO `SMKRSCPosBatches`;
2. lanjut IDO transaction, line, payment, raw-line, process-log, mapping, dan posting-preview;
3. tentukan profile source yang dipakai: lengkap atau minimal/flat;
4. tentukan tabel dan IDO yang benar-benar dibutuhkan berdasarkan raw data resmi;
5. verifikasi dukungan long text, batas ukuran request, dan kebijakan raw-payload retention pada tenant;
6. buat custom form monitoring, inbound request, raw-line review, dan posting preview;
7. buat stored procedure validasi, parsing, mapping, grouping, dan generate preview;
8. buat service IDO `SMKRSCPosIntegration` dan custom receive methods;
9. expose controlled methods sebagai REST API;
10. uji melalui Postman termasuk duplicate/idempotency dan minimal-profile test;
11. tentukan jalur posting aktual ke modul SyteLine.

## Catatan Penting

- Staging menggunakan tabel permanen, bukan SQL temporary table berbasis session.
- Data sumber tidak boleh ditimpa; hasil parsing dan mapping disimpan pada kolom/tabel terpisah.
- API tidak boleh langsung mengklaim data sudah masuk laporan keuangan. Respons awal hanya menyatakan request/batch diterima.
- Duplikasi, idempotency, retry, audit trail, dan rekonsiliasi merupakan kebutuhan inti.
- Nomor kartu penuh, PIN, CVV, track data, Authorization header, password, token, dan API secret tidak boleh disimpan.
- Raw payload harus mengikuti masking, access control, ukuran maksimum, dan kebijakan retensi yang disetujui.
- Tax treatment, tax rate, rounding, dan account mapping harus disetujui Finance sebelum posting produksi.
- Revenue, discount, service charge, dan refund rule harus disetujui Finance.
- Posting preview harus balance dan bebas error mapping sebelum approval/posting.
- Direct REST write ke entity IDO tidak digunakan untuk proses integrasi utama.
- Perubahan requirement masih aman pada tahap PoC; dokumentasi dan implementasi harus versioned dan tidak boleh menghapus data sumber tanpa migration plan.

## Pemilik Repository

Repository: `youhunt/api-pos-syteline`

Dokumentasi akan diperbarui bertahap mengikuti hasil pembahasan, implementasi, pengujian, dan keputusan bisnis.
