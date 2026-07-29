# Implementation 12 — Create `ue_SMK069APISalesErrorProcessing` Form

## Current Status

```text
Table : COMPLETED
IDO   : COMPLETED and updated
Form  : NOT CREATED
```

This document begins at the actual current stop point. Do not recreate the table or IDO.

## Object Identity

```text
Form Name          : ue_SMK069APISalesErrorProcessing
Form Caption       : SMK API SALES ERROR PROCESSING
Primary Collection : ue_SMK069TempSales
Form Type          : Grid Only
Device Type        : Any
```

## Step 1 — Create the Base Form

Open:

```text
Form Wizard
```

Create a new Grid Only form using `ue_SMK069TempSales` as the primary collection.

Select the following properties for the grid:

```text
SiteRef
order_date
co_num
co_line
cust_num
item
qty_ordered
u_m
unit_price
whse
due_date
terms_code
tax_code1
exch_rate
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

Do not display these framework properties in the initial UI:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
UpdatedBy
```

## Grid Order and Captions

| Order | Property | Caption |
| ---: | --- | --- |
| 1 | `SiteRef` | Site |
| 2 | `order_date` | Order Date |
| 3 | `co_num` | CO Number |
| 4 | `co_line` | Line |
| 5 | `cust_num` | Customer |
| 6 | `item` | Item |
| 7 | `qty_ordered` | Quantity |
| 8 | `u_m` | U/M |
| 9 | `unit_price` | Unit Price |
| 10 | `whse` | Warehouse |
| 11 | `due_date` | Due Date |
| 12 | `terms_code` | Terms |
| 13 | `tax_code1` | Tax Code |
| 14 | `exch_rate` | Exchange Rate |
| 15 | `process_status` | Status |
| 16 | `validation_msg` | Validation Message |
| 17 | `error_msg` | Error Message |
| 18 | `retry_count` | Retry Count |
| 19 | `processed_date` | Processed Date |
| 20 | `processed_by` | Processed By |

## Read-Only Fields

These process fields must be read-only for the user:

```text
SiteRef
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

They will be maintained by system validation and processing logic.

## Step 1 Test

After the wizard finishes:

1. open `ue_SMK069APISalesErrorProcessing`;
2. confirm the form opens without metadata errors;
3. confirm the primary collection is `ue_SMK069TempSales`;
4. confirm all 20 selected properties appear;
5. confirm process-control fields cannot be edited manually.

## Stop Point

Stop after the base form opens successfully.

Do not add Preview filters, buttons, or event handlers until this smoke test passes.

## Planned Step 2 — Filter Area

After the base form passes, add:

```text
Order Date filter
CO Number filter
Preview button
```

The intended behavior is:

```text
Order Date only        → filter by order_date
CO Number only         → filter by co_num
Both entered           → filter by order_date AND co_num
Both blank             → show validation message; do not load all staging data
```

## Planned Step 3 — Process Button

After Preview works, add:

```text
Button Name : btnProcess
Caption     : Process
Event       : SMK069Process
```

The Process action will use the selected row's:

```text
SiteRef + co_num
```

and process all lines belonging to the same Customer Order.

## Planned Validation

The first mandatory business validation is:

```text
cust_num must exist in customer_mst
```

## Implementation Checklist

```text
[ ] base Grid Only form created
[ ] form opens successfully
[ ] 20 required grid properties displayed
[ ] technical process fields read-only
[ ] filter variables added
[ ] Order Date filter component added
[ ] CO Number filter component added
[ ] Preview button added
[ ] blank-filter validation added
[ ] Process button added
[ ] customer validation method connected
[ ] processing method connected
```

Only check an item after it has been implemented and tested in the tenant.