# SMK_RSC_POS_ItemMap_mst

## Identity

```text
Metadata object : SMK_RSC_POS_ItemMap_mst
Physical table  : dbo.ue_SMK_RSC_POS_ItemMap_mst
Purpose         : Mapping kode item dan U/M POS ke item SyteLine
```

## Primary Key

```text
source_system + target_site + pos_item_code
```

Item POS yang sama dapat dipetakan berbeda pada site berbeda.

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `source_system` | dbo | ue_SMK_RSC_POS_ItemMap_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 1 | 1 |
| `target_site` | dbo | ue_SMK_RSC_POS_ItemMap_mst | SiteType | nvarchar | 8 |  |  | NO | 1 | 2 |
| `pos_item_code` | dbo | ue_SMK_RSC_POS_ItemMap_mst | nvarchar | nvarchar | 50 |  |  | NO | 1 | 3 |
| `pos_item_desc` | dbo | ue_SMK_RSC_POS_ItemMap_mst | nvarchar | nvarchar | 200 |  |  | YES | 0 |  |
| `pos_category` | dbo | ue_SMK_RSC_POS_ItemMap_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `item` | dbo | ue_SMK_RSC_POS_ItemMap_mst | ItemType | nvarchar | 30 |  |  | NO | 0 |  |
| `pos_u_m` | dbo | ue_SMK_RSC_POS_ItemMap_mst | nvarchar | nvarchar | 10 |  |  | YES | 0 |  |
| `u_m` | dbo | ue_SMK_RSC_POS_ItemMap_mst | UMType | nvarchar | 3 |  |  | YES | 0 |  |
| `qty_conv_factor` | dbo | ue_SMK_RSC_POS_ItemMap_mst | QtyUnitType | decimal | 23 | 8 | `1` | NO | 0 |  |
| `inventory_flag` | dbo | ue_SMK_RSC_POS_ItemMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `active_flag` | dbo | ue_SMK_RSC_POS_ItemMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `effective_date` | dbo | ue_SMK_RSC_POS_ItemMap_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `expiration_date` | dbo | ue_SMK_RSC_POS_ItemMap_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `notes` | dbo | ue_SMK_RSC_POS_ItemMap_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_ItemMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_ItemMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_ItemMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_ItemMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_ItemMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_ItemMap_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_ItemMap_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_ItemMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Quantity Conversion

```text
syteline_qty = pos_qty × qty_conv_factor
```

Contoh:

```text
POS U/M        : BOX
SyteLine U/M   : EA
Conversion     : 6
POS Qty        : 2
SyteLine Qty   : 12
```

Jangan menimpa quantity asli POS. Jika inventory flow diaktifkan, tambahkan kolom terpisah pada transaction line untuk source dan converted quantity.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_ItemMap_01
SiteRef, source_system, target_site, active_flag, pos_item_code

IX_ue_SMK_RSC_POS_ItemMap_02
SiteRef, target_site, item

IX_ue_SMK_RSC_POS_ItemMap_03
SiteRef, pos_category, active_flag
```

## Lookup Rule

```sql
WHERE source_system = @SourceSystem
  AND target_site = @TargetSite
  AND pos_item_code = @PosItemCode
  AND active_flag = 1
  AND effective_date <= @BusinessDate
  AND (expiration_date IS NULL OR expiration_date >= @BusinessDate)
```

## Validation Rules

- Mapping aktif harus tepat satu.
- Item harus tersedia dan valid pada target site.
- `qty_conv_factor > 0`.
- U/M harus valid dan compatible dengan item.
- Masa berlaku mapping mengikuti business date.
- `inventory_flag` tidak menggantikan validasi item master.

## Example

```text
source_system  : PIZZAHUT_POS
target_site    : SBY
pos_item_code  : PIZZA-SUPREME-L
pos_item_desc  : Super Supreme Large
pos_category   : PIZZA
item           : FG-PIZZA-00001
pos_u_m        : PCS
u_m            : EA
qty_conv_factor: 1
inventory_flag : 1
active_flag    : 1
```
