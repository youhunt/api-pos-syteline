# Implementation 12 — Create `ue_SMK069APISalesErrorProcessing` Form

## Current Status

```text
Table              : COMPLETED
IDO                : COMPLETED and updated
Base form          : COMPLETED and opens successfully
Preview controls   : CREATED
Blank-filter check : VERIFIED
Preview filtering  : BLOCKED — staging table has no test data
Process logic      : NOT STARTED
API ingestion      : NOT STARTED
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

Tenant screenshots confirm:

```text
[VERIFIED] form opens without metadata error
[VERIFIED] caption is SMK API SALES ERROR PROCESSING
[VERIFIED] grid is displayed
[VERIFIED] Order Date filter component is displayed
[VERIFIED] CO Number filter component is displayed
[VERIFIED] Preview button is displayed
[VERIFIED] clicking Preview with both filters blank shows a validation message
[BLOCKED]  CO Number filtering cannot yet be verified because staging contains no business/test rows
```

Displayed validation message:

```text
Isi Order Date atau CO Number sebelum Preview.
```

A second screenshot shows CO Number `123` entered and Preview executed, but no matching business row is displayed. This is not evidence that the filter works or fails because the staging table is currently empty.

The screenshots do not by themselves prove every read-only setting. Read-only verification remains a separate tenant check.

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

Only the fourth rule is currently verified in the tenant.

## Current Small Step — Provide Controlled Test Data

Preview filtering cannot be tested until the custom staging table contains controlled test rows.

The immediate next step is only to create a small test dataset in:

```text
dbo.ue_SMK069_temp_sales_mst
```

This is a custom staging table. No direct SQL insert may be performed into standard SyteLine tables `co_mst` or `coitem_mst`.

The recommended test dataset contains:

```text
TEST000001 line 1
TEST000001 line 2
TEST000002 line 1
```

This permits verification that filtering by `TEST000001` returns both of its lines and excludes `TEST000002`.

The temporary seed is only for UI smoke testing. The production ingestion direction remains:

```text
POS / Postman / sample CSV
→ controlled service IDO method
→ dbo.ue_SMK069_temp_sales_mst
→ validation and error processing
→ supported Customer Order business process
```

Do not treat a direct staging seed as the final API implementation.

## API Direction

The final integration must use a controlled service IDO method rather than exposing unrestricted direct REST writes to the entity IDO.

CSV import and REST API ingestion should call the same reusable server-side receive/validation core so business logic is not duplicated.

The official POS payload is still unavailable, so the final external API contract remains pending. A PoC request may use the confirmed SMK069 staging fields, but must not be presented as the final POS contract.

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
[ ] controlled staging test data created
[ ] CO Number-only filtering verified
[ ] Order Date-only filtering verified
[ ] combined Order Date + CO Number filtering verified
[ ] controlled service IDO receive method designed
[ ] API ingestion implemented
[ ] Process button verified
[ ] customer validation method connected
[ ] processing method connected
```

Only check an item after it has been implemented and tested in the tenant.