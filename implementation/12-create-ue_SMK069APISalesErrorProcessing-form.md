# Implementation 12 — Create `ue_SMK069APISalesErrorProcessing` Form

## Current Status

```text
Table              : COMPLETED
IDO                : COMPLETED and updated
Base form          : COMPLETED and opens successfully
Preview controls   : CREATED
Blank-filter check : VERIFIED
Preview filtering  : TEST PENDING
Process logic      : NOT STARTED
```

Do not recreate the table, IDO, or base form.

## Object Identity

```text
Form Name          : ue_SMK069APISalesErrorProcessing
Form Caption       : SMK API SALES ERROR PROCESSING
Primary Collection : ue_SMK069TempSales
Form Type          : Grid Only
Device Type        : Any
```

## Tenant Evidence — 29 July 2026

A tenant screenshot confirms:

```text
[VERIFIED] form opens without metadata error
[VERIFIED] caption is SMK API SALES ERROR PROCESSING
[VERIFIED] grid is displayed
[VERIFIED] Order Date filter component is displayed
[VERIFIED] CO Number filter component is displayed
[VERIFIED] Preview button is displayed
[VERIFIED] clicking Preview with both filters blank shows a validation message
```

Displayed validation message:

```text
Isi Order Date atau CO Number sebelum Preview.
```

The screenshot does not by itself prove every read-only setting or the actual filtering result. These remain separate tenant checks.

## Base Grid Properties

The required grid properties are:

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

These fields must be read-only for the user:

```text
SiteRef
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

They are maintained by validation and processing logic.

## Preview Rules

The intended behavior is:

```text
Order Date only        → filter by order_date
CO Number only         → filter by co_num
Both entered           → filter by order_date AND co_num
Both blank             → show validation message; do not load all staging data
```

The fourth rule is now verified in the tenant.

## Current Small Test — CO Number Only

The next test is only:

1. use a `co_num` that exists in `dbo.ue_SMK069_temp_sales_mst`;
2. leave Order Date blank;
3. enter that value in CO Number;
4. click Preview;
5. verify only rows for that `co_num` are displayed.

Do not proceed to Process, customer validation, or Customer Order creation during this test.

## Planned Process Button

After Preview filtering is fully verified, add or verify:

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
[x] base Grid Only form object created
[x] form opens successfully
[x] caption confirmed
[ ] primary collection ue_SMK069TempSales verified from form metadata
[ ] all 20 required grid properties confirmed
[ ] seven required fields confirmed read-only
[x] Order Date filter component displayed
[x] CO Number filter component displayed
[x] Preview button displayed
[x] blank-filter validation verified
[ ] CO Number-only filtering verified
[ ] Order Date-only filtering verified
[ ] combined Order Date + CO Number filtering verified
[ ] Process button verified
[ ] customer validation method connected
[ ] processing method connected
```

Only check an item after it has been implemented and tested in the tenant.