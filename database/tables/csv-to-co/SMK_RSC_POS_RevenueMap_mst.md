# SMK_RSC_POS_RevenueMap_mst

## Identity

```text
Metadata object : SMK_RSC_POS_RevenueMap_mst
Physical table  : dbo.ue_SMK_RSC_POS_RevenueMap_mst
Purpose         : Rule mapping komponen penjualan POS ke akun dan dimensi SyteLine
Status          : Candidate design / PoC, menunggu raw data dan accounting flow resmi
```

Tabel ini memakai rule yang fleksibel. Kolom kriteria yang `NULL` dianggap wildcard. Dengan desain ini, account dapat ditentukan berdasarkan item, kategori, channel, order type, outlet, line type, atau kombinasi beberapa kriteria.

## Primary Key

```text
map_id
```

`map_id` menggunakan `RowPointerType`/`uniqueidentifier` dengan default `newid()` agar rule tidak dibatasi oleh composite key yang panjang dan mudah berubah ketika requirement berkembang.

## Full Column Structure

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
|---|---|---|---|---|---:|---:|---|---|---:|---:|
| `map_id` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 1 | 1 |
| `source_system` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 0 |  |
| `target_site` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | SiteType | nvarchar | 8 |  |  | NO | 0 |  |
| `rule_name` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 100 |  |  | NO | 0 |  |
| `priority` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | int | int |  |  | `100` | NO | 0 |  |
| `amount_type` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nchar | nchar | 1 |  | `N'R'` | NO | 0 |  |
| `outlet_code` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `pos_item_code` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `pos_category` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `sales_channel` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `order_type` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `line_type` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nchar | nchar | 1 |  |  | YES | 0 |  |
| `currency_code` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | CurrCodeType | nvarchar | 3 |  |  | YES | 0 |  |
| `acct` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | AcctType | nvarchar | 12 |  |  | NO | 0 |  |
| `unit_code1` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code2` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code3` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code4` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `debit_credit` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nchar | nchar | 1 |  | `N'C'` | NO | 0 |  |
| `reverse_on_refund` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `active_flag` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `effective_date` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `expiration_date` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `notes` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_RevenueMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Tab-delimited Structure

```text
Column Name	Schema	Table Name	Data Type	System Data Type	Length	Decimal Position	Default Value	Is Nullable	Primary Key	Key Sequence
map_id	dbo	ue_SMK_RSC_POS_RevenueMap_mst	RowPointerType	uniqueidentifier			newid()	NO	1	1
source_system	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	30		N'POS'	NO	0	
target_site	dbo	ue_SMK_RSC_POS_RevenueMap_mst	SiteType	nvarchar	8			NO	0	
rule_name	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	100			NO	0	
priority	dbo	ue_SMK_RSC_POS_RevenueMap_mst	int	int			100	NO	0	
amount_type	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nchar	nchar	1		N'R'	NO	0	
outlet_code	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	20			YES	0	
pos_item_code	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	50			YES	0	
pos_category	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	30			YES	0	
sales_channel	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	30			YES	0	
order_type	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	20			YES	0	
line_type	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nchar	nchar	1			YES	0	
currency_code	dbo	ue_SMK_RSC_POS_RevenueMap_mst	CurrCodeType	nvarchar	3			YES	0	
acct	dbo	ue_SMK_RSC_POS_RevenueMap_mst	AcctType	nvarchar	12			NO	0	
unit_code1	dbo	ue_SMK_RSC_POS_RevenueMap_mst	UnitCode1Type	nvarchar	4			YES	0	
unit_code2	dbo	ue_SMK_RSC_POS_RevenueMap_mst	UnitCode2Type	nvarchar	4			YES	0	
unit_code3	dbo	ue_SMK_RSC_POS_RevenueMap_mst	UnitCode3Type	nvarchar	4			YES	0	
unit_code4	dbo	ue_SMK_RSC_POS_RevenueMap_mst	UnitCode4Type	nvarchar	4			YES	0	
debit_credit	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nchar	nchar	1		N'C'	NO	0	
reverse_on_refund	dbo	ue_SMK_RSC_POS_RevenueMap_mst	FlagNyType	tinyint			1	NO	0	
active_flag	dbo	ue_SMK_RSC_POS_RevenueMap_mst	FlagNyType	tinyint			1	NO	0	
effective_date	dbo	ue_SMK_RSC_POS_RevenueMap_mst	DateType	datetime			getdate()	NO	0	
expiration_date	dbo	ue_SMK_RSC_POS_RevenueMap_mst	DateType	datetime				YES	0	
notes	dbo	ue_SMK_RSC_POS_RevenueMap_mst	nvarchar	nvarchar	1000			YES	0	
CreateDate	dbo	ue_SMK_RSC_POS_RevenueMap_mst	CurrentDateType	datetime			getdate()	NO	0	
CreatedBy	dbo	ue_SMK_RSC_POS_RevenueMap_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
InWorkflow	dbo	ue_SMK_RSC_POS_RevenueMap_mst	FlagNyType	tinyint			0	NO	0	
NoteExistsFlag	dbo	ue_SMK_RSC_POS_RevenueMap_mst	FlagNyType	tinyint			0	NO	0	
RecordDate	dbo	ue_SMK_RSC_POS_RevenueMap_mst	CurrentDateType	datetime			getdate()	NO	0	
RowPointer	dbo	ue_SMK_RSC_POS_RevenueMap_mst	RowPointerType	uniqueidentifier			newid()	NO	0	
SiteRef	dbo	ue_SMK_RSC_POS_RevenueMap_mst	SiteType	nvarchar	8		rtrim(CONVERT([nvarchar](8),context_info(),(0)))	NO	0	
UpdatedBy	dbo	ue_SMK_RSC_POS_RevenueMap_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
```

## Amount Type

| Value | Meaning | Typical posting |
|---|---|---|
| `R` | Revenue/penjualan | Credit revenue |
| `D` | Discount/contra revenue | Debit discount/contra revenue |
| `S` | Service charge | Credit service income |
| `O` | Other income/component | Berdasarkan konfigurasi |

`debit_credit` tetap disimpan secara eksplisit agar posting preview tidak mengasumsikan bahwa seluruh komponen selalu credit.

## Rule Matching

Kolom kriteria yang `NULL` dianggap wildcard:

```sql
WHERE source_system = @SourceSystem
  AND target_site = @TargetSite
  AND amount_type = @AmountType
  AND active_flag = 1
  AND effective_date <= @BusinessDate
  AND (expiration_date IS NULL OR expiration_date >= @BusinessDate)
  AND (outlet_code IS NULL OR outlet_code = @OutletCode)
  AND (pos_item_code IS NULL OR pos_item_code = @PosItemCode)
  AND (pos_category IS NULL OR pos_category = @PosCategory)
  AND (sales_channel IS NULL OR sales_channel = @SalesChannel)
  AND (order_type IS NULL OR order_type = @OrderType)
  AND (line_type IS NULL OR line_type = @LineType)
  AND (currency_code IS NULL OR currency_code = @CurrencyCode)
```

Urutan pemilihan rule:

1. `priority` paling kecil;
2. rule dengan kriteria non-null paling banyak;
3. `effective_date` terbaru;
4. bila masih lebih dari satu, hasil dianggap ambigu dan validasi gagal.

## Example Rules

```text
Rule 10 — Item-specific
priority       : 10
amount_type    : R
pos_item_code  : PIZZA-SUPREME-L
acct           : FOOD-SALES

Rule 50 — Category fallback
priority       : 50
amount_type    : R
pos_category   : PIZZA
acct           : FOOD-SALES

Rule 999 — Site default
priority       : 999
amount_type    : R
acct           : POS-SUSP
```

Contoh discount rule:

```text
rule_name      : Pizza Discount
priority       : 50
amount_type    : D
pos_category   : PIZZA
acct           : SALES-DISC
debit_credit   : D
```

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_RevenueMap_01
SiteRef, source_system, target_site, amount_type, active_flag, priority

IX_ue_SMK_RSC_POS_RevenueMap_02
SiteRef, target_site, pos_item_code, amount_type, active_flag

IX_ue_SMK_RSC_POS_RevenueMap_03
SiteRef, target_site, pos_category, sales_channel, amount_type, active_flag

IX_ue_SMK_RSC_POS_RevenueMap_04
SiteRef, target_site, acct, active_flag
```

## Validation Rules

- `priority >= 0`.
- `amount_type` harus termasuk nilai yang didukung.
- `debit_credit` hanya `D` atau `C`.
- `acct` harus valid dan aktif pada target site.
- Unit code harus valid terhadap account.
- `effective_date <= expiration_date` bila expiration date terisi.
- Active rule tidak boleh menghasilkan hasil ambigu untuk kombinasi source yang sama.
- Setiap site dan `amount_type` sebaiknya memiliki fallback rule yang disetujui Finance.
- Rule fallback tidak berarti data boleh diposting otomatis ke suspense tanpa approval.
- Refund/void treatment mengikuti `reverse_on_refund` dan aturan transaksi resmi.
- Source values tetap disimpan pada staging; account dan dimension adalah hasil mapping internal.

## Open Decisions

- Apakah revenue dipetakan per item, kategori, outlet, channel, atau cukup default site.
- Apakah discount diposting sebagai contra revenue atau dikurangi langsung dari revenue.
- Apakah service charge memiliki account terpisah.
- Struktur unit code aktual perusahaan.
- Treatment refund, void, complimentary, promotion, dan package/modifier.
- Apakah rule default/suspense diperbolehkan pada produksi.
