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

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `batch_num` | `nvarchar(30)` | No |  | Parent batch |
| `trans_num` | `nvarchar(50)` | No |  | Parent transaction |
| `payment_seq` | `int` | No |  | Urutan payment |
| `payment_code` | `nvarchar(30)` | No |  | Kode detail dari POS |
| `payment_desc` | `nvarchar(100)` | Yes |  | Deskripsi payment |
| `payment_type` | `nchar(1)` | No | `N'O'` | C=Cash, Q=QRIS, D=Debit, K=Credit, T=Transfer, V=Voucher, A=Aggregator, O=Other |
| `currency_code` | `CurrCodeType` | No | `N'IDR'` | Mata uang |
| `payment_amt` | `AmountType` | No | `0` | Nilai pembayaran |
| `fee_amt` | `AmountType` | No | `0` | Fee/MDR/commission |
| `net_settlement_amt` | `AmountType` | No | `0` | Nilai bersih settlement |
| `reference_num` | `nvarchar(100)` | Yes |  | Referensi transaksi payment |
| `bank_code` | `nvarchar(20)` | Yes |  | Bank/provider |
| `card_type` | `nvarchar(20)` | Yes |  | Card type |
| `masked_card_num` | `nvarchar(25)` | Yes |  | Nomor kartu tersamarkan |
| `approval_code` | `nvarchar(30)` | Yes |  | Approval code |
| `terminal_id` | `nvarchar(30)` | Yes |  | Terminal ID |
| `merchant_id` | `nvarchar(50)` | Yes |  | Merchant ID |
| `settlement_date` | `DateType` | Yes |  | Tanggal settlement |
| `acct` | `AcctType` | Yes |  | Account hasil mapping |
| `unit_code1` | `UnitCode1Type` | Yes |  | Unit code 1 |
| `unit_code2` | `UnitCode2Type` | Yes |  | Unit code 2 |
| `unit_code3` | `UnitCode3Type` | Yes |  | Unit code 3 |
| `unit_code4` | `UnitCode4Type` | Yes |  | Unit code 4 |
| `stat` | `nchar(1)` | No | `N'N'` | Status |
| `validation_msg` | `nvarchar(1000)` | Yes |  | Ringkasan validasi |
| `error_msg` | `nvarchar(4000)` | Yes |  | Error terakhir |
| `syteline_ref` | `nvarchar(50)` | Yes |  | Referensi hasil SyteLine |
| `process_date` | `DateType` | Yes |  | Waktu proses |

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
TRX001 / seq 1 / CASH     / 100000
TRX001 / seq 2 / QRIS_BCA / 125000
TRX001 / seq 3 / VOUCHER  /  25000
```
