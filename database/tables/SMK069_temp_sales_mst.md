# SMK069_temp_sales_mst

## Identity

```text
Metadata object : SMK069_temp_sales_mst
Physical table  : dbo.ue_SMK069_temp_sales_mst
Purpose         : Menampung data sales dari file CSV sebelum divalidasi dan diproses menjadi Customer Order header dan Customer Order lines.
Current status  : Table created; IDO created and updated; base form created; smoke test pending.
```

## Confirmed Requirement Revisions

Two corrections were confirmed on 28 July 2026:

```text
1. Header total = SUM(unit_price * qty_ordered)
2. cost is not stored in this staging table; cost is obtained from item_mst during Customer Order processing
```

Therefore, the `cost` column from the original specification is intentionally omitted from the implemented table.

## Row Meaning

One staging row represents one Customer Order line.

Example:

```text
PG | CO0001 | 1 | ITEM-A
PG | CO0001 | 2 | ITEM-B
PG | CO0001 | 3 | ITEM-C
```

The intended result is one Customer Order header and three Customer Order lines.

## Primary Key

```text
SiteRef + co_num + co_line
```

The source specification did not define a primary key. This composite key is the current technical decision to prevent the same Customer Order line from being stored twice for the same site.

## Important Site Column Decision

The source specification calls the field `site_ref`. Mongoose already provides the standard multi-site column `SiteRef`. SQL Server normally treats these names as identical in a case-insensitive database, so a second `site_ref` column must not be created.

The standard `SiteRef` column therefore fulfills both purposes:

```text
- source/target site required by the specification
- Mongoose framework site context
```

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `SiteRef` | dbo | ue_SMK069_temp_sales_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 1 | 0 |
| `cust_num` | dbo | ue_SMK069_temp_sales_mst | CustNumType | nvarchar | 7 |  |  | YES | 0 |  |
| `order_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `terms_code` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 3 |  |  | YES | 0 |  |
| `co_num` | dbo | ue_SMK069_temp_sales_mst | CoNumType | nvarchar | 10 |  |  | NO | 1 | 1 |
| `co_line` | dbo | ue_SMK069_temp_sales_mst | CoLineType | smallint |  |  |  | NO | 1 | 2 |
| `unit_price` | dbo | ue_SMK069_temp_sales_mst | CostPrcType | decimal | 20 | 8 | `0` | YES | 0 |  |
| `tax_code1` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 6 |  |  | YES | 0 |  |
| `exch_rate` | dbo | ue_SMK069_temp_sales_mst | decimal | decimal |  |  | `1` | YES | 0 |  |
| `whse` | dbo | ue_SMK069_temp_sales_mst | WhseType | nvarchar | 4 |  |  | YES | 0 |  |
| `item` | dbo | ue_SMK069_temp_sales_mst | ItemType | nvarchar | 30 |  |  | YES | 0 |  |
| `qty_ordered` | dbo | ue_SMK069_temp_sales_mst | QtyUnitType | decimal | 23 | 8 | `0` | YES | 0 |  |
| `due_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `u_m` | dbo | ue_SMK069_temp_sales_mst | UMType | nvarchar | 3 |  |  | YES | 0 |  |
| `process_status` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `retry_count` | dbo | ue_SMK069_temp_sales_mst | int | int |  |  | `0` | NO | 0 |  |
| `processed_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `processed_by` | dbo | ue_SMK069_temp_sales_mst | UsernameType | nvarchar | 128 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK069_temp_sales_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK069_temp_sales_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK069_temp_sales_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK069_temp_sales_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK069_temp_sales_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK069_temp_sales_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK069_temp_sales_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Process Status

| Value | Meaning |
| --- | --- |
| `N` | New / belum divalidasi |
| `V` | Valid / siap diproses |
| `E` | Error validasi atau posting |
| `P` | Processed / Customer Order berhasil dibuat |
| `C` | Cancelled |

## Technical Control Fields

The following six fields are technical additions needed to support the Error Processing UI:

```text
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

They are maintained by validation and processing logic, not manually by the user.

## Initial Validation Scope

The minimum validation explicitly requested in the source specification is:

```text
cust_num must exist in customer_mst
```

Additional item, warehouse, U/M, terms, tax, date, and quantity validation will be added in later development steps.

## Current Implementation Status

```text
[COMPLETED] SQL table created
[COMPLETED] six technical process-control columns added
[COMPLETED] entity IDO ue_SMK069TempSales created
[COMPLETED] IDO updated/resynchronized after table changes
[COMPLETED] base form object ue_SMK069APISalesErrorProcessing created
[IN PROGRESS] base-form smoke test and read-only verification
[PENDING]   Preview filter event
[PENDING]   customer validation
[PENDING]   Process/reprocess method
[PENDING]   Customer Order header and line creation
```

The form object must not be marked fully completed until it opens successfully and the required grid properties and read-only behavior are verified in the tenant.

## Tenant Verification

Verify the actual application data type definitions in the target tenant, especially:

```text
CoLineType
CostPrcType
QtyUnitType
exchange-rate decimal precision
```

The tenant metadata is the source of truth for physical precision and scale.