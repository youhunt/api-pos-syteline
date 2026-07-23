# SMK_RSC_POS_Payment_mst

## Identity

```text
Metadata object : SMK_RSC_POS_Payment_mst
Physical table  : dbo.ue_SMK_RSC_POS_Payment_mst
Purpose         : Metode dan nilai pembayaran per transaksi
```

## Primary Key

```text
batch_num + trans_num + payment_seq
```

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `batch_num` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 1 |
| `trans_num` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 50 |  |  | NO | 1 | 2 |
| `payment_seq` | dbo | ue_SMK_RSC_POS_Payment_mst | int | int |  |  |  | NO | 1 | 3 |
| `payment_code` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 30 |  |  | NO | 0 |  |
| `payment_desc` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `payment_type` | dbo | ue_SMK_RSC_POS_Payment_mst | nchar | nchar | 1 |  | `N'O'` | NO | 0 |  |
| `currency_code` | dbo | ue_SMK_RSC_POS_Payment_mst | CurrCodeType | nvarchar | 3 |  | `N'IDR'` | NO | 0 |  |
| `payment_amt` | dbo | ue_SMK_RSC_POS_Payment_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `fee_amt` | dbo | ue_SMK_RSC_POS_Payment_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `net_settlement_amt` | dbo | ue_SMK_RSC_POS_Payment_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `reference_num` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `bank_code` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `card_type` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `masked_card_num` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 25 |  |  | YES | 0 |  |
| `approval_code` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `terminal_id` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `merchant_id` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `settlement_date` | dbo | ue_SMK_RSC_POS_Payment_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `acct` | dbo | ue_SMK_RSC_POS_Payment_mst | AcctType | nvarchar | 12 |  |  | YES | 0 |  |
| `unit_code1` | dbo | ue_SMK_RSC_POS_Payment_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code2` | dbo | ue_SMK_RSC_POS_Payment_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code3` | dbo | ue_SMK_RSC_POS_Payment_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code4` | dbo | ue_SMK_RSC_POS_Payment_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `stat` | dbo | ue_SMK_RSC_POS_Payment_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_Payment_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `process_date` | dbo | ue_SMK_RSC_POS_Payment_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_Payment_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_Payment_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_Payment_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_Payment_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_Payment_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_Payment_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_Payment_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_Payment_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Security Rule

Jangan menyimpan nomor kartu lengkap, CVV, PIN, atau track data. Hanya masked card number bila memang diperlukan dan diizinkan policy.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_Payment_01
SiteRef, batch_num, trans_num

IX_ue_SMK_RSC_POS_Payment_02
SiteRef, payment_code, stat

IX_ue_SMK_RSC_POS_Payment_03
SiteRef, settlement_date, payment_code
```

## Validation Rules

- Parent transaction harus ada.
- `payment_seq > 0`.
- `payment_code` wajib dan harus memiliki mapping aktif.
- `SUM(payment_amt)` dibandingkan dengan transaction payment amount.
- `payment_amt` dibandingkan dengan transaction net amount sesuai rule split payment/tolerance.
- `net_settlement_amt` dibandingkan dengan `payment_amt - fee_amt` bila model settlement seperti itu.
- Account dan unit code tidak dipercaya dari source; diisi dari mapping internal.

## Example Split Payment

```text
TRX001 / seq 1 / CASH      / 100000
TRX001 / seq 2 / QRIS_BCA  / 125000
TRX001 / seq 3 / VOUCHER   /  25000
```
