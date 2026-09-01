# SMK069 Development Recap Through 31 August 2026

> **Prepared:** 1 September 2026  
> **Repository:** `youhunt/api-pos-syteline`  
> **Scope:** recap from the documented POS Contract V2 baseline through the work/UAT completed up to 31 August 2026.  
> **Primary baseline:** `SMK_API_Docs_SMK069_POS_Integration_V2_20260827` (UAT-confirmed 27 Aug 2026).  
> **Shipment requirement:** `MF_SMK_API_SHIPMENT_REV_1.1`.

---

## 1. Purpose of this document

This document is the consolidated handoff/status reference for the SMK069 integration work completed through 31 August 2026.

It deliberately separates:

1. the **documented baseline as of 27 Aug 2026**;
2. the **changes implemented and UAT-tested after that baseline**;
3. items that were **prepared but not confirmed as deployed**;
4. experimental patches that were **explicitly not adopted**;
5. the new **Shipment outbound** workstream.

This is important because the 27-Aug API document is no longer sufficient by itself to describe the runtime behavior after the outlet/customer mapping revisions.

---

## 2. Executive status

| Area | Status | Current result |
|---|---|---|
| POS Receive API V2 | ✅ Working | Raw inbound, validation, pricing, generated CO number |
| `cust_po` as POS order | ✅ Working | POS sends `cust_po`; SyteLine generates `co_num` |
| Auto CO number | ✅ Working | `R + YYMM + 5-digit running` |
| Server-side pricing | ✅ Working | From `itemcustprice_mst` |
| U/M validation | ✅ Working | Item base U/M or item-specific conversion |
| Atomic order validation | ✅ Working | One invalid line makes the complete `cust_po` order invalid |
| CSV Test Console V2 | ✅ Working | Parser accepts V2 fields and persists `cust_po` |
| Outlet/Store mapping | ✅ Working | POS `custnum` mapped through `custaddr_mst` |
| Warehouse mapping | ✅ Working | `P963/R970 -> PLG`, otherwise `MAIN` |
| Mapped-customer pricing | ✅ Working | Pricing uses mapped SyteLine customer |
| Blanket Customer Order | ✅ Working | `co_mst.type = B` |
| `coitem_mst` creation | ✅ Working | One row per staging line |
| `co_bln_mst` creation | ✅ Working | One row per staging line |
| Actual `cust_seq` lookup | ✅ Working | Resolved from `custaddr_mst`; not stored in temp |
| Transaction safety | ✅ Working | Mongoose outer transaction/savepoint handling |
| Latest successful CO UAT | ✅ Working | `R260822004`, mapped customer `PHR0001`, `cust_seq=1` |
| API validation error detail in response | 🟡 Prepared | V2.3.1 prepared; deployment confirmation still required |
| Inbound validation UI | ⏳ Gap | Raw inbound E records are not shown in Error Processing form |
| Shipment outbound API | 🟡 Started | Requirement analyzed; flag SQL prepared |
| Shipment API view | ⏳ Not implemented | `SMK069_ShipmentAPI_mst` next |
| Shipment scheduler/sender | ⏳ Not implemented | Planned hourly/adjustable run |
| Shipment Error Processing | ⏳ Not implemented | Required by shipment business flow |

---

# PART A - DOCUMENTED BASELINE THROUGH 27 AUGUST 2026

## 3. POS Contract V2 baseline

The documented V2 contract changed the POS input model so POS no longer supplies:

```text
conum
unit_price
```

POS supplies:

```text
custnum
order_date
cust_po
whse
coline
item
qty_ordered
u_m
```

SyteLine is responsible for:

- validating the inbound order;
- resolving unit price;
- generating the final SyteLine Customer Order number;
- transferring only valid atomic orders to processing temp.

### Baseline flow

```text
POS JSON batch
   |
   v
ue_SMK069_pos_sales_inbound_mst
   |
   +--> invalid -> inbound_status = E
   |
   v
validation + pricing
   |
   v
generate co_num
   |
   v
ue_SMK069_temp_sales_mst
   |
   v
SMK069ProcessCustomerOrderSp
   |
   +--> co_mst      (type = B)
   +--> coitem_mst
   +--> co_bln_mst
   |
   v
temp.process_status = P
```

### Key identifiers

| Identifier | Meaning |
|---|---|
| `BatchId` | inbound idempotency key |
| `cust_po` | original POS order/customer PO |
| `co_num` | generated SyteLine Customer Order number |
| `created_co_num` | audit/compatibility field; in V2 equals the generated `co_num` after Process |

Important:

```text
cust_po != co_num
```

POS owns `cust_po`; SyteLine owns `co_num`.

---

## 4. Receive API baseline

Primary method:

```text
ue_SMK069TempSales.SMK069ReceivePosSalesJsonSp
```

Important outputs:

```text
ReceivedRows
TotalOrders
ValidOrders
ErrorOrders
TransferredRows
Infobar
```

Interpretation:

```text
Success=true
```

means the IDO/method call technically executed. It does **not** guarantee the business order was valid.

Business success must be evaluated from:

```text
ValidOrders
ErrorOrders
TransferredRows
Infobar
```

---

## 5. Server-side Customer Order number

The documented generation format is:

```text
R + YYMM + 5-digit running number
```

Example:

```text
R260822003
```

Receive generates the number once. Process must reuse that number and must not generate a second CO number.

---

## 6. Server-side price resolution

Pricing is resolved from `itemcustprice_mst` using the effective customer-item price for `order_date`.

Core behavior:

1. select the latest effective pricing row where `effect_date <= order_date`;
2. use `cont_price` when non-zero;
3. support the applicable quantity-break price when the contract price requires it;
4. reject the order if no usable effective price is available.

---

## 7. Baseline validation rules

The V2 baseline included:

- required fields;
- customer validation;
- item validation;
- warehouse validation;
- U/M validation;
- price validation;
- Terms validation;
- duplicate line validation;
- header consistency;
- atomic order validation;
- duplicate/existing order protection.

### Atomic order principle

```text
SiteRef + cust_po = one source order
```

If one line fails, the entire source order becomes Error and is not partially transferred.

---

## 8. Confirmed baseline UAT - 27 Aug 2026

Receive UAT:

```text
BatchId          = BATCH-20260827-002
cust_po          = POS08270002
ReceivedRows     = 2
TotalOrders      = 1
ValidOrders      = 1
ErrorOrders      = 0
TransferredRows  = 2
generated co_num = R260822003
unit_price       = 80000
u_m              = CTN
whse             = MAIN
```

Process UAT:

```text
co_num            = R260822003
cust_po           = POS08270002
co_mst.type       = B
temp status       = P
result            = success
```

The same generated `co_num` is used by:

```text
co_mst
coitem_mst
co_bln_mst
```

---

# PART B - CHANGES AFTER THE 27-AUG BASELINE

## 9. CSV Test Console alignment to Contract V2

The 27-Aug document still listed CSV synchronization as a follow-up. That work was subsequently completed.

### CSV input contract

Required CSV fields became:

```text
custnum
order_date
cust_po
whse
coline
item
qty_ordered
u_m
```

CSV no longer requires:

```text
conum
unit_price
```

### Updated components

- `SMK069ImportCsvFileSp`
- `SMK069RunCsvTestBatchSp`
- CSV detail schema with `cust_po`
- `ue_SMK069PosCsvUpload.CustPo`
- CSV Test Console grid/documentation
- sample CSV
- V2 persistence validation

### Important parser issue found during UAT

The raw CSV splitter correctly returned:

```text
field_3 = POS08270003
```

but `cust_po` initially persisted as NULL in `ue_SMK069_pos_csv_upload_mst`.

The parser was hardened until the final parse result showed:

```text
CSV V2 berhasil diparsing. Rows=2; FormatErrors=0.
```

and the grid correctly displayed:

```text
CustPo = POS08270003
```

while `Co Num` and `Unit Price` remained blank at the Parse stage, as intended.

They are generated/resolved later by Receive.

---

## 10. Outlet/Store Code customer mapping

This is the largest functional revision after the 27-Aug baseline.

The POS field `custnum` is now treated as an **Outlet/Store Code**, not directly as the final SyteLine `customer_mst.cust_num`.

### Mapping rule

```sql
custaddr_mst.cust_num LIKE 'PHR%'
custaddr_mst.cust_seq <> 0
LEFT(custaddr_mst.name, 4) = inbound POS custnum
```

### Confirmed example

```text
POS custnum = P001
```

maps to:

```text
custaddr_mst.cust_num = PHR0001
custaddr_mst.cust_seq = 1
name                  = P001 Kelapa Gading Boulevard
```

### Design decision

`cust_seq` is **not added to**:

```text
ue_SMK069_temp_sales_mst
```

It remains a lookup result from `custaddr_mst`.

### Temp behavior

```text
inbound.cust_num = raw POS Outlet Code
temp.cust_num    = mapped SyteLine customer
```

This preserves raw source data for audit while ensuring processing uses the mapped SyteLine customer.

---

## 11. Warehouse mapping revision

POS warehouse codes are now mapped before entering temp.

Current mapping:

```text
P963 -> PLG
R970 -> PLG
other values -> MAIN
```

Example:

```text
inbound.whse = P963
temp.whse    = PLG
```

Raw inbound warehouse remains unchanged for audit.

---

## 12. Pricing now uses the mapped SyteLine customer

Because POS `custnum` is only the outlet/store code, pricing can no longer use the raw incoming `custnum`.

Current pricing flow:

```text
POS Outlet Code
   |
   v
custaddr_mst mapping
   |
   v
mapped SyteLine cust_num
   |
   v
itemcustprice_mst
```

Confirmed UAT data:

```text
mapped customer = PHR0001
item            = AD00001
u_m             = CTN
resolved price  = 630100
```

`PHR0001` is test data from the mapping result and is **not hardcoded**.

---

## 13. Actual Customer Sequence processing

The actual customer sequence is resolved again during Process.

Conceptually:

```text
temp.co_num
   |
   v
find raw inbound order
   |
   v
raw POS outlet/store code
   |
   v
custaddr_mst
   |
   v
mapped cust_num + cust_seq
   |
   v
Customer Order processing
```

This allows:

```text
co_mst.cust_num = mapped temp customer
co_mst.cust_seq = actual custaddr_mst.cust_seq
```

without adding a `cust_seq` column to temp.

---

## 14. Terms Code handling

During outlet UAT, the mapped customer had blank `terms_code`.

The previous validation was too strict.

The corrected runtime behavior used for the successful UAT is:

```text
terms_code blank -> allowed
terms_code populated -> must be valid in terms_mst
```

This prevented valid mapped customers with intentionally blank Terms Code from being rejected prematurely.

---

## 15. Tax Code incident and master-data resolution

A Process test initially failed with the underlying SyteLine tax computation error:

```text
Tax Code that has [Tax System: 1]
and [Tax Code Type: Rate]
and [Tax Code: (Blank)]
and [Site: Default] does not exist.

Tax Computation was not successful
for Customer Order R260822004.
```

The issue was traced to master data:

```text
customer_mst.tax_code1
```

for mapped customer `PHR0001`.

After the customer master was populated with:

```text
PHR0001 / cust_seq 0 -> NPPN
PHR0001 / cust_seq 1 -> NPPN
```

the same order processed successfully.

### Explicitly not adopted

Two additional defensive patches were prepared:

```text
SMK069ReceivePosSalesJsonSp V2.4 Tax Code Guard
SMK069ProcessCustomerOrderSp V2.5 Tax Code Guard
```

They were explicitly **not adopted/deployed as the runtime baseline**, because the actual issue was resolved by correcting `customer_mst.tax_code1`.

Do not treat those two Tax Guard versions as the confirmed production baseline.

---

## 16. Transaction handling corrections

Earlier Process attempts exposed transaction issues such as:

```text
Transaction count after EXECUTE indicates a mismatching number...
```

and:

```text
Uncommittable transaction is detected at the end of the batch.
```

Process was revised for Mongoose/IDO transaction ownership using transaction/savepoint-safe behavior.

A diagnostic revision also rethrew the original SQL error when the outer Mongoose transaction became uncommittable. This exposed the real Tax Computation problem instead of the generic transaction message.

Transaction goals remain:

- no mismatched BEGIN/COMMIT;
- rollback the complete Customer Order on failure;
- no partial `co_mst/coitem_mst/co_bln_mst`;
- safe behavior when the caller already owns the transaction.

---

## 17. Latest successful outlet-mapping UAT

The latest confirmed successful end-to-end case through 28 Aug is:

### POS/source

```text
custnum  = P001
whse     = P963
cust_po  = POS08280002
item     = AD00001
u_m      = CTN
```

### Mapping

```text
P001 -> PHR0001
cust_seq -> 1
P963 -> PLG
```

### Pricing

```text
AD00001 / PHR0001 -> 630100
```

### Receive

```text
ReceivedRows     = 2
TotalOrders      = 1
ValidOrders      = 1
ErrorOrders      = 0
TransferredRows  = 2
```

### Process result

```text
Blanket Customer Order R260822004 berhasil dibuat
untuk cust_po POS08280002;
customer PHR0001;
cust_seq 1.
```

This confirms:

- Outlet mapping works.
- Actual non-zero `cust_seq` works.
- Warehouse mapping works.
- Mapped-customer pricing works.
- Blanket CO creation works.

---

# PART C - 31 AUGUST API SUPPORT / ERROR VISIBILITY

## 18. Real external test: Batch R919-3

A real request was received with:

```text
BatchId = R919-3
cust_po = R919-3
custnum = R919
```

Response:

```text
Success          = true
ReceivedRows     = 2
TotalOrders      = 1
ValidOrders      = 0
ErrorOrders      = 1
TransferredRows  = 0
```

Interpretation:

```text
Technical API/IDO execution -> success
Raw inbound saved           -> yes
Business validation         -> failed
Transferred to temp         -> no
Customer Order created      -> no
```

This confirms why API consumers must not interpret `Success=true` alone as business success.

---

## 19. Error detail in API response

The current IDO signature already has the `Infobar` output.

A V2.3.1 revision was prepared so `Infobar` can append row-level `validation_msg` information when `ErrorOrders > 0`.

Target response pattern:

```text
Batch R919-3 diterima.
Row: 2;
order(cust_po): 1;
valid: 0;
error: 1;
row masuk temp: 0.
ErrorDetail:
Row 1 [cust_po=R919-3]: <validation reason>
...
```

The same behavior was designed for an idempotent replay of an already received BatchId.

### Status

```text
Prepared: YES
Deployment/UAT confirmation: NOT YET RECORDED
```

Until confirmed, do not describe this behavior as deployed runtime behavior.

---

## 20. UI gap: inbound errors vs processing errors

The existing form:

```text
SMK API SALES ERROR PROCESSING
```

operates on:

```text
ue_SMK069_temp_sales_mst
```

Therefore, an order that fails Receive and has:

```text
TransferredRows = 0
```

does not naturally appear in this processing form.

### Identified UI requirement

A self-service UI should expose two logical areas:

```text
Inbound/API Validation
- Batch ID
- Cust PO
- Outlet Code
- Order Date
- Item
- Quantity
- U/M
- POS Warehouse
- Inbound Status
- Validation Message
- Received Date

Processing
- temp data
- Validate
- Process/Reprocess
- generated SyteLine CO
- Process status
- Process error
```

This would allow API users/support staff to inspect Receive validation failures without manually querying inbound or contacting the technical team.

### Status

```text
Identified / recommended
Not implemented yet
```

---

# PART D - SHIPMENT OUTBOUND WORKSTREAM

## 21. Shipment outbound requirement

A new workstream covers:

```text
SyteLine Shipment -> POS Outlet API
```

This is the reverse direction from the inbound Customer Order API.

The shipment requirement defines an automatic schedule approximately every one hour, adjustable later.

High-level flow:

```text
Shipment ready
   |
   v
scheduled Shipment API job
   |
   v
build POS shipment payload
   |
   v
POST to POS
   |
   +--> failure -> retry/error processing
   |
   v
success
   |
   v
shipment_mst API flag = 1
shipment_mst API post date = current date/time
```

---

## 22. Shipment Master API flags

Required fields:

```text
shipment_mst.SMK069_Uf_api_post       int
shipment_mst.SMK069_Uf_api_post_date datetime
```

Intended meaning:

```text
SMK069_Uf_api_post
0 = not successfully posted
1 = successfully posted

SMK069_Uf_api_post_date
= successful API post timestamp
```

A Step-1 SQL script was prepared with:

- add the two columns if missing;
- backfill existing null API flags to 0;
- default future API flags to 0;
- verification query.

### Status

```text
SQL prepared
Apply/UAT confirmation not yet recorded
```

---

## 23. Shipment API view requirement

Required view:

```text
SMK069_ShipmentAPI_mst
```

The requirement joins:

```text
shipment_mst
shipment_line_mst
coitem_mst
co_mst
customer_mst
shipment_seq_mst
lot_mst
```

Target payload fields include:

```text
CUST_CODE
WHS_CODE
DOC_NO
DN_NO
DELIVERY_DATE
STORE_ORDER_NO
STORE_CODE
VEHICLE_NUMBER

DETAIL:
PRODUCT_CODE
SHIPMENT_QTY
UOM
PRICE
BATCH
EXPIRY_DATE
```

Only shipments with API flag 0 are candidates for outbound posting.

### Important mapping ambiguities still to settle in implementation

The supplied requirement contains some inconsistencies that must be resolved when building the view, including:

- `DOC_NO` mapping table vs draft SQL;
- the invalid/incomplete `IIF(sh.whse,'R963','R975')` expression;
- UOM representation expected by the POS Shipment API;
- final warehouse-code conversion.

### Status

```text
Requirement analyzed
View not implemented yet
```

---

## 24. Shipment success update

When the complete shipment payload is accepted successfully by POS, the requirement says to update by `shipment_id`:

```sql
SMK069_Uf_api_post = 1
SMK069_Uf_api_post_date = GETDATE()
```

The expected design is shipment-level atomicity:

```text
one shipment_id = one outbound API unit

success -> flag shipment as posted
failure -> keep it pending/error for retry
```

The exact interpretation of partial detail failure must be finalized with the POS API behavior.

---

# PART E - CURRENT OBJECT INVENTORY

## 25. Main custom data objects

```text
dbo.ue_SMK069_pos_csv_batch_mst
dbo.ue_SMK069_pos_csv_upload_mst
dbo.ue_SMK069_pos_sales_inbound_mst
dbo.ue_SMK069_pos_field_map_mst
dbo.ue_SMK069_temp_sales_mst
```

Target standard SyteLine objects:

```text
dbo.co_mst
dbo.coitem_mst
dbo.co_bln_mst
```

Customer/master dependencies now include:

```text
dbo.custaddr_mst
dbo.customer_mst
dbo.item_mst
dbo.itemcustprice_mst
dbo.u_m_conv_mst
dbo.whse_mst
dbo.terms_mst
dbo.taxcode_mst
```

Shipment work additionally depends on:

```text
dbo.shipment_mst
dbo.shipment_line_mst
dbo.shipment_seq_mst
dbo.lot_mst
```

---

## 26. Main stored procedures / functional areas

```text
SMK069ImportCsvFileSp
SMK069RunCsvTestBatchSp
SMK069ReceivePosSalesJsonSp
SMK069ProcessCustomerOrderSp
```

Roles:

| Procedure | Role |
|---|---|
| `SMK069ImportCsvFileSp` | Parse CSV into CSV detail rows |
| `SMK069RunCsvTestBatchSp` | Build V2 JSON from parsed CSV and call Receive |
| `SMK069ReceivePosSalesJsonSp` | Raw inbound, mapping, validation, pricing, CO number generation, temp transfer |
| `SMK069ProcessCustomerOrderSp` | Create/reconcile Blanket Customer Order, coitem and blanket lines |

---

# PART F - VERSION / DEPLOYMENT NOTES

## 27. Runtime baseline notes

The exact runtime source must be treated carefully because several diagnostic/defensive variants were created during UAT.

### Confirmed concepts in the successful runtime path

- Contract V2 `cust_po`.
- server-generated `co_num`;
- server-resolved `unit_price`;
- CSV V2 persistence fix;
- Outlet Code mapping through `custaddr_mst`;
- `cust_seq <> 0` lookup;
- no `cust_seq` temp column;
- POS warehouse mapping;
- mapped-customer pricing;
- blank Terms Code allowed;
- safe transaction handling;
- error rethrow used to expose underlying SyteLine errors;
- master Tax Code correction resulted in successful CO processing.

### Explicitly not runtime baseline

```text
Receive V2.4 Tax Code Guard
Process V2.5 Tax Code Guard
```

Those were prepared but explicitly not used after the customer master Tax Code was corrected.

### Prepared but deployment confirmation pending

```text
Receive V2.3.1 Error Detail Output
Shipment API flag SQL
```

---

## 28. Repository branch status

During development, the newer SMK069 work has been maintained primarily on:

```text
sync/smk069-csv-test-console-20260805
```

Historically, `main` was behind that development branch.

This recap is intentionally committed to both `main` and the active sync branch so the current project status is visible regardless of which branch is opened.

Before production source-of-truth cleanup, the exact final tenant SQL should be exported/synchronized and the branch/PR strategy should be finalized.

---

# PART G - NEXT PRIORITIES

## 29. Recommended next sequence

### Priority 1 - repository/runtime parity

1. Export exact tenant source currently confirmed working.
2. Synchronize exact `SMK069ReceivePosSalesJsonSp`.
3. Synchronize exact `SMK069ProcessCustomerOrderSp`.
4. Confirm whether Error Detail V2.3.1 is deployed.
5. Merge/reconcile the sync branch with `main`.

### Priority 2 - inbound error self-service UI

1. Add Inbound/API Validation view/tab/form.
2. Show raw Receive failures and `validation_msg`.
3. Make BatchId/cust_po searchable.
4. Keep Process/Reprocess restricted to temp records.

### Priority 3 - Shipment outbound

1. Apply/verify Shipment API flag fields.
2. Build `SMK069_ShipmentAPI_mst`.
3. Resolve final warehouse and UOM mapping.
4. Build JSON grouped by `shipment_id`.
5. Implement POS login/token handling.
6. Implement Shipment POST sender.
7. Update shipment API flag only after successful complete shipment.
8. Add retry/error logging.
9. Add Shipment Error Processing UI.
10. Add adjustable hourly scheduler.

---

## 30. Final status statement through 31 Aug 2026

The inbound POS-to-SyteLine Customer Order integration has progressed from a generic customer-order V2 contract into a tested outlet-aware integration.

The following end-to-end path has been demonstrated successfully:

```text
POS Outlet/Order
-> raw inbound
-> Outlet Code mapping
-> actual customer/cust_seq resolution
-> warehouse mapping
-> U/M validation
-> mapped-customer pricing
-> generated SyteLine co_num
-> temp
-> Process
-> Blanket co_mst
-> coitem_mst
-> co_bln_mst
```

The latest confirmed successful Blanket CO is:

```text
R260822004
```

for:

```text
cust_po     = POS08280002
customer    = PHR0001
cust_seq    = 1
```

The next major functional workstream is Shipment outbound from SyteLine to the POS Outlet API, while repository/runtime parity and inbound-error self-service visibility should be completed in parallel.

---

## 31. Source references

Project source material used for this recap:

1. **SMK069 POS - Infor SyteLine Customer Order Integration, API Contract V2** - UAT confirmed 27 Aug 2026.
2. **SMK - SPESIFIKASI API SHIPMENT / MF_SMK_API_SHIPMENT_REV_1.1** - shipment outbound requirement.
3. Development/UAT records from 28-31 Aug 2026.
4. Repository artifacts under `youhunt/api-pos-syteline`.

Sensitive API credentials/tokens are intentionally excluded from this document.

---

## Addendum — 1 September 2026: Customer Item Mapping / Price Lookup Revision

A new business requirement changes the meaning of the POS `item` field.

Previously the runtime logic treated payload `item` as the SyteLine internal
item. The revised requirement says payload `item` must be treated as the
customer item code and mapped through `itemcust_mst`.

Required lookup:

```sql
SELECT TOP 1
    ...
FROM itemcustprice_mst AS ic
INNER JOIN itemcust_mst AS i
    ON i.site_ref = ic.site_ref
   AND i.item = ic.item
   AND i.cust_num = ic.cust_num
WHERE ic.site_ref = @SiteRef
  AND i.site_ref = @SiteRef
  AND @order_date >= ic.effect_date
  AND i.cust_item = @POSItem
  AND i.u_m = @UM
  AND ic.cust_num = @MappedCustNum
ORDER BY ic.effect_date DESC, ic.RecordDate DESC;
```

Required semantics:

```text
inbound.item = raw POS/customer item code
temp.item    = itemcust_mst.item (mapped SyteLine internal item)
unit_price   = itemcustprice_mst price for mapped customer/internal item
```

SiteRef must be applied to both `itemcust_mst` and
`itemcustprice_mst`.

Status as of this addendum:

```text
Requirement confirmed: YES
SQL revision prepared: YES
Tenant Apply/UAT: PENDING
```

Shipment outbound work remains the next workstream after this inbound mapping
change is applied and verified.


---

## Addendum — 1 Sep 2026: Customer Item Validation / Pricing Feedback

Additional feedback requires POS `item` to be treated as
`itemcust_mst.cust_item`.

Current required flow:

```text
POS item (cust_item)
-> itemcust_mst by SiteRef + mapped cust_num + cust_item + u_m
-> mapped internal itemcust_mst.item
-> itemcustprice_mst by SiteRef + mapped cust_num + internal item + effective date
-> temp.item = mapped internal item
-> temp.unit_price = resolved server price
```

Price query must join `itemcustprice_mst` to `itemcust_mst` and must be
SiteRef-aware.

The validation layer should avoid cascaded item/price errors when the
Outlet/Store Code mapping itself failed. For example, when outlet `DEV4`
cannot be resolved in `custaddr_mst`, that root cause should be reported
without misleading downstream price errors that depend on a mapped customer.

Prepared SQL revision:

```text
SMK069ReceivePosSalesJsonSp V2.3.3 - Customer Item Mapping Feedback
```

Deployment/UAT of V2.3.3 should be confirmed separately from this documentation update.


## Addendum 1 Sep 2026 - DEV4 proves customer prefix must be dynamic

A tenant lookup for POS Outlet/Store Code `DEV4` returned:

```text
site_ref = Default
cust_num = PHD0001
cust_seq = 164
name     = DEV4 ...
```

This confirms that Receive must **not** hardcode `custaddr_mst.cust_num LIKE 'PHR%'`. The outlet lookup now uses SiteRef + `cust_seq <> 0` + `LEFT(name,4)=POS custnum`, and the resulting SyteLine customer prefix is fully data-driven.


---

## Addendum 2026-09-01 - Canonical inbound mapping view

The runtime design was simplified after confirmation from the functional team that
`dbo.ue_SMK069_pos_sales_inbound_mapping_view` is the intended canonical mapping
layer.

### Revised Receive flow

```text
POS JSON
-> ue_SMK069_pos_sales_inbound_mst          (raw)
-> ue_SMK069_pos_sales_inbound_mapping_view (canonical mapping)
-> validation
-> generate co_num
-> ue_SMK069_temp_sales_mst
-> ProcessCustomerOrder
-> co_mst / coitem_mst / co_bln_mst
```

The Receive procedure must no longer maintain a separate customer/item/price
mapping engine that can disagree with the view.

Canonical values consumed from the mapping view include:

```text
cust_num
cust_seq
cust_po
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
```

Important data ownership:

```text
inbound.cust_num = raw POS outlet/store code
inbound.item     = raw POS/customer item code

temp.cust_num    = mapping_view.cust_num
temp.item        = mapping_view.item
temp.unit_price  = mapping_view.unit_price
```

`cust_seq` is still not added to temp. Process should retrieve the mapped
customer sequence from the canonical mapping view.

### DEV4 evidence

The mapping view confirmed:

```text
DEV4 -> cust_num PHD0001 / cust_seq 164
```

This demonstrated why the old independent Receive mapping could return a false
"outlet/store code DEV4 tidak ditemukan" while the canonical view had already
resolved the customer correctly.

### New Receive revision prepared

```text
SMK069ReceivePosSalesJsonSp
POS Contract V2.3.5 - Canonical Mapping View
```

This revision:

- preserves raw inbound values;
- uses the mapping view as the mapping source of truth;
- validates that exactly one canonical row exists per inbound row;
- validates that mapped `unit_price` is present;
- keeps atomic-order validation;
- generates `R + YYMM + 5-digit` co_num;
- inserts canonical mapped values into temp;
- appends row-level validation detail to Infobar;
- retains Mongoose-safe transaction/savepoint behavior.

Status at time of this addendum: **prepared for Apply/UAT; deployment confirmation
pending**.
