# SMK069 CSV/POS — TRN → TBB Copy Guide

**Date:** 16 October 2026  
**Scope:** current working TRN CSV/POS inbound → Blanket Customer Order changes

## Important rule

Do **not** run the older consolidated PROD runtime package in TBB for the October
delta until the canonical Core/Receive procedures in the repository have been
synchronized with the exact working TRN definitions.

For TBB, migrate the **verified TRN objects exactly**.

## 0. Confirm the actual TBB Mongoose configuration name

Do not hardcode a TBB config name from an old script.

Use the Mongoose configurations endpoint first and select the TBB configuration
returned by the server.

The API documentation example previously showed a TBB configuration, while an
older repository test script contains a slightly different name. Treat the live
configuration list as authoritative.

## 1. What to copy — code/metadata only

Copy structure/code/metadata from TRN. Do **not** copy TRN transaction data.

### SQL objects

Required for the October retry/history delta:

~~~text
dbo.ue_SMK069_pos_sales_inbound_hist
dbo.ue_SMK069_pos_sales_inbound_history_v
dbo.SMK069ReceivePosSalesJsonCoreSp
dbo.SMK069ReceivePosSalesJsonSp
~~~

The two procedures must be exported from the verified working TRN definition,
not taken from an older repository runtime bundle.

Dependencies that must already exist in TBB:

~~~text
dbo.ue_SMK069_pos_sales_inbound_mst
dbo.ue_SMK069_temp_sales_mst
dbo.ue_SMK069_pos_sales_inbound_mapping_view
dbo.ue_SMK069_pos_field_map_mst
dbo.SMK030_UomConvQty2
dbo.Getumcf
itemcust_mst.Uf_SMK069_is_peak_season
itemcust_mst.Uf_SMK069_pos_um
~~~

### Mongoose metadata

~~~text
IDO:
  ue_SMK069PosSalesInboundHistory

Existing public/service IDO:
  ue_SMK069TempSales

Form:
  ue_SMK069APISalesErrorProcessing
~~~

Public Receive method requirement:

~~~text
SMK069ReceivePosSalesJsonSp
Transactional = False
~~~

The History IDO is read-only and sources:

~~~text
dbo.ue_SMK069_pos_sales_inbound_history_v
~~~

The verified TRN Error Processing form export is stored at:

~~~text
forms/csv-to-co/exports/
ue_SMK069APISalesErrorProcessing-TRN-2026-10-12.xml
~~~

## 2. What NOT to copy from TRN

Do not migrate transactional rows from:

~~~text
ue_SMK069_pos_sales_inbound_mst
ue_SMK069_pos_sales_inbound_hist
ue_SMK069_temp_sales_mst
ue_SMK069_pos_csv_batch_mst
ue_SMK069_pos_csv_upload_mst
co_mst
coitem_mst
co_bln_mst
~~~

History in TBB should start from TBB activity, not from TRN history.

Do not blindly replace TBB business/master data. Verify customer/item/U/M/warehouse
configuration separately.

## 3. Recommended copy order

~~~text
1. Export/backup current TBB SQL + IDO + form definitions
2. Run 01-preflight.sql in TBB
3. Create/align ue_SMK069_pos_sales_inbound_hist
4. Create/alter ue_SMK069_pos_sales_inbound_history_v
5. Deploy exact working TRN SMK069ReceivePosSalesJsonCoreSp
6. Deploy exact working TRN SMK069ReceivePosSalesJsonSp
7. Import/resync ue_SMK069PosSalesInboundHistory
8. Confirm ue_SMK069TempSales.SMK069ReceivePosSalesJsonSp Transactional=False
9. Import verified TRN ue_SMK069APISalesErrorProcessing form
10. Refresh Mongoose metadata/cache
11. Run 02-post-copy-verify.sql
12. Perform controlled API UAT
~~~

Do not import the History form before the view + History IDO exist.

## 4. Minimum TBB UAT

### A. Invalid quantity

Send a new TBB-safe BatchId/CustPO with a known quantity-multiple error.

Expected:

~~~text
API = POS-108
only the true root line is reported as invalid
message contains qty_hasil_konversi and u_m_hasil
no external "ValidationStatus mapping" wording
no CO created
History current row = CURRENT_ERROR
root validation_msg = POS-108
valid sibling = POS-203
~~~

### B. Corrected retry with SAME BatchId

Correct the payload and resend the same failed BatchId.

Expected:

~~~text
old attempt -> RETRY_SAME_BATCH
new payload is actually revalidated
attempt number increments
if corrected -> one CO only
no duplicate CO
~~~

### C. Successful replay protection

Replay after CO is created.

Expected:

~~~text
no second CO
business duplicate/idempotency protection remains intact
~~~

## 5. Current repository caveat

The repository has the October History table/view source and verified TRN form
export, but the exact working TRN Core/Receive SP bodies still need canonical
source synchronization before a new consolidated runtime package is generated.

For TBB migration today, use exact TRN SP exports.
