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

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `batch_num` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 1 |
| `trans_num` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 50 |  |  | NO | 1 | 2 |
| `receipt_num` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `outlet_code` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 20 |  |  | NO | 0 |  |
| `business_date` | dbo | ue_SMK_RSC_POS_Tran_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `trans_datetime` | dbo | ue_SMK_RSC_POS_Tran_mst | datetime | datetime |  |  |  | YES | 0 |  |
| `trans_type` | dbo | ue_SMK_RSC_POS_Tran_mst | nchar | nchar | 1 |  | `N'S'` | NO | 0 |  |
| `orig_trans_num` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `cashier_code` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `order_type` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `sales_channel` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `currency_code` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 3 |  | `N'IDR'` | NO | 0 |  |
| `item_count` | dbo | ue_SMK_RSC_POS_Tran_mst | int | int |  |  | `0` | NO | 0 |  |
| `gross_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `discount_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `tax_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `service_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `rounding_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `net_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `payment_amt` | dbo | ue_SMK_RSC_POS_Tran_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `stat` | dbo | ue_SMK_RSC_POS_Tran_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_Tran_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `process_date` | dbo | ue_SMK_RSC_POS_Tran_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_Tran_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_Tran_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_Tran_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_Tran_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_Tran_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_Tran_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_Tran_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_Tran_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

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
