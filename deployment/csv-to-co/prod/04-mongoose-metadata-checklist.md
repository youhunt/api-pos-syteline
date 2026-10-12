# SMK069 PROD — Mongoose / UET / IDO / Form Migration Checklist

**Date:** 24 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order only

The SQL runtime package is not a replacement for Mongoose metadata migration.

Prefer exporting/importing the **verified working DEV metadata** rather than rebuilding objects manually in PROD.

## 1. UET — Customer Contracts / itemcust_mst

DEV-verified user fields — 28 Sep 2026:

```text
Uf_SMK069_is_peak_season
  User Data Type : int
  Decimals       : 0
  Initial Value  : <blank in UET metadata>

Uf_SMK069_pos_um
  User Data Type : UMType
  Physical Type  : nvarchar(3)
  Initial Value  : <blank in UET metadata>
```

The DEV UET Impact Schema completed successfully. For the CSV/POS workstream,
the relevant class/table relationship is the item-customer extension below.

Required UET class:

```text
Class Name : SMK069_CL_itemcust
Fields:
  Uf_SMK069_is_peak_season
  Uf_SMK069_pos_um
```

Required table extension:

```text
Table             : itemcust_mst
Class             : SMK069_CL_itemcust
Active            : 1
Extend All Records: 1
```

Customer Contracts form:

```text
POS U/M
[ ] Is Peak Season?
```

DEV evidence confirms the UET relationship is active and Impact Schema completed successfully.

For PROD:
1. migrate/import this verified UET metadata;
2. run UET Impact Schema;
3. confirm the two physical columns on `itemcust_mst` using
   `00f-verify-itemcust-uet-physical.sql`.

Do not use the direct physical-column script `00e-ensure-itemcust-peak-posum-physical.sql`
in the normal path; it is retained only as a fallback.

## 2. POS inbound table

Physical table:

```text
dbo.ue_SMK069_pos_sales_inbound_mst
```

Critical current fields include:

```text
inbound_id
source_system
batch_id
row_no
raw_json
SiteRef
cust_num
order_date
co_num
co_line
item
qty_ordered
unit_price
whse
due_date
u_m
terms_code
tax_code1
exch_rate
inbound_status
validation_msg
received_date
validated_date
transferred_date
cust_po
is_peak_season
```

`is_peak_season`:

```text
INT NOT NULL
default 0
```

## 3. Temp staging / Error Processing IDO

Physical table:

```text
dbo.ue_SMK069_temp_sales_mst
```

Entity IDO:

```text
ue_SMK069TempSales
```

Critical current fields:

```text
SiteRef
cust_num
order_date
terms_code
co_num
cust_po
co_line
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
is_peak_season
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
created_co_num
```

After metadata import / Impact Schema:

- resynchronize `ue_SMK069TempSales`;
- confirm `cust_po`, `created_co_num`, and `is_peak_season` are exposed;
- inspect generated `INSTEAD OF INSERT` trigger;
- generated trigger should be aligned with the physical table metadata.

DEV evidence showed an older generated trigger that did not list `is_peak_season`. Runtime still works because the public wrapper synchronizes Peak after Core, but **PROD metadata should be regenerated/aligned**, not knowingly migrated stale.

## 4. SMK API SALES ERROR PROCESSING form

Form:

```text
ue_SMK069APISalesErrorProcessing
Caption: SMK API SALES ERROR PROCESSING
Primary Collection: ue_SMK069TempSales
```

Final important bindings:

```text
SyteLine CO Number → object.created_co_num
CustPo             → object.cust_po
Peak Season        → object.is_peak_season
```

Peak Season:

```text
Control   : Checkbox
1         : checked
0         : unchecked
Read Only : True
Position  : beside CustPo
```

Do not bind the actual SyteLine CO display to the old technical/source R-number.

### CustSeq / Name lookup

DEV SQL proved:

```text
temp.co_num    = actual PYYMMDD### CO
mapping.co_num = technical/source R...
```

Therefore **never** join temp to mapping view using `co_num`.

Correct business lookup keys:

```text
SiteRef
cust_num
cust_po
co_line
```

SQL-proven relation:

```text
posin.SiteRef  = ts.SiteRef
posin.cust_num = ts.cust_num
posin.cust_po  = ts.cust_po
posin.co_line  = ts.co_line
```

Customer name:

```text
custaddr.cust_num = ts.cust_num
custaddr.cust_seq = posin.cust_seq
```

For PROD, migrate the working DEV IDO/form implementation. If derived properties are used instead of secondary tables, validate them in DEV first and ensure no `co_num` condition remains.

Expected display example:

```text
Peak CustPO:
CustSeq = mapped cust_seq
Name    = mapped custaddr.name
Peak    = checked

Normal CustPO:
CustSeq = mapped cust_seq
Name    = mapped custaddr.name
Peak    = unchecked
```

## 5. Public Receive IDO method

External/public method must invoke:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Critical setting:

```text
Transactional = False
```

Parameter order:

```text
 1 @SourceSystem
 2 @BatchId
 3 @PayloadJson
 4 @ReceivedBy
 5 @ReceivedRows OUT
 6 @TotalOrders OUT
 7 @ValidOrders OUT
 8 @ErrorOrders OUT
 9 @TransferredRows OUT
10 @Infobar OUT
11 @ProcessedOrders OUT
12 @ProcessErrors OUT
13 @CreatedCoNums OUT
14 @ThrowOnBusinessError
```

Do not reorder the first 10 parameters.

Postman/API calls depend on this positional contract.

## 6. Manual Error Processing methods

Preserve/export any DEV IDO methods/events currently used by:

```text
Preview
Validate
Process/Reprocess
```

Canonical SQL available in the repo includes:

```text
dbo.SMK069ValidateCustomerSp
dbo.SMK069ProcessCustomerOrderSp
```

Do not recreate event handlers from old archived documentation when a working DEV form export exists.

## 7. CSV batch/upload metadata

Required physical objects:

```text
dbo.ue_SMK069_pos_csv_batch_mst
dbo.ue_SMK069_pos_csv_upload_mst
```

CSV detail IDO:

```text
ue_SMK069PosCsvUpload
```

Required Peak property:

```text
is_peak_season
INT
default 0
```

After metadata migration:

1. resynchronize `ue_SMK069PosCsvUpload`;
2. verify property `is_peak_season`;
3. checkbox is read-only beside CustPo.

## 8. CSV console form

Form:

```text
ue_SMK069PosCsvBatchConsole
Caption: SMK POS CSV TO BLANKET CO
```

Keep safe operator flow:

```text
1. New Batch
2. Upload CSV to Blanket CO
3. Choose file
4. Parse
5. Run canonical CSV full process
6. Refresh result
```

One-hit event design must keep file import as direct primary action:

```text
Sequence 0 | ACTION(Import) COMPONENT(btnCsvToCoOneHit)
Sequence 1 | disable
Sequence 2 | SMK069ParseCsv
Sequence 3 | SMK069RunCsvFullProcess
Sequence 4+| refresh
```

Do not restore the withdrawn nested event:

```text
One-Hit → Upload Event → ACTION(Import)
```

because Web Client previously failed with the anonymous `choices` error.

Keep troubleshooting buttons:

```text
New Batch
Upload Only
Re-Parse CSV
Retry / Process CO
Upload & Process CSV to CO
```

## 9. Mapping view

Object:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

The working source definition has been captured in the repository and is part
of the final PROD runtime package:

```text
database/views/csv-to-co/ue_SMK069_pos_sales_inbound_mapping_view.sql
deployment/csv-to-co/prod/02-deploy-canonical-runtime.sql
```

There is no separate manual mapping-view creation step during PROD cutover.
The runtime package uses `CREATE OR ALTER VIEW` so it can bootstrap a fresh
target or align an existing target to the captured final definition.

It must support:

```text
Peak/Normal customer-item mapping
POS U/M mapping
mapped cust_num/cust_seq
business CustPO
mapped item
mapped qty/U/M
unit price
warehouse
ValidationStatus
```

## 10. Metadata acceptance

Before opening PROD to API traffic:

```text
[x DEV] UET user fields verified / [ ] PROD migrated
[x DEV] UET class verified / [ ] PROD migrated
[x DEV] itemcust extension active / [ ] PROD migrated
[ ] custom table metadata migrated
[x DEV] Impact Schema completed / [ ] PROD completed
[ ] generated triggers aligned
[ ] ue_SMK069TempSales resynchronized
[x PROD] public Receive IDO method imported
[x PROD] IDO methods set Transactional=False (user-confirmed)
[x PROD] 03-post-deploy verification PASS (no FAIL rows; temp trigger WARN only)
[x PROD] Error Processing form imported from verified DEV export / [ ] opens
[ ] Peak checkbox correct
[ ] CustSeq/Name correct
[ ] CSV detail IDO resynchronized
[x PROD] CSV console form imported from verified DEV export / [ ] opens
[x PROD XML] one-hit file-import event chain verified
[x PROD] mapping view final runtime deployed + contract verified
```


## Imported IDO XML audit — 28 Sep 2026

Imported Object Studio XML contains the CSV/POS IDOs:

```text
ue_SMK069PosCsvBatch
ue_SMK069PosCsvUpload
ue_SMK069PosSalesInbound
ue_SMK069TempSales
```

The `ue_SMK069TempSales` properties required by the latest Error Processing
design are present:

```text
CreatedCoNum -> created_co_num
CustPo       -> cust_po
IsPeakSeason -> is_peak_season (read-only)
CustSeq      -> derived from mapping view by SiteRef + CustPo
Name         -> derived from mapping view + custaddr by SiteRef + CustPo
```

### Required corrections before PROD UAT

The imported XML currently defines two processing/orchestration methods with an
outer Mongoose transaction:

```text
SMK069ReceivePosSalesJsonSp
  Transactional = YES

SMK069ProcessCustomerOrderSp
  Transactional = YES
```

Change both to:

```text
Transactional = NO / False
```

Reason: `SMK069ProcessCustomerOrderSp` owns its own SQL transaction boundary.
The public Receive path can call the per-order processor, and the Error
Processing form can call the per-order method directly.

The imported `SMK069ProcessCustomerOrderSp` metadata also still declares:

```text
SourceCoNum = VARCHAR(10)
```

but the final SQL signature is:

```text
@SourceCoNum NVARCHAR(100)
```

The parameter name is retained only for compatibility; new callers pass the
business `cust_po`. Set the IDO method parameter length to **100** so a valid
CustPO is not constrained by the old 10-character technical order contract.

The imported public Receive method exposes the original 10 parameters. Keep
that 10-parameter metadata if backward compatibility with existing callers is
required: the SQL procedure's parameters 11-14 are appended/defaulted, so the
10-parameter method remains valid.

Optional full-current metadata can expose:

```text
11 ProcessedOrders OUT
12 ProcessErrors OUT
13 CreatedCoNums OUT
14 ThrowOnBusinessError IN
```

but changing the IDO method to 14 parameters can change the positional Mongoose
Invoke contract for clients. Do not change this merely for migration parity
without coordinating the caller.

The XML also still contains the legacy
`SMK069ReceiveAndProcessPosSalesJsonSp` method. It may remain for compatibility,
but do not use it as the primary PROD API path. The final public entry point is
`SMK069ReceivePosSalesJsonSp`.

### Form export note

The supplied Object Studio XML contains IDO definitions only. It does not contain
the two form definitions/events. If the forms were imported separately, verify
them in PROD using sections 4 and 8 of this checklist before UAT.


## PROD IDO import status — 28 Sep 2026

User confirmed that the IDO metadata has been imported and all custom
`ue_SMK069TempSales` methods were set to:

```text
Transactional = NO
```

This is acceptable for the current CSV/POS inbound workstream. In particular,
the receive/orchestration and per-order processing methods must remain
non-transactional at the Mongoose method layer because
`SMK069ProcessCustomerOrderSp` owns its SQL transaction boundary.

Still verify before form UAT:

```text
SMK069ProcessCustomerOrderSp.SourceCoNum length = 100
```

The next migration gate is form/event verification:
`ue_SMK069APISalesErrorProcessing`,
`ue_SMK069PosCsvBatchConsole`, and the Customer Contracts custom controls.


## Form migration parity rule — 28 Sep 2026

The supplied FormsAndObjects export is the verified DEV form source used for the
PROD migration. Import it **as-is**. Do not rewrite bindings, event arguments,
read-only flags, or event chains merely to make them match later repository
design notes.

Confirmed DEV form export contains:

```text
ue_SMK069APISalesErrorProcessing
ue_SMK069PosCsvBatchConsole
```

For migration, DEV parity is the gate:

```text
DEV export -> PROD import -> open/smoke test -> business UAT
```

If UAT later proves a functional defect, fix the defect in DEV/source first,
re-test it there, then migrate that verified change to PROD. Do not create a
PROD-only form variant during the baseline migration.


## PROD preflight result — 28 Sep 2026

User supplied the Query Select result for `01-preflight.sql`.

Result:

```text
All Required Object rows       = PASS
All Runtime Prerequisite rows  = PASS
All Inbound Column rows        = PASS
All Temp Column rows           = PASS
All CSV Upload Column rows     = PASS
Both itemcust UET fields       = PASS
All target SyteLine columns    = PASS
Mapping view                   = INFO / already exists
```

No FAIL rows were present. PROD is cleared for
`02-deploy-canonical-runtime.sql`.


## PROD runtime deployment result — 28 Sep 2026

User executed:

```text
deployment/csv-to-co/prod/02-deploy-canonical-runtime.sql
```

through SyteLine **Apply Database**.

Observed result:

```text
Process Completed Successfully
```

No deployment error was reported. The next gate is
`03-post-deploy-verify.sql` through **Query Select**.


## PROD post-deploy verification query fix — 28 Sep 2026

The first `03-post-deploy-verify.sql` execution reached Query Select but failed
while composing the verification grid because tenant catalog/database collations
differed inside a `UNION ALL` text column:

```text
SQL_Latin1_General_CP1_CI_AS
vs
Latin1_General_CI_AS_KS_WS
```

This is a verification-query collation issue only; it does not indicate failure
of the already successful `02-deploy-canonical-runtime.sql` deployment.

The verification query now normalizes catalog-derived text using
`COLLATE DATABASE_DEFAULT` while remaining exactly one SELECT statement.


## PROD post-deploy verification result — 28 Sep 2026

User supplied the successful Query Select result from
`03-post-deploy-verify.sql`.

Summary:

```text
Runtime objects                         PASS (8/8)
Final runtime markers                   PASS (8/8)
Public Receive SQL parameters           PASS (14/14)
Mapping view columns                    PASS (30/30)
Peak/UET physical fields                PASS (5/5)
Mongoose temp trigger                   WARN: no trigger found
Mapping view SHA-256                    INFO
  4D5C78F5D8BFA517652C41C9A378311774998A622AE18FC78FD5266899630973
```

There were no FAIL rows.

The temp-table trigger warning is not treated as a runtime deployment failure:
the final receive/process path writes staging through SQL procedures and the
imported IDO uses the custom table as its primary table. Keep this warning as a
metadata/UAT observation; verify the Error Processing form can load/update the
intended rows during UAT before sign-off.


## PROD smoke UI result — 28 Sep 2026

User opened all three migrated UI surfaces successfully:

```text
SMK API SALES ERROR PROCESSING
SMK POS CSV TO BLANKET CO
SMK Customer Contracts
```

Customer Contracts visibly contains:

```text
POS U/M
Is Peak Season?
```

No UI/opening error occurred. The Error Processing and CSV grids are empty
because no PROD UAT transaction has been submitted yet; this is expected and
does not by itself validate processing behavior.

Next gate: create an approved PROD-safe Normal/non-Peak UAT transaction, then
verify inbound -> temp -> Blanket CO -> form traceability.


## October 2026 History / same-Batch retry delta

Additional verified TRN metadata is now required for the latest Error Processing design:

~~~
IDO:
  ue_SMK069PosSalesInboundHistory
  source = dbo.ue_SMK069_pos_sales_inbound_history_v
  read-only

Form:
  ue_SMK069APISalesErrorProcessing
  secondary collection = object2 / History
  History tab = enabled
  StdFormInitCompleted -> RefreshHistory()
  StdFormRefresh       -> RefreshHistory()
~~~

The public Receive method must remain:

~~~
SMK069ReceivePosSalesJsonSp
Transactional = False
~~~

The latest detailed migration gate is:

~~~
deployment/csv-to-co/prod/07-trn-to-prd-delta-2026-10-12.md
~~~
