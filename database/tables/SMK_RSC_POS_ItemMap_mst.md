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

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `source_system` | `nvarchar(30)` | No | `N'POS'` | Sistem sumber |
| `target_site` | `SiteType` | No |  | Site target |
| `pos_item_code` | `nvarchar(50)` | No |  | Kode item asli POS |
| `pos_item_desc` | `nvarchar(200)` | Yes |  | Deskripsi item POS |
| `pos_category` | `nvarchar(30)` | Yes |  | Kategori item POS |
| `item` | `ItemType` | No |  | Item SyteLine hasil mapping |
| `pos_u_m` | `nvarchar(10)` | Yes |  | U/M sumber |
| `u_m` | `UMType` | Yes |  | U/M SyteLine |
| `qty_conv_factor` | `QtyUnitType` | No | `1` | Faktor konversi quantity |
| `inventory_flag` | `FlagNyType` | No | `1` | Relevan terhadap inventory |
| `active_flag` | `FlagNyType` | No | `1` | Mapping aktif |
| `effective_date` | `DateType` | No | `getdate()` | Mulai berlaku |
| `expiration_date` | `DateType` | Yes |  | Akhir berlaku |
| `notes` | `nvarchar(1000)` | Yes |  | Catatan |

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
