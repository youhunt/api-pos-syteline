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

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `source_system` | dbo | ue_SMK_RSC_POS_OutletMap_mst | nvarchar | nvarchar | 30 |  | `N'POS'` | NO | 1 | 1 |
| `outlet_code` | dbo | ue_SMK_RSC_POS_OutletMap_mst | nvarchar | nvarchar | 20 |  |  | NO | 1 | 2 |
| `outlet_name` | dbo | ue_SMK_RSC_POS_OutletMap_mst | nvarchar | nvarchar | 100 |  |  | YES | 0 |  |
| `target_site` | dbo | ue_SMK_RSC_POS_OutletMap_mst | SiteType | nvarchar | 8 |  |  | NO | 0 |  |
| `whse` | dbo | ue_SMK_RSC_POS_OutletMap_mst | WhseType | nvarchar | 4 |  |  | YES | 0 |  |
| `cust_num` | dbo | ue_SMK_RSC_POS_OutletMap_mst | CustNumType | nvarchar | 7 |  |  | YES | 0 |  |
| `currency_code` | dbo | ue_SMK_RSC_POS_OutletMap_mst | CurrCodeType | nvarchar | 3 |  | `N'IDR'` | NO | 0 |  |
| `unit_code1` | dbo | ue_SMK_RSC_POS_OutletMap_mst | UnitCode1Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code2` | dbo | ue_SMK_RSC_POS_OutletMap_mst | UnitCode2Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code3` | dbo | ue_SMK_RSC_POS_OutletMap_mst | UnitCode3Type | nvarchar | 4 |  |  | YES | 0 |  |
| `unit_code4` | dbo | ue_SMK_RSC_POS_OutletMap_mst | UnitCode4Type | nvarchar | 4 |  |  | YES | 0 |  |
| `active_flag` | dbo | ue_SMK_RSC_POS_OutletMap_mst | FlagNyType | tinyint |  |  | `1` | NO | 0 |  |
| `effective_date` | dbo | ue_SMK_RSC_POS_OutletMap_mst | DateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `expiration_date` | dbo | ue_SMK_RSC_POS_OutletMap_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `notes` | dbo | ue_SMK_RSC_POS_OutletMap_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK_RSC_POS_OutletMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK_RSC_POS_OutletMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK_RSC_POS_OutletMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK_RSC_POS_OutletMap_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK_RSC_POS_OutletMap_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK_RSC_POS_OutletMap_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK_RSC_POS_OutletMap_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK_RSC_POS_OutletMap_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

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
