# SMK_RSC_POS_TranLine_mst

## Identity

```text
Metadata object : SMK_RSC_POS_TranLine_mst
Physical table  : dbo.ue_SMK_RSC_POS_TranLine_mst
Purpose         : Detail item dan quantity per transaksi
```

## Primary Key

```text
batch_num + trans_num + line_num
```

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `batch_num` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 30 |  |  | NO | 1 | 1 |
| `trans_num` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 50 |  |  | NO | 1 | 2 |
| `line_num` | dbo | ue_SMK_RSC_POS_TranLine_mst | int | int |  |  |  | NO | 1 | 3 |
| `parent_line_num` | dbo | ue_SMK_RSC_POS_TranLine_mst | int | int |  |  |  | YES | 0 |  |
| `pos_item_code` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 50 |  |  | NO | 0 |  |
| `item` | dbo | ue_SMK_RSC_POS_TranLine_mst | ItemType | nvarchar | 30 |  |  | YES | 0 |  |
| `item_desc` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 200 |  |  | YES | 0 |  |
| `line_type` | dbo | ue_SMK_RSC_POS_TranLine_mst | nchar | nchar | 1 |  | `N'I'` | NO | 0 |  |
| `qty` | dbo | ue_SMK_RSC_POS_TranLine_mst | QtyUnitType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `u_m` | dbo | ue_SMK_RSC_POS_TranLine_mst | UMType | nvarchar | 3 |  |  | YES | 0 |  |
| `unit_price` | dbo | ue_SMK_RSC_POS_TranLine_mst | CostPrcType | decimal | 20 | 8 | `0` | NO | 0 |  |
| `gross_amt` | dbo | ue_SMK_RSC_POS_TranLine_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `discount_amt` | dbo | ue_SMK_RSC_POS_TranLine_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `tax_amt` | dbo | ue_SMK_RSC_POS_TranLine_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `service_amt` | dbo | ue_SMK_RSC_POS_TranLine_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `net_amt` | dbo | ue_SMK_RSC_POS_TranLine_mst | AmountType | decimal | 23 | 8 | `0` | NO | 0 |  |
| `tax_code` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 20 |  |  | YES | 0 |  |
| `promo_code` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `void_flag` | dbo | ue_SMK_RSC_POS_TranLine_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `stat` | dbo | ue_SMK_RSC_POS_TranLine_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `syteline_ref` | dbo | ue_SMK_RSC_POS_TranLine_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `process_date` | dbo | ue_SMK_RSC_POS_TranLine_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_TranLine_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_TranLine_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_TranLine_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_TranLine_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_TranLine_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_TranLine_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_TranLine_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_TranLine_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Important Design Note

Sebelum inventory processing final, pertimbangkan memisahkan:

```text
pos_qty       = quantity asli POS
syteline_qty  = quantity setelah konversi
pos_u_m       = U/M asli POS
u_m           = U/M SyteLine
```

Data sumber tidak boleh ditimpa oleh hasil mapping.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_TranLine_01
SiteRef, batch_num, trans_num

IX_ue_SMK_RSC_POS_TranLine_02
SiteRef, pos_item_code, stat

IX_ue_SMK_RSC_POS_TranLine_03
SiteRef, item
```

## Validation Rules

- Parent transaction harus ada.
- `line_num > 0`.
- `parent_line_num` harus menunjuk line valid bila terisi.
- `pos_item_code` wajib.
- Mapping item harus aktif dan berlaku pada business date.
- `gross_amt` dibandingkan dengan `qty × unit_price` sesuai aturan rounding.
- `net_amt` dibandingkan dengan gross, discount, tax, dan service.
- Void line diperlakukan sesuai spesifikasi resmi source.

## Example

```text
batch_num       : SMKPOS-20260723-000001
trans_num       : TRX-PH001-00001234
line_num        : 1
pos_item_code   : PIZZA-SUPREME-L
item            : FG-PIZZA-00001
line_type       : I
qty             : 1
u_m             : EA
unit_price      : 150000
net_amt         : 148500
stat            : V
```
