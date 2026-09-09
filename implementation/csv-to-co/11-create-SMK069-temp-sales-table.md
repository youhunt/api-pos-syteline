# Implementation 11 — Create `SMK069_temp_sales_mst`

## Scope

This step creates the staging table required by the SMK sales integration specification and adds the process-control columns needed by the Error Processing UI.

## Object Identity

```text
Metadata Table Name : SMK069_temp_sales_mst
Physical SQL Table  : dbo.ue_SMK069_temp_sales_mst
Purpose             : CSV sales staging and Customer Order error reprocessing source
```

The `ue_` prefix is applied to the physical object by the tenant. Use `SMK069_temp_sales_mst` in SQL Tables metadata and verify the resulting physical table becomes `dbo.ue_SMK069_temp_sales_mst`.

## Confirmed Requirement Revisions

The following corrections were confirmed on 28 July 2026:

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

Therefore:

```text
- do not create the cost column in SMK069_temp_sales_mst
- unit_price remains the sales price received from the source CSV
- item cost will be read during Customer Order processing
```

## Site Column

Do not create both `site_ref` and `SiteRef`.

The source specification requires `site_ref`, while Mongoose already provides the standard multi-site column `SiteRef`. Because SQL Server normally uses case-insensitive object names, the standard `SiteRef` column is used to satisfy the source requirement and framework requirement together.

## Primary Key

```text
SiteRef + co_num + co_line
```

Key sequence:

```text
SiteRef = 0
co_num  = 1
co_line = 2
```

This is a technical decision because the source specification did not define a primary key.

## Business Columns

| Sequence | Column | Application Data Type | Physical Type | Nullable | Default |
| ---: | --- | --- | --- | --- | --- |
| 1 | `SiteRef` | `SiteType` | `nvarchar(8)` | NO | standard site-context expression |
| 2 | `cust_num` | `CustNumType` | `nvarchar(7)` | YES | |
| 3 | `order_date` | `DateType` | `datetime` | YES | |
| 4 | `terms_code` | `nvarchar(3)` | `nvarchar(3)` | YES | |
| 5 | `co_num` | `CoNumType` | `nvarchar(10)` | NO | |
| 6 | `co_line` | `CoLineType` | `smallint` | NO | |
| 7 | `unit_price` | `CostPrcType` | `decimal(20,8)` | YES | `0` |
| 8 | `tax_code1` | `nvarchar(6)` | `nvarchar(6)` | YES | |
| 9 | `exch_rate` | tenant decimal/UDDT | `decimal` | YES | `1` |
| 10 | `whse` | `WhseType` | `nvarchar(4)` | YES | |
| 11 | `item` | `ItemType` | `nvarchar(30)` | YES | |
| 12 | `qty_ordered` | `QtyUnitType` | `decimal(23,8)` | YES | `0` |
| 13 | `due_date` | `DateType` | `datetime` | YES | |
| 14 | `u_m` | `UMType` | `nvarchar(3)` | YES | |

## Technical Control Columns

These fields are required to implement status, validation messages, posting errors, retry, and audit:

| Sequence | Column | Application Data Type | Physical Type | Nullable | Default |
| ---: | --- | --- | --- | --- | --- |
| 15 | `process_status` | `nvarchar(1)` | `nvarchar(1)` | NO | `N'N'` |
| 16 | `validation_msg` | `nvarchar(1000)` | `nvarchar(1000)` | YES | |
| 17 | `error_msg` | `nvarchar(4000)` | `nvarchar(4000)` | YES | |
| 18 | `retry_count` | `int` | `int` | NO | `0` |
| 19 | `processed_date` | `DateType` | `datetime` | YES | |
| 20 | `processed_by` | `UsernameType` | `nvarchar(128)` | YES | |

## Standard Mongoose Columns

The table also contains:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
UpdatedBy
```

`SiteRef` is already included as the first business/framework column and must not be duplicated.

## Process Status Values

```text
N = New
V = Valid
E = Error
P = Processed
C = Cancelled
```

## Creation and Update Steps

1. Open `SQL Tables`.
2. Create or open metadata table `SMK069_temp_sales_mst`.
3. Confirm the physical table is `dbo.ue_SMK069_temp_sales_mst`.
4. Add the 14 business columns listed above.
5. Add the six technical control columns.
6. Add the standard Mongoose columns.
7. Configure the composite primary key: `SiteRef + co_num + co_line`.
8. Save and apply/update the table.
9. Confirm the physical columns exist.
10. Update/resynchronize the entity IDO so the new properties are generated.

## Completed Status

```text
[COMPLETED] table created
[COMPLETED] cost omitted based on confirmed revision
[COMPLETED] technical process-control columns added
[COMPLETED] IDO ue_SMK069TempSales created and updated
[NEXT]      create ue_SMK069APISalesErrorProcessing form
```

## Smoke Check

Verify the table and IDO expose at least:

```text
SiteRef
cust_num
order_date
terms_code
co_num
co_line
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
RowPointer
RecordDate
```

## Stop Point

This implementation step is complete after the table and IDO properties are updated. Continue with the form implementation in the next document.