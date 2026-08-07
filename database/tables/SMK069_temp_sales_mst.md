# SMK069_temp_sales_mst

## Identity

```text
Metadata object : SMK069_temp_sales_mst
Physical table  : dbo.ue_SMK069_temp_sales_mst
Purpose         : Validated processing staging before Blanket Customer Order creation
Current status  : Implemented and used by CSV/API receive and Error Processing
```

Full end-to-end documentation:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

## Row Meaning

One row represents one source/POS Customer Order line.

```text
DEFAULT | CS26080001 | 1 | AA00005
DEFAULT | CS26080001 | 2 | AA00007
DEFAULT | CS26080001 | 3 | AA00008
```

Expected output:

```text
1 dbo.co_mst header, type B
3 dbo.coitem_mst lines
3 dbo.co_bln_mst lines
```

## Number Model

```text
co_num          = source/POS order number
created_co_num  = generated SyteLine Customer Order number
```

Example:

```text
co_num          = CS26080001
created_co_num  = CO26080017
```

The source number is copied to `co_mst.cust_po`. The generated number is used by `co_mst.co_num`, `coitem_mst.co_num`, and `co_bln_mst.co_num`.

## Primary Key

```text
SiteRef + co_num + co_line
```

This prevents duplicate source lines for the same site and source order.

## Site Column Decision

The source specification uses `site_ref`, while Mongoose provides standard `SiteRef`. On a case-insensitive database these names conflict, so the standard `SiteRef` column fulfills both roles.

## Structure

| Column | Data type / physical intent | Nullable | Meaning |
|---|---|---:|---|
| `SiteRef` | `SiteType`, nvarchar(8) | No | Source and target site; part of PK |
| `cust_num` | `CustNumType`, nvarchar(7) | Yes | Customer number |
| `order_date` | `DateType` | Yes | Source order date |
| `terms_code` | nvarchar(3) | Yes | Terms, payload or customer fallback |
| `co_num` | `CoNumType`, nvarchar(10) | No | Source/POS order number; part of PK |
| `created_co_num` | `CoNumType`, nvarchar(10) | Yes | Generated SyteLine CO number |
| `co_line` | `CoLineType`, smallint | No | Source order line; part of PK |
| `unit_price` | `CostPrcType`, decimal(20,8) | Yes | Source unit/contract price |
| `tax_code1` | nvarchar(6) | Yes | Tax code, payload or customer fallback |
| `exch_rate` | decimal | Yes | Exchange rate; default 1 |
| `whse` | `WhseType`, nvarchar(4) | Yes | Warehouse |
| `item` | `ItemType`, nvarchar(30) | Yes | SyteLine item |
| `qty_ordered` | `QtyUnitType`, decimal(23,8) | Yes | Source/blanket quantity |
| `due_date` | `DateType` | Yes | Due date; fallback order date |
| `u_m` | `UMType`, nvarchar(3) | Yes | Transaction U/M |
| `process_status` | nvarchar(1) | No | N/V/E/P/C process state |
| `validation_msg` | nvarchar(1000) | Yes | Validation details |
| `error_msg` | nvarchar(4000) | Yes | Processing error |
| `retry_count` | int | No | Process retry count; default 0 |
| `processed_date` | `DateType` | Yes | Last successful/attempt process timestamp |
| `processed_by` | `UsernameType`, nvarchar(128) | Yes | Last process caller |
| `CreateDate` | `CurrentDateType` | No | Framework create timestamp |
| `CreatedBy` | `UsernameType` | No | Framework creator |
| `InWorkflow` | `FlagNyType` | No | Framework flag |
| `NoteExistsFlag` | `FlagNyType` | No | Framework flag |
| `RecordDate` | `CurrentDateType` | No | Last record update timestamp |
| `RowPointer` | `RowPointerType` | No | Framework row identity |
| `UpdatedBy` | `UsernameType` | No | Framework last updater |

The tenant metadata remains the source of truth for exact precision/default expressions.

## Process Status

| Value | Meaning |
|---|---|
| `N` | New/manual row, not validated |
| `V` | Valid and ready for Process/Reprocess |
| `E` | Validation or processing error |
| `P` | Processed; Blanket CO created or idempotently reused |
| `C` | Cancelled |

Normal controlled flow:

```text
Receive valid row → V
Process success   → P
Process failure   → E
```

## Field Ownership

### Source/Business Data

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
```

### System-Maintained Data

```text
created_co_num
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

System-maintained fields must be read-only on the Error Processing form.

## Validation Before Insert into Temp

The final tenant `SMK069ReceivePosSalesJsonSp` transfers only fully valid orders. Validation includes:

```text
required fields and lengths
valid customer
valid item
valid warehouse
positive quantity
non-negative price
positive exchange rate
U/M equal to item base U/M or valid conversion
duplicate source line prevention
header consistency
atomic order rule
existing source order in temp prevention
```

One invalid line prevents every line of the source order from entering temp.

## Mapping to Standard Tables

### `co_mst`

```text
co_num  = created_co_num
type    = B
cust_po = source co_num
```

### `coitem_mst`

```text
co_num  = created_co_num
co_line = co_line
item    = item
quantity/price/U/M from staging
```

### `co_bln_mst`

```text
co_num       = created_co_num
co_line      = co_line
item         = item
blanket_qty  = qty_ordered
cont_price   = unit_price
stat         = O
allow_on_pick_list = 0
```

## Process Success Update

```text
created_co_num = @CreatedCoNum
process_status = P
validation_msg = NULL
error_msg = NULL
processed_date = GETDATE()
processed_by = caller
```

## Process Error Update

When the transaction is committable:

```text
process_status = E
error_msg = original error
retry_count = retry_count + 1
processed_date = NULL
processed_by = caller
```

If an outer Mongoose transaction is uncommittable, the final tenant procedure rethrows the original error and the caller owns the final rollback.

## IDO and Form Requirements

IDO:

```text
ue_SMK069TempSales
```

Required property:

```text
CreatedCoNum → created_co_num
```

Grid captions:

```text
created_co_num → SyteLine CO Number
co_num         → Source/POS CO Number
```

## Current Implementation Status

```text
[COMPLETED] Physical table and process-control fields
[COMPLETED] Entity IDO
[COMPLETED] Error Processing form and Preview
[COMPLETED] Customer validation
[IMPLEMENTED IN TENANT] Receive/API validation
[IMPLEMENTED IN TENANT] U/M conversion validation
[IMPLEMENTED IN TENANT] Blanket CO processing
[IMPLEMENTED IN TENANT] coitem_mst insert
[IMPLEMENTED IN TENANT] co_bln_mst insert
[IMPLEMENTED IN TENANT] created_co_num processing logic
[PENDING REPOSITORY SYNC] Exact final Receive/Process SQL source
[REQUIRED CHECK] CreatedCoNum property/grid synchronized in tenant
[REQUIRED UAT] 100-row/25-order formal evidence
```
