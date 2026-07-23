# SMK_RSC_POS_Batch_mst

## Identity

```text
Metadata object : SMK_RSC_POS_Batch_mst
Physical table  : dbo.ue_SMK_RSC_POS_Batch_mst
Purpose         : Header satu batch/periode data POS
```

Satu record mewakili satu kali penerimaan atau kelompok transaksi POS. Periode dapat satu hari, satu minggu, atau rentang bebas.

## Primary Key

Rancangan saat ini:

```text
batch_num
```

Catatan: kebutuhan memasukkan `SiteRef` ke key harus diverifikasi terhadap standar tenant Cloud sebelum produksi.

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `batch_num` | `nvarchar(30)` | No |  | Nomor batch internal SyteLine |
| `ext_batch_num` | `nvarchar(50)` | Yes |  | Nomor batch dari POS |
| `request_id` | `nvarchar(50)` | Yes |  | ID request untuk tracing |
| `source_system` | `nvarchar(30)` | No | `N'POS'` | Sistem sumber |
| `input_type` | `nchar(1)` | No | `N'A'` | A=API, M=Manual, F=File |
| `outlet_code` | `nvarchar(20)` | No |  | Kode outlet POS |
| `period_start` | `DateType` | No | `getdate()` | Awal periode batch |
| `period_end` | `DateType` | No | `getdate()` | Akhir periode batch |
| `received_date` | `CurrentDateType` | No | `getdate()` | Tanggal diterima |
| `trans_count` | `int` | No | `0` | Jumlah transaksi |
| `gross_amt` | `AmountType` | No | `0` | Nilai kotor |
| `discount_amt` | `AmountType` | No | `0` | Diskon |
| `tax_amt` | `AmountType` | No | `0` | Pajak |
| `service_amt` | `AmountType` | No | `0` | Service charge |
| `rounding_amt` | `AmountType` | No | `0` | Pembulatan |
| `net_amt` | `AmountType` | No | `0` | Nilai bersih |
| `payment_amt` | `AmountType` | No | `0` | Total pembayaran |
| `stat` | `nchar(1)` | No | `N'N'` | Status proses |
| `validation_msg` | `nvarchar(1000)` | Yes |  | Ringkasan validasi |
| `error_msg` | `nvarchar(4000)` | Yes |  | Error terakhir |
| `validate_date` | `DateType` | Yes |  | Waktu validasi |
| `process_date` | `DateType` | Yes |  | Waktu proses/posting |
| `processed_by` | `UsernameType` | Yes |  | User/proses yang memproses |
| `syteline_ref` | `nvarchar(50)` | Yes |  | Referensi hasil SyteLine sementara |
| `retry_count` | `int` | No | `0` | Jumlah retry |

Kolom standar Mongoose mengikuti [`docs/03-database-design.md`](../../docs/03-database-design.md).

## Status

```text
N New
R Received
V Validated / Ready
I In Process
P Processed
E Error
C Cancelled
```

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_Batch_01
SiteRef, outlet_code, period_start, period_end

IX_ue_SMK_RSC_POS_Batch_02
SiteRef, stat, received_date
```

## Validation Rules

- `period_end >= period_start`.
- `batch_num` wajib unik.
- Outlet harus memiliki mapping aktif.
- `trans_count` dibandingkan dengan jumlah transaction records.
- Header totals dibandingkan dengan penjumlahan transaksi.
- `payment_amt` dibandingkan dengan total payment.
- Batch yang sudah `P` tidak boleh diposting ulang.

## Example

```text
batch_num     : SMKPOS-20260723-000001
ext_batch_num : PH-SBY-001-20260723-001
source_system : PIZZAHUT_POS
outlet_code   : PH-SBY-001
period_start  : 2026-07-23
period_end    : 2026-07-23
stat          : R
```
