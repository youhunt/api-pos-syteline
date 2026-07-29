# SMK069_temp_sales_mst

## Identity

```text
Metadata object : SMK069_temp_sales_mst
Physical table  : dbo.ue_SMK069_temp_sales_mst
Purpose         : Menampung data sales dari CSV/POS sebelum divalidasi dan diproses menjadi Customer Order header dan Customer Order lines.
```

## Design Decisions

1. Satu record staging merepresentasikan satu Customer Order line.
2. Satu `SiteRef + co_num` membentuk satu Customer Order header.
3. Kolom `cost` dihapus berdasarkan revisi functional; cost diambil dari `item_mst` saat posting.
4. Total order dihitung dengan `SUM(unit_price * qty_ordered)`.
5. Standard Mongoose `SiteRef` digunakan sebagai field `site_ref` dari spesifikasi. Jangan membuat kolom `site_ref` kedua karena SQL Server umumnya case-insensitive.
6. Enam kolom kontrol ditambahkan untuk mendukung preview, validasi, error processing, retry, dan audit.

## Primary Key

```text
SiteRef + co_num + co_line
```

Spesifikasi sumber tidak menetapkan primary key. Composite key tersebut adalah keputusan teknis fase pertama untuk mencegah duplikasi line pada Customer Order yang sama.

## Struktur kolom

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `SiteRef` | dbo | ue_SMK069_temp_sales_mst | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 1 | 1 |
| `cust_num` | dbo | ue_SMK069_temp_sales_mst | CustNumType | nvarchar | 7 |  |  | YES | 0 |  |
| `order_date` | dbo | ue_SMK069_temp_sales_mst | DateType | datetime |  |  |  | YES | 0 |  |
| `terms_code` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 3 |  |  | YES | 0 |  |
| `co_num` | dbo | ue_SMK069_temp_sales_mst | CoNumType | nvarchar | 10 |  |  | NO | 1 | 2 |
| `co_line` | dbo | ue_SMK069_temp_sales_mst | CoLineType | smallint |  |  |  | NO | 1 | 3 |
| `unit_price` | dbo | ue_SMK069_temp_sales_mst | CostPrcType | decimal | 20 | 8 | `0` | YES | 0 |  |
| `tax_code1` | dbo | ue_SMK069_temp_sales_mst | nvarchar | nvarchar | 6 |  |  | YES | 0 |  |
| `exch_rate` | dbo | ue_SMK069_temp_sales_mst | decimal | decimal | 20 | 8 | `1` | YES | 0 |  |
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
| `E` | Error / gagal validasi atau posting |
| `P` | Processed / Customer Order berhasil dibuat |
| `C` | Cancelled |

## Initial Validation Scope

Validasi wajib fase pertama sesuai spesifikasi:

```text
cust_num harus ditemukan pada customer_mst
```

Validasi tambahan dapat ditambahkan bertahap setelah format CSV dan contoh data final diterima.
