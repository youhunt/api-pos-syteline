# Implementation 12 — Create `ue_SMK069APISalesErrorProcessing` Form

## Current Status

```text
Table                         : COMPLETED
IDO                           : COMPLETED and updated
Base form                     : COMPLETED
Preview controls              : COMPLETED
Blank-filter validation       : VERIFIED
CO Number-only filtering      : VERIFIED
Order Date-only filtering     : VERIFIED
Combined AND filtering        : VERIFIED
process_status list source    : VERIFIED
process_status read-only      : VERIFIED
Customer validation           : NOT STARTED
Process logic                 : NOT STARTED
API ingestion                 : NOT STARTED
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

## Required Grid Properties

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

Framework properties not displayed in the initial UI:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
UpdatedBy
```

## Read-Only Fields

These fields are system-maintained and must be read-only:

```text
SiteRef
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

Current verification boundary:

```text
[VERIFIED] process_status cannot be manually edited
[PENDING]  remaining six read-only fields require separate verification if needed
```

## `process_status` Data Source

Component:

```text
process_statusGridCol
```

Binding:

```text
object.process_status
```

List Source:

```text
INLINE ENTRIES(N\New,V\Valid,E\Error,P\Processed,C\Cancelled) DISPLAY(2) VALUE(1)
```

Mapping:

| Stored value | Display text |
| --- | --- |
| `N` | New |
| `V` | Valid |
| `E` | Error |
| `P` | Processed |
| `C` | Cancelled |

Tenant verification confirms that `N` displays as `New`. The user also confirmed that clicking the Status cell does not open an editable input or dropdown, so `process_status` is protected from manual changes.

Evidence:

```text
tests/evidence/2026-07-29-smk069-process-status-display.md
```

## Preview Rules — Verified

```text
Order Date only        → filter by order_date
CO Number only         → filter by co_num
Both entered           → filter by order_date AND co_num
Both blank             → show validation message; do not load all staging data
```

Blank-filter message:

```text
Isi Order Date atau CO Number sebelum Preview.
```

Controlled test rows:

```text
TEST000001 | 2026-07-29 | line 1
TEST000001 | 2026-07-29 | line 2
TEST000002 | 2026-07-30 | line 1
```

Verified tenant results:

```text
CO Number TEST000001 + blank Order Date
→ TEST000001 line 1 and line 2 only

Order Date 7/30/2026 + blank CO Number
→ TEST000002 line 1 only

Order Date 7/30/2026 + CO Number TEST000001
→ no matching business rows
→ confirms order_date AND co_num
```

The test data is stored only in the custom staging table:

```text
dbo.ue_SMK069_temp_sales_mst
```

No direct SQL insert is allowed into standard `co_mst` or `coitem_mst`.

## Form Implementation Checklist

```text
[x] base Grid Only form created
[x] form opens successfully
[x] caption confirmed
[x] required business/process grid columns displayed in tenant
[x] Order Date filter displayed
[x] CO Number filter displayed
[x] Preview button displayed
[x] blank-filter validation verified
[x] CO Number-only filtering verified
[x] Order Date-only filtering verified
[x] combined AND filtering verified
[x] process_status inline list source configured
[x] process_status displays New for stored N
[x] process_status read-only behavior verified
```

## Completed Stop Point

The base form and Preview behavior are complete for the current requirement.

Do not add Customer Order creation directly in the form. The next implementation area is reusable customer validation:

```text
cust_num must exist in customer_mst
```

Continue with:

```text
implementation/13-create-SMK069-customer-validation.md
```

## API Direction

The project remains an API integration:

```text
POS / Postman / sample CSV
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ reusable validation and error processing
→ supported Customer Order business process
→ co_mst + coitem_mst
```

CSV import, the Error Processing form, and REST API ingestion must reuse the same server-side validation and processing core.