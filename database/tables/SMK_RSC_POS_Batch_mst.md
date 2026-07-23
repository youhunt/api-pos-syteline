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

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `batch_num` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 1 |
| `ext_batch_num` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `request_id` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `source_system` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 0 |  |
| `input_type` | dbo | ue_SMK_RSC_POS_Batch_mst | nchar | nchar | 1 |  | `N'A'` | NO | 0 |  |
| `outlet_code` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 20 |  |  | NO | 0 |  |
| `period_start` | dbo | ue_SMK_RSC_POS_Batch_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `period_end` | dbo | ue_SMK_RSC_POS_Batch_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `received_date` | dbo | ue_SMK_RSC_POS_Batch_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `trans_count` | dbo | ue_SMK_RSC_POS_Batch_mst | int | int |  |  | `0` | NO | 0 |  |
| `gross_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `discount_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `tax_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `service_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `rounding_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `net_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `payment_amt` | dbo | ue_SMK_RSC_POS_Batch_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `stat` | dbo | ue_SMK_RSC_POS_Batch_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `validate_date` | dbo | ue_SMK_RSC_POS_Batch_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `process_date` | dbo | ue_SMK_RSC_POS_Batch_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `processed_by` | dbo | ue_SMK_RSC_POS_Batch_mst | UsernameType | nvarchar | 128 |  |  | YES | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_Batch_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `retry_count` | dbo | ue_SMK_RSC_POS_Batch_mst | int | int |  |  | `0` | NO | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_Batch_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_Batch_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_Batch_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_Batch_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_Batch_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_Batch_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_Batch_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_Batch_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

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
