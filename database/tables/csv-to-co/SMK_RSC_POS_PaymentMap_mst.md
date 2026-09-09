# SMK_RSC_POS_PaymentMap_mst

## Identity

```text
Metadata object : SMK_RSC_POS_PaymentMap_mst
Physical table  : dbo.ue_SMK_RSC_POS_PaymentMap_mst
Purpose         : Mapping kode pembayaran POS ke account, dimension, customer, dan aturan settlement SyteLine
```

Tabel ini tidak menyimpan transaksi pembayaran. Tabel ini merupakan master mapping yang dipakai saat validasi dan pengolahan record pada `SMK_RSC_POS_Payment_mst`.

## Primary Key

```text
source_system + target_site + payment_code
```

Kode pembayaran yang sama dapat diarahkan ke account atau dimensi berbeda pada site yang berbeda.

## Table Structure

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
|---|---|---|---|---|---:|---:|---|---|---:|---:|
| `source_system` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 1 | 1 |
| `target_site` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | SiteType | nvarchar | 8 |  |  | NO | 1 | 2 |
| `payment_code` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 3 |
| `payment_desc` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `payment_type` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nchar | nchar | 1 |  | `N'O'` | NO | 0 |  |
| `currency_code` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | CurrCodeType | nvarchar | 3 |  | `N'IDR'` | NO | 0 |  |
| `acct` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | AcctType | nvarchar | 12 |  |  | NO | 0 |  |
| `unit_code1` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code2` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code3` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code4` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `fee_acct` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | AcctType | nvarchar | 12 |  |  | YES | 0 |  |
| `fee_unit_code1` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `fee_unit_code2` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `fee_unit_code3` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `fee_unit_code4` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `cust_num` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | CustNumType | nvarchar | 7 |  |  | YES | 0 |  |
| `bank_code` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `settlement_type` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nchar | nchar | 1 |  | `N'I'` | NO | 0 |  |
| `settlement_days` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | int | int |  |  | `0` | NO | 0 |  |
| `active_flag` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `effective_date` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `expiration_date` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `notes` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_PaymentMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Tab-delimited Format

```text
Column Name	Schema	Table Name	Data Type	System Data Type	Length	Decimal Position	Default Value	Is Nullable	Primary Key	Key Sequence
source_system	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nvarchar	nvarchar	30		N'POS'	NO	1	1
target_site	dbo	ue_SMK_RSC_POS_PaymentMap_mst	SiteType	nvarchar	8			NO	1	2
payment_code	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nvarchar	nvarchar	30			NO	1	3
payment_desc	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nvarchar	nvarchar	100			YES	0	
payment_type	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nchar	nchar	1		N'O'	NO	0	
currency_code	dbo	ue_SMK_RSC_POS_PaymentMap_mst	CurrCodeType	nvarchar	3		N'IDR'	NO	0	
acct	dbo	ue_SMK_RSC_POS_PaymentMap_mst	AcctType	nvarchar	12			NO	0	
unit_code1	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode1Type	nvarchar	4			YES	0	
unit_code2	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode2Type	nvarchar	4			YES	0	
unit_code3	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode3Type	nvarchar	4			YES	0	
unit_code4	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode4Type	nvarchar	4			YES	0	
fee_acct	dbo	ue_SMK_RSC_POS_PaymentMap_mst	AcctType	nvarchar	12			YES	0	
fee_unit_code1	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode1Type	nvarchar	4			YES	0	
fee_unit_code2	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode2Type	nvarchar	4			YES	0	
fee_unit_code3	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode3Type	nvarchar	4			YES	0	
fee_unit_code4	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UnitCode4Type	nvarchar	4			YES	0	
cust_num	dbo	ue_SMK_RSC_POS_PaymentMap_mst	CustNumType	nvarchar	7			YES	0	
bank_code	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nvarchar	nvarchar	20			YES	0	
settlement_type	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nchar	nchar	1		N'I'	NO	0	
settlement_days	dbo	ue_SMK_RSC_POS_PaymentMap_mst	int	int			0	NO	0	
active_flag	dbo	ue_SMK_RSC_POS_PaymentMap_mst	FlagNyType	tinyint			1	NO	0	
effective_date	dbo	ue_SMK_RSC_POS_PaymentMap_mst	DateType	datetime			getdate()	NO	0	
expiration_date	dbo	ue_SMK_RSC_POS_PaymentMap_mst	DateType	datetime				YES	0	
notes	dbo	ue_SMK_RSC_POS_PaymentMap_mst	nvarchar	nvarchar	1000			YES	0	
CreateDate	dbo	ue_SMK_RSC_POS_PaymentMap_mst	CurrentDateType	datetime			getdate()	NO	0	
CreatedBy	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
InWorkflow	dbo	ue_SMK_RSC_POS_PaymentMap_mst	FlagNyType	tinyint			0	NO	0	
NoteExistsFlag	dbo	ue_SMK_RSC_POS_PaymentMap_mst	FlagNyType	tinyint			0	NO	0	
RecordDate	dbo	ue_SMK_RSC_POS_PaymentMap_mst	CurrentDateType	datetime			getdate()	NO	0	
RowPointer	dbo	ue_SMK_RSC_POS_PaymentMap_mst	RowPointerType	uniqueidentifier			newid()	NO	0	
SiteRef	dbo	ue_SMK_RSC_POS_PaymentMap_mst	SiteType	nvarchar	8		rtrim(CONVERT([nvarchar](8),context_info(),(0)))	NO	0	
UpdatedBy	dbo	ue_SMK_RSC_POS_PaymentMap_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
```

## Payment Type

| Value | Meaning |
|---|---|
| `C` | Cash |
| `Q` | QRIS |
| `D` | Debit card |
| `K` | Credit card |
| `T` | Bank transfer |
| `V` | Voucher |
| `A` | Aggregator, misalnya GoFood/GrabFood |
| `O` | Other |

## Settlement Type

| Value | Meaning |
|---|---|
| `I` | Immediate — dianggap langsung menjadi kas/bank/clearing pada tanggal transaksi |
| `D` | Delayed — settlement diterima beberapa hari setelah transaksi |
| `A` | Accounts Receivable — diarahkan melalui customer/receivable bila flow AR digunakan |
| `N` | Non-settlement — contoh voucher liability atau metode lain yang tidak langsung diselesaikan |

`settlement_days` merupakan nilai default untuk estimasi tanggal settlement. Nilai aktual dari POS tetap disimpan pada tabel transaksi pembayaran bila tersedia.

## Account Mapping

`acct` adalah account utama yang menerima nilai pembayaran atau receivable/clearing.

Contoh rancangan:

```text
CASH       -> Cash on Hand
QRIS_BCA   -> QRIS BCA Clearing
CREDIT_BCA -> Credit Card BCA Clearing
GOFOOD     -> GoFood Receivable
VOUCHER_PH -> Voucher Liability
```

`fee_acct` digunakan untuk MDR, komisi aggregator, atau biaya settlement bila flow Finance menyetujuinya. Account dan unit code tidak boleh dipercaya dari payload POS; nilainya diambil dari mapping internal ini.

## Customer Mapping

`cust_num` bersifat opsional dan digunakan bila payment/channel perlu diarahkan melalui AR, misalnya:

```text
GOFOOD   -> customer GOFOOD
GRABFOOD -> customer GRABFOOD
```

Bila jalur final langsung menggunakan jurnal GL, `cust_num` dapat dibiarkan kosong.

## Lookup Rule

```sql
WHERE source_system = @SourceSystem
  AND target_site = @TargetSite
  AND payment_code = @PaymentCode
  AND active_flag = 1
  AND effective_date <= @BusinessDate
  AND (expiration_date IS NULL OR expiration_date >= @BusinessDate)
```

## Validation Rules

- Mapping aktif harus ditemukan tepat satu.
- `acct` wajib tersedia dan valid pada target site.
- Unit codes harus valid terhadap account bila account menggunakan unit code.
- `fee_acct` wajib bila terdapat `fee_amt` dan kebijakan posting memisahkan fee.
- `cust_num` wajib bila `settlement_type = A` dan jalur AR digunakan.
- `settlement_days >= 0`.
- Currency mapping harus sesuai dengan payment dan aturan site.
- Periode mapping tidak boleh tumpang tindih bila histori mapping diaktifkan.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_PaymentMap_01
SiteRef, source_system, target_site, active_flag, payment_code

IX_ue_SMK_RSC_POS_PaymentMap_02
SiteRef, target_site, acct

IX_ue_SMK_RSC_POS_PaymentMap_03
SiteRef, payment_type, settlement_type, active_flag

IX_ue_SMK_RSC_POS_PaymentMap_04
SiteRef, cust_num, active_flag
```

## Example

```text
source_system    : PIZZAHUT_POS
target_site      : SBY
payment_code     : QRIS_BCA
payment_desc     : QRIS BCA
payment_type     : Q
currency_code    : IDR
acct             : 110220
unit_code1       : S001
fee_acct         : 610210
bank_code        : BCA
settlement_type  : D
settlement_days  : 1
active_flag      : 1
```

## Result on Payment Staging

Setelah mapping berhasil, nilai berikut pada `SMK_RSC_POS_Payment_mst` dapat diisi oleh logic server-side:

```text
acct
unit_code1
unit_code2
unit_code3
unit_code4
stat = V
```

Mapping tidak boleh mengubah `payment_code`, `payment_amt`, `fee_amt`, atau data sumber lain yang diterima dari POS.