# SMK_RSC_POS_RawLine_mst

## Identity

```text
Metadata object : SMK_RSC_POS_RawLine_mst
Physical table  : dbo.ue_SMK_RSC_POS_RawLine_mst
Purpose         : Landing/staging table minimal untuk source flat berisi tanggal, nomor transaksi, item, quantity, dan total
Status          : Candidate design / PoC, digunakan bila raw data resmi berbentuk flat atau minimal
```

Tabel ini tidak menggantikan seluruh desain lengkap secara otomatis. Tabel ini merupakan jalur alternatif ketika source hanya mengirim data seperti:

```text
business_date | trans_num | pos_item_code | pos_qty | total_amt
```

Data sumber disimpan apa adanya. Hasil mapping ditempatkan pada kolom terpisah agar nilai asli tidak tertimpa.

## Primary Key

```text
batch_num + source_row_num
```

`source_row_num` adalah nomor urut baris pada payload/file sumber. Primary key tidak menggunakan `trans_num + pos_item_code` karena item yang sama dapat muncul lebih dari sekali dalam transaksi yang sama.

## Full Column Structure

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
|---|---|---|---|---|---:|---:|---|---|---:|---:|
| `batch_num` | dbo | ue_SMK_RSC_POS_RawLine_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 1 |
| `source_row_num` | dbo | ue_SMK_RSC_POS_RawLine_mst | int | int |  |  |  | NO | 1 | 2 |
| `business_date` | dbo | ue_SMK_RSC_POS_RawLine_mst | DateType | datetime |  |  |  | NO | 0 |  |
| `trans_num` | dbo | ue_SMK_RSC_POS_RawLine_mst | nvarchar | nvarchar | 50 |  |  | NO | 0 |  |
| `pos_item_code` | dbo | ue_SMK_RSC_POS_RawLine_mst | nvarchar | nvarchar | 50 |  |  | NO | 0 |  |
| `pos_qty` | dbo | ue_SMK_RSC_POS_RawLine_mst | QtyUnitType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `total_amt` | dbo | ue_SMK_RSC_POS_RawLine_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `item` | dbo | ue_SMK_RSC_POS_RawLine_mst | ItemType | nvarchar | 30 |  |  | YES | 0 |  |
| `syteline_qty` | dbo | ue_SMK_RSC_POS_RawLine_mst | QtyUnitType | decimal | 23 | 8 |  | YES | 0 |  |
| `u_m` | dbo | ue_SMK_RSC_POS_RawLine_mst | UMType | nvarchar | 3 |  |  | YES | 0 |  |
| `stat` | dbo | ue_SMK_RSC_POS_RawLine_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK_RSC_POS_RawLine_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_RawLine_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `process_date` | dbo | ue_SMK_RSC_POS_RawLine_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_RawLine_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_RawLine_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_RawLine_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_RawLine_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_RawLine_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_RawLine_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_RawLine_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_RawLine_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_RawLine_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Tab-delimited Structure

```text
Column Name	Schema	Table Name	Data Type	System Data Type	Length	Decimal Position	Default Value	Is Nullable	Primary Key	Key Sequence
batch_num	dbo	ue_SMK_RSC_POS_RawLine_mst	nvarchar	nvarchar	30			NO	1	1
source_row_num	dbo	ue_SMK_RSC_POS_RawLine_mst	int	int				NO	1	2
business_date	dbo	ue_SMK_RSC_POS_RawLine_mst	DateType	datetime				NO	0	
trans_num	dbo	ue_SMK_RSC_POS_RawLine_mst	nvarchar	nvarchar	50			NO	0	
pos_item_code	dbo	ue_SMK_RSC_POS_RawLine_mst	nvarchar	nvarchar	50			NO	0	
pos_qty	dbo	ue_SMK_RSC_POS_RawLine_mst	QtyUnitType	decimal	23	8	0	NO	0	
total_amt	dbo	ue_SMK_RSC_POS_RawLine_mst	AmountType	decimal	23	8	0	NO	0	
item	dbo	ue_SMK_RSC_POS_RawLine_mst	ItemType	nvarchar	30			YES	0	
syteline_qty	dbo	ue_SMK_RSC_POS_RawLine_mst	QtyUnitType	decimal	23	8		YES	0	
u_m	dbo	ue_SMK_RSC_POS_RawLine_mst	UMType	nvarchar	3			YES	0	
stat	dbo	ue_SMK_RSC_POS_RawLine_mst	nchar	nchar	1		N'N'	NO	0	
validation_msg	dbo	ue_SMK_RSC_POS_RawLine_mst	nvarchar	nvarchar	1000			YES	0	
error_msg	dbo	ue_SMK_RSC_POS_RawLine_mst	nvarchar	nvarchar	4000			YES	0	
process_date	dbo	ue_SMK_RSC_POS_RawLine_mst	DateType	datetime				YES	0	
syteline_ref	dbo	ue_SMK_RSC_POS_RawLine_mst	nvarchar	nvarchar	50			YES	0	
CreateDate	dbo	ue_SMK_RSC_POS_RawLine_mst	CurrentDateType	datetime			getdate()	NO	0	
CreatedBy	dbo	ue_SMK_RSC_POS_RawLine_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
InWorkflow	dbo	ue_SMK_RSC_POS_RawLine_mst	FlagNyType	tinyint			0	NO	0	
NoteExistsFlag	dbo	ue_SMK_RSC_POS_RawLine_mst	FlagNyType	tinyint			0	NO	0	
RecordDate	dbo	ue_SMK_RSC_POS_RawLine_mst	CurrentDateType	datetime			getdate()	NO	0	
RowPointer	dbo	ue_SMK_RSC_POS_RawLine_mst	RowPointerType	uniqueidentifier			newid()	NO	0	
SiteRef	dbo	ue_SMK_RSC_POS_RawLine_mst	SiteType	nvarchar	8		rtrim(CONVERT([nvarchar](8),context_info(),(0)))	NO	0	
UpdatedBy	dbo	ue_SMK_RSC_POS_RawLine_mst	UsernameType	nvarchar	128		suser_sname()	NO	0	
```

## Source Fields vs Mapping Results

Source fields yang tidak boleh ditimpa:

```text
business_date
trans_num
pos_item_code
pos_qty
total_amt
```

Hasil mapping:

```text
item
syteline_qty
u_m
```

Formula quantity hasil mapping:

```text
syteline_qty = pos_qty × qty_conv_factor
```

Faktor konversi berasal dari `SMK_RSC_POS_ItemMap_mst` bila tabel mapping tersebut digunakan.

## Derived Transaction Header

Transaction header dapat dibentuk atau direkap dari flat rows:

```sql
SELECT
    business_date,
    trans_num,
    COUNT(*) AS line_count,
    SUM(total_amt) AS transaction_total
FROM dbo.ue_SMK_RSC_POS_RawLine_mst
WHERE batch_num = @BatchNum
GROUP BY business_date, trans_num;
```

Karena itu, source minimal tidak harus langsung memiliki tabel transaction header terpisah. Namun tabel header tetap dapat dibentuk kemudian bila diperlukan oleh form, audit, atau posting flow.

## Status

| Value | Meaning |
|---|---|
| `N` | New/unvalidated |
| `V` | Validated and mapped |
| `P` | Processed/used for preview or posting |
| `E` | Error |
| `C` | Cancelled/ignored |

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_RawLine_01
SiteRef, batch_num, source_row_num

IX_ue_SMK_RSC_POS_RawLine_02
SiteRef, batch_num, business_date, trans_num

IX_ue_SMK_RSC_POS_RawLine_03
SiteRef, pos_item_code, stat

IX_ue_SMK_RSC_POS_RawLine_04
SiteRef, item, stat
```

## Validation Rules

- Parent `batch_num` harus tersedia.
- `source_row_num > 0` dan unik dalam batch.
- `business_date`, `trans_num`, dan `pos_item_code` wajib.
- Quantity dan total tidak otomatis diwajibkan positif karena refund/return dapat memakai nilai negatif; aturan final mengikuti source specification.
- Item mapping harus menghasilkan tepat satu mapping aktif bila mapping item diwajibkan.
- `syteline_qty` tidak boleh menimpa `pos_qty`.
- Total per transaction adalah `SUM(total_amt)` dari seluruh rows dengan `business_date + trans_num` yang sama.
- `COUNT(DISTINCT business_date + trans_num)` digunakan sebagai jumlah transaksi, bukan jumlah raw rows.
- Baris error tidak boleh diproses ke posting preview.
- Baris yang sudah diproses tidak boleh diposting ulang tanpa kontrol retry/rebuild.

## Minimal Example

```text
batch_num      : SMKPOS-20260723-000001
source_row_num : 1
business_date  : 2026-07-23
trans_num      : TRX0001
pos_item_code  : PIZZA001
pos_qty        : 2
total_amt      : 200000
item           : FG-PIZZA-00001
syteline_qty   : 2
u_m            : EA
stat           : V
```

## Important Limitation

Dengan hanya lima source fields, sistem belum mengetahui secara langsung:

- outlet/site bila tidak tersedia pada batch metadata;
- metode pembayaran;
- pajak;
- diskon;
- service charge;
- void/refund indicator;
- settlement aggregator;
- currency bila tidak tersedia pada metadata/default.

Kekurangan tersebut tidak boleh diisi dengan asumsi tersembunyi. Nilai harus berasal dari batch metadata, mapping yang disetujui, default resmi, atau suspense/exception process.