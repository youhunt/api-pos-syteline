# 10 — Minimum Data Profile and Change Strategy

## Status

Dokumen ini menetapkan bahwa desain database saat ini masih **draft/PoC** karena format raw data POS belum diterima dan belum disetujui.

Tabel yang telah dirancang bukan berarti semuanya wajib dibuat atau digunakan sejak tahap pertama. Tabel-tabel tersebut merupakan kandidat arsitektur lengkap apabila raw data dan kebutuhan Finance memang membutuhkan transaksi header, item detail, pembayaran, pajak, settlement, serta posting keuangan terperinci.

## Prinsip Perubahan Requirement

Perubahan requirement diperbolehkan dan normal selama tahap discovery/PoC.

Strategi perubahan:

1. pertahankan data sumber apa adanya;
2. tambahkan kolom baru sebagai nullable bila memungkinkan;
3. hindari rename/drop kolom setelah API digunakan pihak lain;
4. pisahkan source value dan mapped value;
5. gunakan payload/API version;
6. dokumentasikan setiap perubahan pada changelog dan development history;
7. jangan mengaktifkan posting produksi sebelum format data dan aturan Finance disetujui.

## Klasifikasi Tabel

### Minimum/Core Candidate

Untuk PoC dengan format source yang belum pasti, kebutuhan minimum dapat dibuat hanya dari:

1. `SMK_RSC_POS_Batch_mst` — metadata satu pengiriman/import;
2. `SMK_RSC_POS_RawLine_mst` — baris data mentah/flat dari POS;
3. `SMK_RSC_POS_ProcessLog_mst` — audit/error; dapat ditunda bila PoC sangat sederhana.

### Conditional Tables

Tabel berikut hanya digunakan jika raw data atau flow bisnis membutuhkannya:

- `SMK_RSC_POS_Tran_mst` — bila ada header transaksi;
- `SMK_RSC_POS_TranLine_mst` — bila transaksi memiliki banyak item dan perlu normalisasi;
- `SMK_RSC_POS_Payment_mst` — bila payment method/split payment tersedia;
- `SMK_RSC_POS_OutletMap_mst` — bila source outlet harus diterjemahkan;
- `SMK_RSC_POS_ItemMap_mst` — bila source item berbeda dengan item SyteLine;
- `SMK_RSC_POS_PaymentMap_mst` — bila payment harus diarahkan ke account/AR;
- `SMK_RSC_POS_TaxMap_mst` — bila tax code/value tersedia;
- `SMK_RSC_POS_RevenueMap_mst` — bila revenue account ditentukan berdasarkan category/item/channel;
- posting preview — dibuat setelah bentuk jurnal disetujui Finance.

## Contoh Raw Minimal

Misalnya source hanya mengirim:

```text
tanggal
trans_num
item
qty
total
```

Contoh:

```text
2026-07-23 | TRX0001 | PIZZA001 | 2 | 200000
2026-07-23 | TRX0001 | DRINK001 | 1 |  25000
2026-07-23 | TRX0002 | PIZZA002 | 1 | 125000
```

Data ini adalah struktur flat per item/line. Dalam kondisi tersebut, transaction header, payment, dan tax table belum wajib diisi.

## Minimum Landing Table Candidate

Nama metadata:

```text
SMK_RSC_POS_RawLine_mst
```

Physical Cloud table:

```text
dbo.ue_SMK_RSC_POS_RawLine_mst
```

Kolom minimum:

```text
batch_num
source_row_num
business_date
trans_num
source_item
qty
total_amt
stat
validation_msg
error_msg
```

Kolom hasil mapping yang dapat ditambahkan tanpa mengubah source:

```text
item
syteline_qty
revenue_acct
unit_code1
unit_code2
unit_code3
unit_code4
```

Primary key candidate:

```text
batch_num + source_row_num
```

`source_row_num` lebih aman daripada langsung memakai `trans_num + item`, karena item yang sama dapat muncul lebih dari sekali pada satu transaksi.

## Pengolahan Raw Minimal

```text
API/Form Import
   ↓
Batch + RawLine
   ↓
Group by business_date + trans_num
   ↓
Map source_item ke item/revenue account
   ↓
Validate qty dan total
   ↓
Generate posting preview
```

Transaction header dapat dihitung saat proses:

```sql
GROUP BY business_date, trans_num
```

Total transaksi:

```sql
SUM(total_amt)
```

Tidak wajib menyimpan hasil grouping ke `Tran_mst` kecuali form, audit, volume, atau proses lanjutan membutuhkannya.

## Kemampuan dari Data Minimal

Dengan `tanggal + trans_num + item + qty + total`, sistem dapat:

- menghitung total penjualan per tanggal;
- menghitung total per transaksi;
- menghitung quantity dan total per item;
- mapping item ke item/category/revenue account;
- membuat laporan penjualan dasar;
- membuat posting preview pendapatan.

## Keterbatasan Data Minimal

Data minimal belum cukup untuk menentukan secara akurat:

- cash, bank, QRIS, card, voucher, atau aggregator;
- split payment;
- pajak dan tax payable;
- discount dan service charge terpisah;
- settlement dan MDR/commission;
- void/refund bila tidak ada transaction type;
- outlet/site bila tidak tersedia pada request/header;
- journal debit account final.

Karena itu posting final memerlukan salah satu pendekatan berikut:

1. debit ke account default `POS Clearing/Suspense` dari konfigurasi;
2. outlet/site/payment dikirim pada header request meskipun tidak ada pada setiap row;
3. payment/settlement diterima melalui feed terpisah;
4. hanya membuat posting preview sampai data tambahan tersedia.

## Minimum Envelope API

Walaupun setiap row hanya berisi lima field, request sebaiknya tetap memiliki metadata batch:

```json
{
  "sourceSystem": "PIZZAHUT_POS",
  "externalBatchNum": "PH-20260723-001",
  "outletCode": "PH-SBY-001",
  "periodStart": "2026-07-23",
  "periodEnd": "2026-07-23",
  "payloadVersion": "1.0",
  "rows": [
    {
      "businessDate": "2026-07-23",
      "transactionNumber": "TRX0001",
      "itemCode": "PIZZA001",
      "quantity": 2,
      "totalAmount": 200000
    }
  ]
}
```

`outletCode` dapat dibuat optional pada PoC, tetapi site/account tujuan harus diperoleh dari konfigurasi sebelum posting final.

## Keputusan Tahap Saat Ini

- Hentikan sementara penambahan tabel desain baru setelah TaxMap.
- Jangan membuat RevenueMap sebelum contoh raw dan aturan Finance tersedia.
- Verifikasi tabel mana yang benar-benar sudah dibuat pada tenant Cloud.
- Siapkan minimum landing-table design sebagai fallback.
- Setelah raw sample diterima, lakukan gap analysis antara field source dan tabel kandidat.

## Gap Analysis Template

| Source Field | Required? | Destination | Transformation | Validation | Missing Impact |
|---|---:|---|---|---|---|
| tanggal | Yes | business_date | parse date | valid date | tidak dapat menentukan periode |
| trans_num | Yes | trans_num | trim | non-empty/duplicate rule | tidak dapat grouping transaksi |
| item | Yes | source_item | trim | mapping | pendapatan/item tidak terklasifikasi |
| qty | Yes | qty | decimal | rule sesuai source | laporan quantity salah |
| total | Yes | total_amt | decimal | reconciliation | nilai penjualan tidak tersedia |

Dokumen ini harus diperbarui setelah sample payload/file resmi diterima.