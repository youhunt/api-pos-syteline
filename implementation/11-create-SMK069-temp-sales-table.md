# Implementation 11 — Create `SMK069_temp_sales_mst`

## Scope

This step creates only the staging table required by the SMK sales integration specification. Do not create the IDO or form in this step.

## Object Identity

```text
Metadata Table Name : SMK069_temp_sales_mst
Physical SQL Table  : dbo.ue_SMK069_temp_sales_mst
Purpose             : POS sales staging and error reprocessing source
```

The `ue_` prefix is expected to be applied by the tenant Access As configuration to the physical SQL table. Do not enter a double prefix.

## Primary Key

```text
1. site_ref
2. co_num
3. co_line
```

This composite key is a technical design decision because the source specification did not define a primary key.

## Business Columns from the Specification

Create these columns first:

| Sequence | Column | Application Data Type | Physical Type | Nullable | Default |
| ---: | --- | --- | --- | --- | --- |
| 1 | `site_ref` | `SiteType` | `nvarchar(8)` | NO | |
| 2 | `cust_num` | `CustNumType` | `nvarchar(7)` | YES | |
| 3 | `order_date` | `DateType` | `datetime` | YES | |
| 4 | `terms_code` | `nvarchar(3)` | `nvarchar(3)` | YES | |
| 5 | `co_num` | `CoNumType` | `nvarchar(10)` | NO | |
| 6 | `co_line` | `CoLineType` | `smallint` | NO | |
| 7 | `cost` | `CostPrcType` | `decimal(20,8)` | YES | `0` |
| 8 | `unit_price` | `CostPrcType` | `decimal(20,8)` | YES | `0` |
| 9 | `tax_code1` | `nvarchar(6)` | `nvarchar(6)` | YES | |
| 10 | `exch_rate` | `decimal(20,8)` | `decimal(20,8)` | YES | `1` |
| 11 | `whse` | `WhseType` | `nvarchar(4)` | YES | |
| 12 | `item` | `ItemType` | `nvarchar(30)` | YES | |
| 13 | `qty_ordered` | `QtyUnitType` | `decimal(23,8)` | YES | `0` |
| 14 | `due_date` | `DateType` | `datetime` | YES | |
| 15 | `u_m` | `UMType` | `nvarchar(3)` | YES | |

## Technical Control Columns

These columns are not explicitly listed in the source specification, but are required to implement preview, error control, retry, and audit:

| Sequence | Column | Application Data Type | Physical Type | Nullable | Default |
| ---: | --- | --- | --- | --- | --- |
| 16 | `request_id` | `nvarchar(50)` | `nvarchar(50)` | YES | |
| 17 | `batch_num` | `nvarchar(30)` | `nvarchar(30)` | YES | |
| 18 | `process_status` | `nchar(1)` | `nchar(1)` | NO | `N'N'` |
| 19 | `validation_msg` | `nvarchar(1000)` | `nvarchar(1000)` | YES | |
| 20 | `error_msg` | `nvarchar(4000)` | `nvarchar(4000)` | YES | |
| 21 | `retry_count` | `int` | `int` | NO | `0` |
| 22 | `last_process_date` | `DateType` | `datetime` | YES | |
| 23 | `processed_by` | `UsernameType` | `nvarchar(128)` | YES | |

## Standard Mongoose Columns

Add the tenant standard framework columns:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
SiteRef
UpdatedBy
```

Use the standard defaults already used by the other project tables.

## Important Naming Note

The source specification contains a business field named:

```text
site_ref
```

The Mongoose framework also adds:

```text
SiteRef
```

They are different columns:

```text
site_ref = target/business site received from integration
SiteRef  = framework site context for the physical Mongoose row
```

For the current single-site implementation they should normally contain the same site value. Do not remove either field during this implementation step.

## Why Business Fields Are Nullable

The table is intended to retain invalid integration records for the Error Processing UI. If `cust_num`, `order_date`, or another source value is missing, the row should still be stored and marked as error instead of being rejected by the database before it can be reviewed.

Only the composite key is mandatory at database level.

## Creation Steps

1. Open `SQL Tables` or the tenant table-definition form.
2. Create table metadata named `SMK069_temp_sales_mst`.
3. Verify the physical table preview becomes `ue_SMK069_temp_sales_mst`.
4. Add the 15 source business columns.
5. Add the 8 technical control columns.
6. Add all standard Mongoose columns.
7. Set the primary key sequence:

```text
site_ref = 1
co_num   = 2
co_line  = 3
```

8. Save and create the table.
9. Confirm the physical table exists as:

```text
dbo.ue_SMK069_temp_sales_mst
```

## Smoke Check

After creation, verify the table metadata contains at least:

```text
site_ref
cust_num
order_date
co_num
co_line
unit_price
qty_ordered
process_status
error_msg
retry_count
RowPointer
SiteRef
```

No data insert is required yet.

## Stop Point

Stop after the table is successfully created. The next step will create the entity IDO for this table.
