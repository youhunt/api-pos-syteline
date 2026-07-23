# SMK_RSC_POS_PostingPreview_mst

## Identity

```text
Metadata object : SMK_RSC_POS_PostingPreview_mst
Physical table  : dbo.ue_SMK_RSC_POS_PostingPreview_mst
Purpose         : Menyimpan hasil simulasi debit-credit sebelum posting aktual ke SyteLine
Status          : Candidate design / PoC, menunggu raw data, accounting flow, dan target module resmi
```

Satu `preview_num` mewakili satu hasil generate posting preview. Satu preview memiliki banyak line debit-credit. Apabila preview dibangun ulang, buat preview/generation baru dan jangan menimpa preview yang sudah disetujui atau sudah diposting.

## Primary Key

```text
preview_num + line_num
```

## Full Column Structure

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
|---|---|---|---|---|---:|---:|---|---|---:|---:|
| `preview_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 1 |
| `line_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | int | int |  |  |  | NO | 1 | 2 |
| `batch_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 30 |  |  | NO | 0 |  |
| `generation_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | int | int |  |  | `1` | NO | 0 |  |
| `posting_group` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `target_module` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nchar | nchar | 1 |  | `N'G'` | NO | 0 |  |
| `source_level` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nchar | nchar | 1 |  | `N'B'` | NO | 0 |  |
| `trans_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `source_line_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | int | int |  |  |  | YES | 0 |  |
| `payment_seq` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | int | int |  |  |  | YES | 0 |  |
| `component_type` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nchar | nchar | 1 |  | `N'O'` | NO | 0 |  |
| `mapping_source` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `mapping_ref` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `posting_date` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `currency_code` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | CurrCodeType | nvarchar | 3 |  | `N'IDR'` | NO | 0 |  |
| `exch_rate` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | ExchRateType | decimal | 12 | 7 | `1` | NO | 0 |  |
| `acct` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | AcctType | nvarchar | 12 |  |  | NO | 0 |  |
| `unit_code1` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code2` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code3` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code4` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `description` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 200 |  |  | YES | 0 |  |
| `reference_num` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `source_amt` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `debit_amt` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `credit_amt` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `dom_debit_amt` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `dom_credit_amt` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `approval_stat` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `approved_by` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UsernameType | nvarchar | 128 |  |  | YES | 0 |  |
| `approved_date` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `posting_stat` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `posted_date` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `validation_msg` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_PostingPreview_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Tab-delimited Structure

```text
Column Name	Schema	Table Name	Data Type	System Data Type	Length	Decimal Position	Default Value	Is Nullable	Primary Key	Key Sequence
preview_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	30			NO	1	1
line_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	int	int				NO	1	2
batch_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	30			NO	0	
generation_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	int	int			1	NO	0	
posting_group	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	30			YES	0	
target_module	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nchar	nchar	1		N'G'	NO	0	
source_level	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nchar	nchar	1		N'B'	NO	0	
trans_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	50			YES	0	
source_line_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	int	int				YES	0	
payment_seq	dbo	ue_SMK_RSC_POS_PostingPreview_mst	int	int				YES	0	
component_type	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nchar	nchar	1		N'O'	NO	0	
mapping_source	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nchar	nchar	1		N'N'	NO	0	
mapping_ref	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	100			YES	0	
posting_date	dbo	ue_SMK_RSC_POS_PostingPreview_mst	DateType	datetime			getdate()	NO	0	
currency_code	dbo	ue_SMK_RSC_POS_PostingPreview_mst	CurrCodeType	nvarchar	3		N'IDR'	NO	0	
exch_rate	dbo	ue_SMK_RSC_POS_PostingPreview_mst	ExchRateType	decimal	12	7	1	NO	0	
acct	dbo	ue_SMK_RSC_POS_PostingPreview_mst	AcctType	nvarchar	12			NO	0	
unit_code1	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UnitCode1Type	nvarchar	4			YES	0	
unit_code2	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UnitCode2Type	nvarchar	4			YES	0	
unit_code3	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UnitCode3Type	nvarchar	4			YES	0	
unit_code4	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UnitCode4Type	nvarchar	4			YES	0	
description	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	200			YES	0	
reference_num	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	100			YES	0	
source_amt	dbo	ue_SMK_RSC_POS_PostingPreview_mst	AmountType	decimal	23	8	0	NO	0	
debit_amt	dbo	ue_SMK_RSC_POS_PostingPreview_mst	AmountType	decimal	23	8	0	NO	0	
credit_amt	dbo	ue_SMK_RSC_POS_PostingPreview_mst	AmountType	decimal	23	8	0	NO	0	
dom_debit_amt	dbo	ue_SMK_RSC_POS_PostingPreview_mst	AmountType	decimal	23	8	0	NO	0	
dom_credit_amt	dbo	ue_SMK_RSC_POS_PostingPreview_mst	AmountType	decimal	23	8	0	NO	0	
approval_stat	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nchar	nchar	1		N'N'	NO	0	
approved_by	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UsernameType	nvarchar	128			YES	0	
approved_date	dbo	ue_SMK_RSC_POS_PostingPreview_mst	DateType	datetime				YES	0	
posting_stat	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nchar	nchar	1		N'N'	NO	0	
posted_date	dbo	ue_SMK_RSC_POS_PostingPreview_mst	DateType	datetime				YES	0	
syteline_ref	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	50			YES	0	
validation_msg	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	1000			YES	0	
error_msg	dbo	ue_SMK_RSC_POS_PostingPreview_mst	nvarchar	nvarchar	4000			YES	0	
CreateDate	dbo	ue_SMK_RSC_POS_PostingPreview_mst	CurrentDateType	datetime			getdate()	NO	0	
CreatedBy	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
InWorkflow	dbo	ue_SMK_RSC_POS_PostingPreview_mst	FlagNyType	tinyint			0	NO	0	
NoteExistsFlag	dbo	ue_SMK_RSC_POS_PostingPreview_mst	FlagNyType	tinyint			0	NO	0	
RecordDate	dbo	ue_SMK_RSC_POS_PostingPreview_mst	CurrentDateType	datetime			getdate()	NO	0	
RowPointer	dbo	ue_SMK_RSC_POS_PostingPreview_mst	RowPointerType	uniqueidentifier			newid()	NO	0	
SiteRef	dbo	ue_SMK_RSC_POS_PostingPreview_mst	SiteType	nvarchar	8		rtrim(CONVERT([nvarchar](8),context_info(),(0)))	NO	0	
UpdatedBy	dbo	ue_SMK_RSC_POS_PostingPreview_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
```

## Codes

### `target_module`

| Value | Meaning |
|---|---|
| `G` | General Ledger |
| `A` | Accounts Receivable |
| `O` | Customer Order / order flow |
| `I` | Inventory |
| `U` | Undecided / belum ditetapkan |

Default `G` hanya untuk PoC dan harus disesuaikan setelah jalur posting resmi diputuskan.

### `source_level`

| Value | Meaning |
|---|---|
| `B` | Batch/summary |
| `T` | Transaction |
| `L` | Transaction line |
| `P` | Payment |
| `S` | System/generated balancing line |

### `component_type`

| Value | Meaning |
|---|---|
| `R` | Revenue |
| `D` | Discount/contra revenue |
| `T` | Tax |
| `S` | Service charge |
| `P` | Payment/cash/bank/clearing/receivable |
| `F` | Fee/MDR/commission |
| `N` | Rounding |
| `O` | Other |

### `mapping_source`

| Value | Meaning |
|---|---|
| `O` | Outlet mapping |
| `I` | Item mapping |
| `P` | Payment mapping |
| `T` | Tax mapping |
| `R` | Revenue mapping |
| `M` | Manual override |
| `N` | None/default/generated |

### `approval_stat`

| Value | Meaning |
|---|---|
| `N` | Not submitted |
| `W` | Waiting approval |
| `A` | Approved |
| `R` | Rejected |

### `posting_stat`

| Value | Meaning |
|---|---|
| `N` | New |
| `V` | Validated / ready |
| `I` | In process |
| `P` | Posted |
| `E` | Error |
| `C` | Cancelled |

## Generation and Versioning Rules

- `preview_num` mengidentifikasi satu set preview.
- `generation_num` menunjukkan hasil build keberapa untuk batch terkait.
- Rebuild membuat preview baru; jangan mengubah preview yang sudah `approval_stat = A` atau `posting_stat = P`.
- `posting_group` dapat digunakan untuk memisahkan journal per tanggal, outlet, transaksi, atau grouping lain sesuai requirement.
- `mapping_ref` menyimpan nama rule, kode mapping, atau referensi lain yang membantu audit. Karena mapping table memiliki bentuk primary key berbeda-beda, field ini sengaja dibuat generik.

## Amount Rules

Satu line hanya boleh mengisi salah satu sisi:

```text
debit_amt > 0  AND credit_amt = 0
atau
credit_amt > 0 AND debit_amt = 0
```

Domestic amount dihitung sesuai currency dan exchange rate yang disetujui:

```text
dom_debit_amt  = debit_amt  × exchange-rate rule
dom_credit_amt = credit_amt × exchange-rate rule
```

Detail arah rate serta rounding harus mengikuti konfigurasi currency SyteLine dan dikonfirmasi pada tenant.

## Balance Rules

Untuk setiap `preview_num` dan, bila dipakai, setiap `posting_group`:

```text
SUM(debit_amt) = SUM(credit_amt)
SUM(dom_debit_amt) = SUM(dom_credit_amt)
```

Selisih hanya dapat diterima jika terdapat rounding rule/tolerance yang disetujui Finance dan dibuat sebagai line rounding eksplisit. Preview tidak boleh disetujui atau diposting dalam kondisi tidak balance.

## Example

```text
preview_num : PV-20260723-000001
batch_num   : SMKPOS-20260723-000001

Line 1
component_type : P
acct           : POS-CLEARING
debit_amt      : 198000
credit_amt     : 0

Line 2
component_type : R
acct           : FOOD-SALES
debit_amt      : 0
credit_amt     : 180000

Line 3
component_type : T
acct           : TAX-PAYABLE
debit_amt      : 0
credit_amt     : 18000

Total Debit  : 198000
Total Credit : 198000
```

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_PostingPreview_01
SiteRef, batch_num, preview_num, line_num

IX_ue_SMK_RSC_POS_PostingPreview_02
SiteRef, preview_num, acct

IX_ue_SMK_RSC_POS_PostingPreview_03
SiteRef, batch_num, approval_stat, posting_stat

IX_ue_SMK_RSC_POS_PostingPreview_04
SiteRef, posting_date, target_module, posting_stat
```

## Validation Rules

- Parent `batch_num` harus tersedia.
- `line_num > 0` dan unik dalam `preview_num`.
- `generation_num > 0`.
- `acct` wajib valid dan aktif pada target site.
- Unit code harus valid terhadap account.
- Currency dan exchange rate harus valid.
- Satu line tidak boleh memiliki debit dan credit sekaligus.
- Satu line tidak boleh bernilai nol pada kedua sisi.
- Total debit-credit transaction currency harus balance.
- Total debit-credit domestic currency harus balance.
- Preview yang memiliki error mapping tidak boleh disetujui.
- Preview yang belum approved tidak boleh diposting bila approval diwajibkan.
- Preview posted tidak boleh diposting ulang.
- Rebuild setelah approval/posting harus menghasilkan preview baru atau reversal sesuai prosedur.
- Posting date harus berada pada accounting period yang diperbolehkan.
- `syteline_ref` wajib diisi setelah posting aktual berhasil.

## Open Decisions

- Jalur posting final: GL, AR, Customer Order, inventory, atau kombinasi.
- Level grouping: per transaksi, tanggal, outlet, batch, payment method, atau account summary.
- Apakah approval wajib dan siapa approver-nya.
- Apakah preview lama dipertahankan seluruhnya atau mengikuti retention policy.
- Exchange-rate direction dan rounding menurut tenant.
- Bentuk reference SyteLine setelah posting.
