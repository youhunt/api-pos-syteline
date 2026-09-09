# SMK_RSC_POS_TaxMap_mst

## Identity

```text
Metadata object : SMK_RSC_POS_TaxMap_mst
Physical table  : dbo.ue_SMK_RSC_POS_TaxMap_mst
Purpose         : Mapping kode pajak POS ke tax code, account, dimensi, dan aturan perhitungan SyteLine
```

## Primary Key

```text
source_system + target_site + pos_tax_code
```

Mapping dibuat per source system dan target site karena kode pajak yang sama dapat diarahkan berbeda pada site berbeda.

## Full Column Structure

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
|---|---|---|---|---|---:|---:|---|---|---:|---:|
| `source_system` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 1 | 1 |
| `target_site` | dbo | ue_SMK_RSC_POS_TaxMap_mst | SiteType | nvarchar | 8 |  |  | NO | 1 | 2 |
| `pos_tax_code` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nvarchar | nvarchar | 20 |  |  | NO | 1 | 3 |
| `pos_tax_desc` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `tax_type` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nchar | nchar | 1 |  | `N'S'` | NO | 0 |  |
| `posting_mode` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nchar | nchar | 1 |  | `N'A'` | NO | 0 |  |
| `syteline_tax_code` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `tax_rate` | dbo | ue_SMK_RSC_POS_TaxMap_mst | decimal | decimal | 9 | 5 | `0` | NO | 0 |  |
| `tax_inclusive_flag` | dbo | ue_SMK_RSC_POS_TaxMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `taxable_flag` | dbo | ue_SMK_RSC_POS_TaxMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `tax_acct` | dbo | ue_SMK_RSC_POS_TaxMap_mst | AcctType | nvarchar | 12 |  |  | YES | 0 |  |
| `unit_code1` | dbo | ue_SMK_RSC_POS_TaxMap_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code2` | dbo | ue_SMK_RSC_POS_TaxMap_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code3` | dbo | ue_SMK_RSC_POS_TaxMap_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code4` | dbo | ue_SMK_RSC_POS_TaxMap_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `rounding_mode` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `tolerance_amt` | dbo | ue_SMK_RSC_POS_TaxMap_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `active_flag` | dbo | ue_SMK_RSC_POS_TaxMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `effective_date` | dbo | ue_SMK_RSC_POS_TaxMap_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `expiration_date` | dbo | ue_SMK_RSC_POS_TaxMap_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `notes` | dbo | ue_SMK_RSC_POS_TaxMap_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_TaxMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_TaxMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_TaxMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_TaxMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_TaxMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_TaxMap_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_TaxMap_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_TaxMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Tab-delimited Structure

```text
Column Name	Schema	Table Name	Data Type	System Data Type	Length	Decimal Position	Default Value	Is Nullable	Primary Key	Key Sequence
source_system	dbo	ue_SMK_RSC_POS_TaxMap_mst	nvarchar	nvarchar	30		N'POS'	NO	1	1
target_site	dbo	ue_SMK_RSC_POS_TaxMap_mst	SiteType	nvarchar	8			NO	1	2
pos_tax_code	dbo	ue_SMK_RSC_POS_TaxMap_mst	nvarchar	nvarchar	20			NO	1	3
pos_tax_desc	dbo	ue_SMK_RSC_POS_TaxMap_mst	nvarchar	nvarchar	100			YES	0	
tax_type	dbo	ue_SMK_RSC_POS_TaxMap_mst	nchar	nchar	1		N'S'	NO	0	
posting_mode	dbo	ue_SMK_RSC_POS_TaxMap_mst	nchar	nchar	1		N'A'	NO	0	
syteline_tax_code	dbo	ue_SMK_RSC_POS_TaxMap_mst	nvarchar	nvarchar	20			YES	0	
tax_rate	dbo	ue_SMK_RSC_POS_TaxMap_mst	decimal	decimal	9	5	0	NO	0	
tax_inclusive_flag	dbo	ue_SMK_RSC_POS_TaxMap_mst	FlagNyType	tinyint			1	NO	0	
taxable_flag	dbo	ue_SMK_RSC_POS_TaxMap_mst	FlagNyType	tinyint			1	NO	0	
tax_acct	dbo	ue_SMK_RSC_POS_TaxMap_mst	AcctType	nvarchar	12			YES	0	
unit_code1	dbo	ue_SMK_RSC_POS_TaxMap_mst	UnitCode1Type	nvarchar	4			YES	0	
unit_code2	dbo	ue_SMK_RSC_POS_TaxMap_mst	UnitCode2Type	nvarchar	4			YES	0	
unit_code3	dbo	ue_SMK_RSC_POS_TaxMap_mst	UnitCode3Type	nvarchar	4			YES	0	
unit_code4	dbo	ue_SMK_RSC_POS_TaxMap_mst	UnitCode4Type	nvarchar	4			YES	0	
rounding_mode	dbo	ue_SMK_RSC_POS_TaxMap_mst	nchar	nchar	1		N'N'	NO	0	
tolerance_amt	dbo	ue_SMK_RSC_POS_TaxMap_mst	AmountType	decimal	23	8	0	NO	0	
active_flag	dbo	ue_SMK_RSC_POS_TaxMap_mst	FlagNyType	tinyint			1	NO	0	
effective_date	dbo	ue_SMK_RSC_POS_TaxMap_mst	DateType	datetime			getdate()	NO	0	
expiration_date	dbo	ue_SMK_RSC_POS_TaxMap_mst	DateType	datetime				YES	0	
notes	dbo	ue_SMK_RSC_POS_TaxMap_mst	nvarchar	nvarchar	1000			YES	0	
CreateDate	dbo	ue_SMK_RSC_POS_TaxMap_mst	CurrentDateType	datetime			getdate()	NO	0	
CreatedBy	dbo	ue_SMK_RSC_POS_TaxMap_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
InWorkflow	dbo	ue_SMK_RSC_POS_TaxMap_mst	FlagNyType	tinyint			0	NO	0	
NoteExistsFlag	dbo	ue_SMK_RSC_POS_TaxMap_mst	FlagNyType	tinyint			0	NO	0	
RecordDate	dbo	ue_SMK_RSC_POS_TaxMap_mst	CurrentDateType	datetime			getdate()	NO	0	
RowPointer	dbo	ue_SMK_RSC_POS_TaxMap_mst	RowPointerType	uniqueidentifier			newid()	NO	0	
SiteRef	dbo	ue_SMK_RSC_POS_TaxMap_mst	SiteType	nvarchar	8		rtrim(CONVERT([nvarchar](8),context_info(),(0)))	NO	0	
UpdatedBy	dbo	ue_SMK_RSC_POS_TaxMap_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
```

## Code Definitions

### tax_type

| Code | Meaning |
|---|---|
| `S` | Sales/output tax |
| `E` | Exempt/non-taxable |
| `O` | Other tax treatment |

### posting_mode

| Code | Meaning |
|---|---|
| `T` | Gunakan tax code/proses pajak SyteLine |
| `A` | Posting nilai pajak langsung ke account hasil mapping |
| `N` | Tidak membuat posting pajak terpisah |

### rounding_mode

| Code | Meaning |
|---|---|
| `N` | Normal/standard rounding |
| `U` | Round up |
| `D` | Round down |
| `S` | Gunakan nilai yang dikirim source selama masih dalam tolerance |

## Processing Rules

- `posting_mode = T` mewajibkan `syteline_tax_code`.
- `posting_mode = A` mewajibkan `tax_acct`.
- `posting_mode = N` digunakan untuk kode exempt/non-taxable atau treatment yang tidak membutuhkan tax posting terpisah.
- `tax_inclusive_flag = 1` berarti nilai transaksi dari POS sudah termasuk pajak.
- `taxable_flag = 0` berarti rate dan nilai pajak normalnya nol, kecuali Finance menyetujui rule khusus.
- `tolerance_amt` menentukan selisih maksimum antara nilai pajak source dan nilai perhitungan ulang.
- Account dan unit code merupakan hasil mapping internal dan tidak boleh dipercaya dari payload POS.

## Lookup Rule

```sql
WHERE source_system = @SourceSystem
  AND target_site = @TargetSite
  AND pos_tax_code = @PosTaxCode
  AND active_flag = 1
  AND effective_date <= @BusinessDate
  AND (expiration_date IS NULL OR expiration_date >= @BusinessDate)
```

## Validation Rules

- Mapping aktif harus tepat satu pada business date.
- `tax_rate >= 0` dan tidak boleh melebihi batas yang disetujui Finance.
- `effective_date <= expiration_date` jika expiration date terisi.
- Masa berlaku mapping tidak boleh overlap untuk kombinasi key yang sama.
- Target account dan unit codes harus valid pada target site.
- Nilai pajak source tidak boleh ditimpa; hasil validasi/perhitungan ulang disimpan atau ditampilkan terpisah.
- Tax treatment final harus disetujui Finance sebelum posting produksi.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_TaxMap_01
SiteRef, source_system, target_site, active_flag, pos_tax_code

IX_ue_SMK_RSC_POS_TaxMap_02
SiteRef, target_site, syteline_tax_code

IX_ue_SMK_RSC_POS_TaxMap_03
SiteRef, target_site, tax_acct

IX_ue_SMK_RSC_POS_TaxMap_04
SiteRef, tax_type, posting_mode, active_flag
```

## Example

```text
source_system       : PIZZAHUT_POS
target_site         : SBY
pos_tax_code        : SALES_TAX
pos_tax_desc        : Sales tax from POS
tax_type            : S
posting_mode         : A
syteline_tax_code   :
tax_rate            : 10.00000
tax_inclusive_flag  : 1
taxable_flag        : 1
tax_acct             : 210500
rounding_mode        : S
tolerance_amt        : 1
active_flag          : 1
```

## Important Note

Nama UDD/domain untuk target tax code dapat berbeda antar versi atau tenant. Karena itu `syteline_tax_code` sementara didokumentasikan sebagai `nvarchar(20)`. Sebelum tabel dibuat untuk produksi, verifikasi apakah environment menyediakan domain standar yang harus dipakai.