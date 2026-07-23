# API POS SyteLine

Repository dokumentasi dan artefak pengembangan integrasi **POS Pizza Hut / RSC → Infor SyteLine (Mongoose)**.

> Status saat ini: **Proof of Concept / tahap perancangan data staging**. Struktur akhir API, jalur posting keuangan, dan format payload resmi masih menunggu flow serta contoh data dari tim POS, Finance, dan SyteLine.

## Tujuan

Menyediakan API di dalam SyteLine yang dapat menerima data transaksi POS untuk periode bebas—harian, mingguan, atau rentang tanggal lain—kemudian:

1. menyimpan data pada custom staging table SyteLine;
2. memvalidasi batch, transaksi, item, quantity, nilai, dan pembayaran;
3. melakukan mapping data POS ke master/struktur SyteLine;
4. menyiapkan preview hasil pengolahan;
5. memproses data melalui stored procedure atau server-side IDO logic;
6. menghasilkan transaksi yang dapat berujung pada laporan keuangan SyteLine;
7. menyediakan audit trail, error handling, dan retry.

## Prinsip Arsitektur

```text
POS / Postman / Custom Form SyteLine
                 |
                 v
       Custom REST API / IDO Method
                 |
                 v
       Custom Staging Tables SyteLine
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

Dokumentasi detail tersedia di folder [`database/tables`](database/tables/).

## Relasi Utama

```text
Batch
  ├── Transactions
  │     ├── Transaction Lines
  │     └── Payments
  └── Process Logs

Outlet Map  ──> menentukan target site, warehouse, customer, currency,
                dan unit code

Item Map    ──> menerjemahkan kode item dan U/M POS ke SyteLine

Payment Map ──> menerjemahkan payment code ke account, fee account,
                customer, bank, dimensi, dan aturan settlement

Tax Map     ──> menerjemahkan kode pajak POS ke tax code/account,
                rate, inclusion rule, rounding, dan tolerance
```

## Status Proses

Status awal yang dirancang:

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
│   └── 09-open-questions.md
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
        └── SMK_RSC_POS_TaxMap_mst.md
```

## Tahap Berikutnya

Setelah tabel yang sudah dirancang selesai dibuat dan diverifikasi di Cloud:

1. desain `RevenueMap`;
2. desain posting preview;
3. buat IDO untuk tabel staging dan mapping;
4. buat custom form monitoring;
5. buat stored procedure validasi;
6. buat custom IDO Method penerimaan batch;
7. expose sebagai REST API;
8. uji melalui Postman;
9. tentukan jalur posting aktual ke modul SyteLine.

## Catatan Penting

- Staging menggunakan tabel permanen, bukan SQL temporary table berbasis session.
- Data sumber tidak boleh ditimpa; hasil mapping disimpan pada kolom terpisah.
- API tidak boleh langsung mengklaim data sudah masuk laporan keuangan. Respons awal hanya menyatakan batch diterima.
- Duplikasi, retry, audit trail, dan rekonsiliasi merupakan kebutuhan inti.
- Nomor kartu penuh, PIN, CVV, dan track data tidak boleh disimpan.
- Tax treatment, tax rate, rounding, dan account mapping harus disetujui Finance sebelum posting produksi.

## Pemilik Repository

Repository: `youhunt/api-pos-syteline`

Dokumentasi akan diperbarui bertahap mengikuti hasil pembahasan, implementasi, pengujian, dan keputusan bisnis.