# SMK069_temp_sales_mst

## Identity

```text
Metadata object : SMK069_temp_sales_mst
Physical table  : dbo.ue_SMK069_temp_sales_mst
Purpose         : Menampung data sales hasil integrasi Pizza Hut POS sebelum divalidasi dan diproses menjadi Customer Order header dan Customer Order lines.
Status          : Approved design for implementation based on SMK specification dated 20 July 2026.
```

## Source Versus Technical Additions

Kolom bisnis berikut berasal dari spesifikasi SMK:

```text
site_ref
cust_num
order_date
terms_code
co_num
co_line
cost
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
```

Kolom kontrol berikut adalah tambahan teknis agar kebutuhan **SMK API SALES ERROR PROCESSING**, preview, retry, audit, dan reprocessing dapat dijalankan:

```text
request_id
batch_num
process_status
validation_msg
error_msg
retry_count
last_process_date
processed_by
```

## Primary Key

```text
site_ref + co_num + co_line
```

Spesifikasi sumber tidak menetapkan primary key. Composite key di atas adalah keputusan desain teknis karena satu record staging merepresentasikan satu Customer Order line pada satu site.

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `site_ref` | dbo | ue_SMK069_temp_sales_mst | SiteType | nvarchar | 8 |  |  | NO | 1 | 1 |
| `cust_num` | dbo | ue_SMK069_temp_sales_mst | CustNumType | nvarchar | 7 |  |  | YES | 0 |  |
| `order_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `terms_code` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 3 |  |  | YES | 0 |  |
| `co_num` | dbo | ue_SMK069_temp_sales_mst | CoNumType | nvarchar | 10 |  |  | NO | 1 | 2 |
| `co_line` | dbo | ue_SMK069_temp_sales_mst | CoLineType | smallint |  |  |  | NO | 1 | 3 |
| `cost` | dbo | ue_SMK069_temp_sales_mst | CostPrcType | decimal | 20 | 8 | `0` | YES | 0 |  |
| `unit_price` | dbo | ue_SMK069_temp_sales_mst | CostPrcType | decimal | 20 | 8 | `0` | YES | 0 |  |
| `tax_code1` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 6 |  |  | YES | 0 |  |
| `exch_rate` | dbo | ue_SMK069_temp_sales_mst | decimal | decimal | 20 | 8 | `1` | YES | 0 |  |
| `whse` | dbo | ue_SMK069_temp_sales_mst | WhseType | nvarchar | 4 |  |  | YES | 0 |  |
| `item` | dbo | ue_SMK069_temp_sales_mst | ItemType | nvarchar | 30 |  |  | YES | 0 |  |
| `qty_ordered` | dbo | ue_SMK069_temp_sales_mst | QtyUnitType | decimal | 23 | 8 | `0` | YES | 0 |  |
| `due_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `u_m` | dbo | ue_SMK069_temp_sales_mst | UMType | nvarchar | 3 |  |  | YES | 0 |  |
| `request_id` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 50 |  |  | YES | 0 |  |
| `batch_num` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 30 |  |  | YES | 0 |  |
| `process_status` | dbo | ue_SMK069_temp_sales_mst | nchar | nchar | 1 |  | `N'N'` | NO | 0 |  |
| `validation_msg` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 1000 |  |  | YES | 0 |  |
| `error_msg` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 4000 |  |  | YES | 0 |  |
| `retry_count` | dbo | ue_SMK069_temp_sales_mst | int | int |  |  | `0` | NO | 0 |  |
| `last_process_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `processed_by` | dbo | ue_SMK069_temp_sales_mst | UsernameType | nvarchar | 128 |  |  | YES | 0 |  |
| `CreateDate` | dbo | ue_SMK069_temp_sales_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_SMK069_temp_sales_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_SMK069_temp_sales_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_SMK069_temp_sales_mst | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_SMK069_temp_sales_mst | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_SMK069_temp_sales_mst | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_SMK069_temp_sales_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_SMK069_temp_sales_mst | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Why Most Business Fields Are Nullable

Tabel ini adalah staging/error-processing table. Data yang tidak lengkap tetap perlu disimpan agar dapat terlihat pada UI error processing. Karena itu hanya kolom key dan framework yang diwajibkan pada level database. Validasi bisnis dilakukan oleh service method dan status error disimpan pada `process_status`, `validation_msg`, dan `error_msg`.

## Process Status

| Value | Meaning |
| --- | --- |
| `N` | New / belum divalidasi |
| `V` | Valid / siap diproses |
| `E` | Error / gagal validasi atau posting |
| `P` | Processed / Customer Order berhasil dibuat |
| `C` | Cancelled |

## Candidate Indexes

```text
IX_ue_SMK069_temp_sales_mst_OrderDate
order_date, co_num
```

```text
IX_ue_SMK069_temp_sales_mst_Status
process_status, order_date, co_num
```

```text
IX_ue_SMK069_temp_sales_mst_Request
request_id, batch_num
```

## Initial Validation Scope

Untuk fase pertama, validasi yang diwajibkan oleh spesifikasi adalah:

```text
cust_num harus ditemukan pada customer_mst
```

Validasi item, warehouse, U/M, tax, dan aturan lanjutan ditunda sesuai keputusan development saat ini.

## Example

```text
site_ref         : PG
cust_num         : C000005
order_date       : 2026-07-20
terms_code       : N30
co_num           : CO0001
co_line          : 1
cost             : 760000
unit_price       : 760000
tax_code1        : NPPN
exch_rate        : 1
whse             : MAIN
item             : AA00007
qty_ordered      : 360
due_date         : 2026-07-25
u_m              : CTN
process_status   : N
retry_count      : 0
```

## Tenant Verification

Before final creation, verify these application data types in the target tenant dropdown:

```text
CoNumType
CoLineType
CostPrcType
QtyUnitType
```

If a listed UDDT is unavailable, use the documented physical SQL type and length without changing the source field meaning.
