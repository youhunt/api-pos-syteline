# SMK069 Current Status and Handoff

## Primary Current Reference

The current implementation baseline is documented in:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

Use that document for all new work related to:

```text
CSV upload and parsing
Import & Validate
raw inbound preservation
field mapping
U/M validation
atomic-order validation
temporary sales staging
Process/Reprocess
co_mst type B
coitem_mst
co_bln_mst
created_co_num
transaction safety
idempotency
verification SQL
UAT checklist
```

## Current Final Flow

```text
CSV raw
→ Binary Value Action
→ csv_file
→ SMK069ImportCsvFileSp
→ CSV detail rows
→ SMK069RunCsvTestBatchSp
→ SMK069ReceivePosSalesJsonSp
→ raw inbound + validation
→ valid rows to temp, status V
→ SMK069ProcessCustomerOrderSp
→ co_mst type B
→ coitem_mst
→ co_bln_mst
→ temp status P + created_co_num
```

## Important Numbering Rule

```text
source/POS order = temp.co_num = co_mst.cust_po
generated CO     = temp.created_co_num = co_mst/coitem/co_bln.co_num
```

Never use the source/POS number as `co_bln_mst.co_num`.

## Current Validation Rule

U/M is valid when:

```text
u_m = item_mst.u_m
```

or an applicable conversion exists for:

```text
Global
Item
Customer
```

Vendor conversion does not qualify. One invalid line invalidates the entire source order.

## Current Blanket Mapping

```text
co_mst.type = B
co_bln_mst.stat = O
co_bln_mst.allow_on_pick_list = 0
blanket_qty = staging.qty_ordered
cont_price = staging.unit_price
```

## Current Transaction Rule

Stored procedures called from Mongoose/IDO must not unconditionally roll back the caller-owned transaction. Use:

```text
@@TRANCOUNT
savepoint
commit only procedure-owned transaction
rollback to savepoint when committable
rethrow when caller transaction is uncommittable
```

## Repository Synchronization Boundary

Committed:

```text
database/procedures/SMK069RunCsvTestBatchSp.sql
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
forms/02-SMK069PosCsvTestConsole.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
database/tables/SMK069_temp_sales_mst.md
tests/evidence/2026-08-06-smk069-um-validation-and-blanket-order-corrections.md
```

Still pending exact final tenant-source export and repository replacement:

```text
database/stored-procedures/SMK069ImportCsvFileSp.sql
database/procedures/SMK069ReceivePosSalesJsonSp.sql
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

Do not represent the old committed `SMK069ProcessCustomerOrderSp.sql` as the final Blanket version until it is replaced by the exact tenant source.

## Next Required Actions

```text
1. Export exact final parser source from tenant.
2. Export exact final Receive source with U/M conversion validation.
3. Export exact final Process source with type B, co_bln, allow_on_pick_list 0, and savepoint handling.
4. Commit those exact sources to this branch.
5. Verify CreatedCoNum property and grid column.
6. Run and record 100-row/25-order UAT.
7. Reconcile staging, coitem, and co_bln counts.
8. Review conversion-factor behavior.
9. Resolve PR mergeability/conflicts before merge.
```
