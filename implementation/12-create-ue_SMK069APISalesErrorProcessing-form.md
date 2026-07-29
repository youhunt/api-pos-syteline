# Implementation 12 — Create `ue_SMK069APISalesErrorProcessing` Form

## Current Status

```text
Table                       : COMPLETED
IDO                         : COMPLETED and updated
Base form                   : COMPLETED and opens successfully
Preview controls            : COMPLETED
Blank-filter check          : VERIFIED
Controlled staging test data: CREATED
CO Number-only filtering    : VERIFIED
Order Date-only filtering   : VERIFIED
Combined filtering          : VERIFIED
process_status list source  : CONFIGURED; DISPLAY TEST PENDING
Process logic               : NOT STARTED
API ingestion               : NOT STARTED
```

Do not recreate the table, IDO, base form, or Preview controls.

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
[VERIFIED] controlled test rows exist in the staging table
[VERIFIED] CO Number TEST000001 returns exactly line 1 and line 2
[VERIFIED] TEST000002 is excluded from the TEST000001 result
[VERIFIED] Order Date 7/30/2026 with CO Number blank returns TEST000002 line 1 only
[VERIFIED] TEST000001 dated 7/29/2026 is excluded from the 7/30/2026 result
[VERIFIED] Order Date 7/30/2026 plus CO Number TEST000001 returns no matching business rows
[VERIFIED] combined filtering uses order_date AND co_num
[CONFIGURED] process_status grid component uses an inline list source
```

Displayed blank-filter validation message:

```text
Isi Order Date atau CO Number sebelum Preview.
```

The screenshots do not by themselves prove every read-only setting. Read-only verification remains a separate tenant check.

## Controlled Test Dataset

The following temporary records were created only for form testing:

```text
TEST000001 | 2026-07-29 | line 1
TEST000001 | 2026-07-29 | line 2
TEST000002 | 2026-07-30 | line 1
```

These records are stored in the custom staging table:

```text
dbo.ue_SMK069_temp_sales_mst
```

No direct SQL insert is allowed into standard SyteLine tables `co_mst` or `coitem_mst`.

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

## `process_status` Data Source Configuration

The `process_statusGridCol` component is bound to:

```text
object.process_status
```

Its List Source is configured as:

```text
INLINE ENTRIES(N\New,V\Valid,E\Error,P\Processed,C\Cancelled) DISPLAY(2) VALUE(1)
```

Meaning:

| Stored value | Display text |
| --- | --- |
| `N` | New |
| `V` | Valid |
| `E` | Error |
| `P` | Processed |
| `C` | Cancelled |

`VALUE(1)` keeps the one-character process code as the underlying value. `DISPLAY(2)` shows the descriptive text in the form.

This list source does not change the business rule that `process_status` must remain read-only. Users must not manually change status through the grid; validation and processing logic will maintain it.

## Preview Rules

The implemented and verified behavior is:

```text
Order Date only        → filter by order_date
CO Number only         → filter by co_num
Both entered           → filter by order_date AND co_num
Both blank             → show validation message; do not load all staging data
```

Verification status:

```text
[VERIFIED] Both blank
[VERIFIED] CO Number only
[VERIFIED] Order Date only
[VERIFIED] Both entered
```

The Preview behavior is now fully verified for the current test dataset.

## Current Small Test — `process_status` Display and Read-Only

Perform only this field-protection test:

1. save the form metadata change;
2. open the form and load CO Number `TEST000002`;
3. confirm the Status column displays `New` for the underlying value `N`;
4. click the Status cell and attempt to select or type another status;
5. confirm the field cannot be changed and the underlying value remains `N`.

If the cell unexpectedly becomes editable, press `Esc` and do not save the row. Send a screenshot before changing form metadata.

Do not test Process, customer validation, Customer Order creation, or API ingestion during this step.

## API Direction

The final integration must use a controlled service IDO method rather than exposing unrestricted direct REST writes to the entity IDO.

CSV import and REST API ingestion should call the same reusable server-side receive and validation core so business logic is not duplicated.

The official POS payload is still unavailable. The final external API contract therefore remains pending. A PoC request may use the confirmed SMK069 staging fields, but must not be presented as the final POS contract.

Target flow:

```text
POS / Postman / sample CSV
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ validation and error processing
→ supported Customer Order business process
→ co_mst + coitem_mst
```

## Planned Process Button

After the remaining form-protection checks are complete, add or verify:

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
[x] controlled staging test data created
[x] CO Number-only filtering verified
[x] Order Date-only filtering verified
[x] combined Order Date + CO Number filtering verified
[x] process_status inline list source configured
[ ] process_status displays description while preserving one-character value
[ ] process_status read-only behavior verified
[ ] controlled service IDO receive method designed
[ ] API ingestion implemented
[ ] Process button verified
[ ] customer validation method connected
[ ] processing method connected
```

Only check an item after it has been implemented and tested in the tenant.