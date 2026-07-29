# Implementation 12 — Create `ue_SMK069APISalesErrorProcessing` Form

## Current Status

```text
Table : COMPLETED
IDO   : COMPLETED and updated
Form  : CREATED; SMOKE TEST PENDING
```

The base form object has now been created in the tenant. Do not recreate the table, IDO, or form.

The form is not marked fully completed until the tenant smoke test confirms that it opens successfully, displays the required properties, and enforces the required read-only fields.

## Object Identity

```text
Form Name          : ue_SMK069APISalesErrorProcessing
Form Caption       : SMK API SALES ERROR PROCESSING
Primary Collection : ue_SMK069TempSales
Form Type          : Grid Only
Device Type        : Any
```

## Implementation Record — 29 July 2026

The user confirmed that the base form object was created.

Recorded implementation scope:

```text
Form Name          : ue_SMK069APISalesErrorProcessing
Caption            : SMK API SALES ERROR PROCESSING
Form Type          : Grid Only
Primary Collection : ue_SMK069TempSales
Device Type        : Any
```

Verification evidence has not yet been recorded in the repository. Therefore, the current status is:

```text
[COMPLETED] form object created
[PENDING]   form opens successfully without metadata errors
[PENDING]   all 20 required properties confirmed in the grid
[PENDING]   required technical fields confirmed read-only
```

Do not continue to Preview filters or Process logic until the pending smoke-test items are confirmed by the user or supported by a tenant screenshot.

## Step 1 — Base Form Configuration

The base form was designed as a Grid Only form using `ue_SMK069TempSales` as the primary collection.

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

## Current Smoke-Test Step

The next development action is only to verify the existing base form:

1. open `ue_SMK069APISalesErrorProcessing`;
2. confirm the form opens without metadata errors;
3. confirm the primary collection is `ue_SMK069TempSales`;
4. confirm all 20 selected properties appear;
5. confirm the seven required fields cannot be edited manually.

## Stop Point

Stop after performing the base-form smoke test.

Do not add Preview filters, buttons, event handlers, validation methods, or Customer Order processing until the smoke test passes.

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
[x] base Grid Only form object created
[ ] form opens successfully
[ ] primary collection ue_SMK069TempSales confirmed
[ ] 20 required grid properties displayed
[ ] seven required fields confirmed read-only
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