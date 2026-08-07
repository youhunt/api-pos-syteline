# Implementation 12 — `ue_SMK069APISalesErrorProcessing` Form

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
Customer validation           : COMPLETED
Receive API validation        : IMPLEMENTED IN TENANT
U/M conversion validation     : IMPLEMENTED IN TENANT
Process/Reprocess logic        : IMPLEMENTED IN TENANT
Blanket CO header              : IMPLEMENTED IN TENANT, co_mst.type = B
CO item lines                  : IMPLEMENTED IN TENANT, coitem_mst
Blanket lines                  : IMPLEMENTED IN TENANT, co_bln_mst
Generated CO display           : requires CreatedCoNum property/grid verification
Exact final Receive/Process SQL: PENDING REPOSITORY SYNC
```

Full CSV-to-Blanket-CO documentation:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

## Object Identity

```text
Form Name          : ue_SMK069APISalesErrorProcessing
Form Caption       : SMK API SALES ERROR PROCESSING
Primary Collection : ue_SMK069TempSales
Form Type          : Grid Only
Device Type        : Any
```

## Purpose

The form is the controlled processing boundary between validated temporary sales data and standard SyteLine Blanket Customer Order tables.

```text
Receive/Validate
→ ue_SMK069_temp_sales_mst, status V
→ this form
→ Process/Reprocess by SiteRef + source co_num
→ co_mst type B
→ coitem_mst
→ co_bln_mst
→ temp status P + created_co_num
```

The form must not bypass validation by writing directly into standard Customer Order tables.

## Required Grid Properties

```text
SiteRef
order_date
created_co_num       -- display: SyteLine CO Number
co_num               -- display: Source/POS CO Number
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

Framework properties can remain hidden:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
UpdatedBy
```

## Source Number vs Generated Number

```text
co_num          = source/POS order number
created_co_num  = generated SyteLine Customer Order number
```

Example:

```text
Source/POS CO Number : CS26080001
SyteLine CO Number   : CO26080017
```

The generated number is also used by:

```text
co_mst.co_num
coitem_mst.co_num
co_bln_mst.co_num
```

The source number is retained in:

```text
co_mst.cust_po
```

## Read-Only Fields

System-maintained fields must be read-only:

```text
SiteRef
created_co_num
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

Business fields may be editable only according to the approved correction workflow. Changes must be saved before Reprocess.

## `process_status` Data Source

Component binding:

```text
object.process_status
```

List Source:

```text
INLINE ENTRIES(N\New,V\Valid,E\Error,P\Processed,C\Cancelled) DISPLAY(2) VALUE(1)
```

| Stored value | Display text |
|---|---|
| `N` | New |
| `V` | Valid |
| `E` | Error |
| `P` | Processed |
| `C` | Cancelled |

## Preview Rules

```text
Order Date only        → filter by order_date
Source CO Number only  → filter by co_num
Both entered           → order_date AND co_num
Both blank             → validation message; do not load all rows
```

Blank-filter message:

```text
Isi Order Date atau CO Number sebelum Preview.
```

The CO Number filter refers to the source/POS number stored in `co_num`. A separate display/filter can be added for `created_co_num` when users need to search by the generated SyteLine number.

## Validate Behavior

Receive/API validation is the primary validation layer. Important rule:

```text
U/M valid when:
- equal to item_mst.u_m; or
- an applicable Global, Item, or Customer conversion exists.
```

Vendor conversion is excluded. One invalid line makes the entire source order invalid.

Manual staging rows must be validated through a controlled method before Process/Reprocess. Direct manual status changes to `V` are prohibited.

## Process/Reprocess Method

Procedure:

```text
dbo.SMK069ProcessCustomerOrderSp
```

Parameters:

```text
SiteRef       = selected/current SiteRef
SourceCoNum   = selected/current co_num
CustSeq       = 0
ProcessedBy   = USERNAME()
CreatedCoNum  = output
Success       = output
Infobar       = output
```

One invocation processes all lines having the same:

```text
SiteRef + co_num
```

Do not invoke once per grid line.

## Final Customer Order Output

### Header

```text
Table            : dbo.co_mst
Rows/order       : 1
Order type       : B
Source reference : cust_po = source co_num
```

### Customer Order Lines

```text
Table          : dbo.coitem_mst
Rows/order     : equal to staging line count
co_num         : generated SyteLine CO
```

### Blanket Lines

```text
Table              : dbo.co_bln_mst
Rows/order         : equal to staging line count
co_num             : generated SyteLine CO
stat               : O
allow_on_pick_list : 0
```

## Successful Result

```text
created_co_num = generated CO
process_status = P
validation_msg = NULL
error_msg = NULL
processed_date = current time
processed_by = current user
```

## Error Result

When the transaction remains committable:

```text
process_status = E
error_msg = original SQL/business error
retry_count = retry_count + 1
```

When an outer Mongoose transaction becomes uncommittable, the final tenant procedure rethrows the original error so the framework rolls back its own transaction.

## Transaction Safety

The final tenant Process procedure uses:

```text
@@TRANCOUNT detection
procedure-owned transaction when no caller transaction exists
SAVE TRANSACTION when called by Mongoose/IDO
commit only procedure-owned transaction
rollback to savepoint for a committable caller transaction
rethrow for an uncommittable caller transaction
```

This avoids the earlier error:

```text
Transaction count after EXECUTE indicates a mismatching number of
BEGIN and COMMIT statements.
```

## Idempotent Reprocess

Existing Blanket CO is located by:

```text
site_ref
cust_num
cust_po = source co_num
type = B
```

Before reusing it, the final tenant procedure verifies:

```text
coitem_mst line count
co_bln_mst line count
coitem item and quantity
co_bln item, blanket quantity, and contract price
```

If matching:

```text
no duplicate CO is created
created_co_num is synchronized
status becomes P
Success = 1
```

If not matching, processing fails for investigation.

## Form Event Guidance

Recommended Process/Reprocess sequence:

```text
10 Collection Save
20 Call IDO Method — SMK069ProcessCustomerOrderSp
30 Collection Refresh — primary
40 Display Infobar/output message
```

The method must use the source order number (`co_num`) as `SourceCoNum`, not `created_co_num`.

## UAT Checklist

```text
[ ] Valid source order creates one co_mst type B
[ ] All lines inserted into coitem_mst
[ ] All lines inserted into co_bln_mst
[ ] co_bln allow_on_pick_list = 0
[ ] source co_num stored as co_mst.cust_po
[ ] generated CO shown in created_co_num
[ ] staging line count = coitem count = co_bln count
[ ] reprocess matching existing order does not duplicate
[ ] invalid U/M never reaches Process from Receive
[ ] original SQL error is visible for process failure
[ ] no transaction count mismatch error
[ ] exact final Receive/Process SQL committed after tenant source export
```
