# SMK_RSC_POS_OutletMap_mst

## Identity

```text
Metadata object : SMK_RSC_POS_OutletMap_mst
Physical table  : dbo.ue_SMK_RSC_POS_OutletMap_mst
Purpose         : Mapping outlet POS ke site, warehouse, customer, currency, dan unit code SyteLine
```

## Primary Key

```text
source_system + outlet_code
```

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `source_system` | `nvarchar(30)` | No | `N'POS'` | Sistem sumber |
| `outlet_code` | `nvarchar(20)` | No |  | Kode outlet POS |
| `outlet_name` | `nvarchar(100)` | Yes |  | Nama outlet |
| `target_site` | `SiteType` | No |  | Site tujuan hasil mapping |
| `whse` | `WhseType` | Yes |  | Warehouse default |
| `cust_num` | `CustNumType` | Yes |  | Customer/walk-in customer default |
| `currency_code` | `CurrCodeType` | No | `N'IDR'` | Currency default |
| `unit_code1` | `UnitCode1Type` | Yes |  | Unit code 1 |
| `unit_code2` | `UnitCode2Type` | Yes |  | Unit code 2 |
| `unit_code3` | `UnitCode3Type` | Yes |  | Unit code 3 |
| `unit_code4` | `UnitCode4Type` | Yes |  | Unit code 4 |
| `active_flag` | `FlagNyType` | No | `1` | Mapping aktif |
| `effective_date` | `DateType` | No | `getdate()` | Mulai berlaku |
| `expiration_date` | `DateType` | Yes |  | Akhir berlaku |
| `notes` | `nvarchar(1000)` | Yes |  | Catatan |

## SiteRef vs target_site

```text
SiteRef     = site owner record menurut framework Mongoose
target_site = site tujuan mapping outlet
```

Keduanya dapat sama pada single-site setup, tetapi secara semantik berbeda.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_OutletMap_01
SiteRef, active_flag, source_system, outlet_code

IX_ue_SMK_RSC_POS_OutletMap_02
SiteRef, target_site, whse

IX_ue_SMK_RSC_POS_OutletMap_03
SiteRef, effective_date, expiration_date
```

## Lookup Rule

```sql
WHERE source_system = @SourceSystem
  AND outlet_code = @OutletCode
  AND active_flag = 1
  AND effective_date <= @BusinessDate
  AND (expiration_date IS NULL OR expiration_date >= @BusinessDate)
```

## Validation Rules

- Mapping aktif harus tepat satu.
- `target_site` harus valid.
- Warehouse wajib bila flow inventory memerlukannya.
- Customer wajib bila flow AR/order memerlukannya.
- Currency dan unit codes harus valid sesuai target account/site.
- Masa berlaku tidak boleh tumpang tindih jika histori mapping diaktifkan.

## Example

```text
source_system : PIZZAHUT_POS
outlet_code   : PH-SBY-001
outlet_name   : Pizza Hut Surabaya 1
target_site   : SBY
whse          : PH01
cust_num      : POSCASH
currency_code : IDR
unit_code1    : S001
active_flag   : 1
```
