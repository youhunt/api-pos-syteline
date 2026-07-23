# SMK_RSC_POS_Tran_mst

## Identity

```text
Metadata object : SMK_RSC_POS_Tran_mst
Physical table  : dbo.ue_SMK_RSC_POS_Tran_mst
Purpose         : Header transaksi/struk POS
```

## Primary Key

```text
batch_num + trans_num
```

Satu nomor transaksi dapat muncul pada batch berbeda, tetapi tidak boleh ganda pada batch yang sama.

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `batch_num` | `nvarchar(30)` | No |  | Parent batch |
| `trans_num` | `nvarchar(50)` | No |  | Nomor transaksi POS |
| `receipt_num` | `nvarchar(50)` | Yes |  | Nomor struk |
| `outlet_code` | `nvarchar(20)` | No |  | Outlet transaksi |
| `business_date` | `DateType` | No | `getdate()` | Tanggal operasional |
| `trans_datetime` | `datetime` | Yes |  | Waktu transaksi |
| `trans_type` | `nchar(1)` | No | `N'S'` | S=Sale, V=Void, R=Refund, C=Cancelled |
| `orig_trans_num` | `nvarchar(50)` | Yes |  | Referensi transaksi asal |
| `cashier_code` | `nvarchar(20)` | Yes |  | Kode kasir |
| `order_type` | `nvarchar(20)` | Yes |  | Dine-in/takeaway/delivery |
| `sales_channel` | `nvarchar(30)` | Yes |  | POS/aggregator/channel lain |
| `currency_code` | `nvarchar(3)` | No | `N'IDR'` | Mata uang |
| `item_count` | `int` | No | `0` | Jumlah line/item |
| `gross_amt` | `AmountType` | No | `0` | Nilai kotor |
| `discount_amt` | `AmountType` | No | `0` | Diskon |
| `tax_amt` | `AmountType` | No | `0` | Pajak |
| `service_amt` | `AmountType` | No | `0` | Service charge |
| `rounding_amt` | `AmountType` | No | `0` | Pembulatan |
| `net_amt` | `AmountType` | No | `0` | Nilai bersih |
| `payment_amt` | `AmountType` | No | `0` | Total payment |
| `stat` | `nchar(1)` | No | `N'N'` | Status |
| `validation_msg` | `nvarchar(1000)` | Yes |  | Ringkasan validasi |
| `error_msg` | `nvarchar(4000)` | Yes |  | Error terakhir |
| `syteline_ref` | `nvarchar(50)` | Yes |  | Referensi hasil SyteLine |
| `process_date` | `DateType` | Yes |  | Waktu proses |

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_Tran_01
SiteRef, outlet_code, business_date, trans_num

IX_ue_SMK_RSC_POS_Tran_02
SiteRef, stat, business_date

IX_ue_SMK_RSC_POS_Tran_03
SiteRef, orig_trans_num
```

## Validation Rules

- Parent `batch_num` harus tersedia.
- `business_date` mengikuti aturan periode batch.
- Transaksi tidak boleh duplikat berdasarkan identity yang disepakati.
- Refund/void harus memiliki `orig_trans_num` bila aturan source mewajibkan.
- `item_count` dibandingkan dengan line records.
- Header amount dibandingkan dengan penjumlahan line.
- `payment_amt` dibandingkan dengan penjumlahan payment.
- Transaction yang sudah diposting tidak boleh diposting ulang.

## Example

```text
batch_num      : SMKPOS-20260723-000001
trans_num      : TRX-PH001-00001234
receipt_num    : RCP-001234
business_date  : 2026-07-23
trans_type     : S
sales_channel  : POS
net_amt        : 247500
payment_amt    : 247500
stat           : N
```
