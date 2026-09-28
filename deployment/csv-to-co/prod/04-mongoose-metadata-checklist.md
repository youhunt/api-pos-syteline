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

Ownership:

```text
Eva / SMK
```

Do not create a competing repository-owned view.

Production migration must use the exact current DEV definition.

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
[x PROD] Error Processing form imported / [ ] corrections applied + opens
[ ] Peak checkbox correct
[ ] CustSeq/Name correct
[ ] CSV detail IDO resynchronized
[x PROD] CSV console form imported / [ ] opens
[x PROD XML] one-hit file-import event chain verified
[ ] mapping view exact DEV definition migrated
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


## PROD form import audit — 28 Sep 2026

Imported FormsAndObjects export was reviewed.

Confirmed imported forms:

```text
ue_SMK069APISalesErrorProcessing
ue_SMK069PosCsvBatchConsole
```

CSV one-hit event chain matches the safe FIX2 design and is accepted.

Required corrections before UAT:

```text
Error Processing / Process-Reprocess:
  SourceCoNum argument : co_num -> CustPo
  CustSeq argument     : 0      -> CustSeq

Read-only display:
  CreatedCoNum = True
  CustSeq      = True
  Name         = True
  IsPeakSeason = True

CSV detail:
  IsPeakSeason = Read Only
```

Detailed audit:

```text
forms/csv-to-co/04-prod-form-import-audit-20260928.md
```
