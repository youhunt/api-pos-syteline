# SMK069 Current Handoff — POS Inbound Stable + Shipment Outbound In Progress

> **Prepared:** 3 September 2026  
> **Repository:** `youhunt/api-pos-syteline`  
> **Purpose:** single handoff document so development can be resumed in a new ChatGPT/session without rebuilding project context from scratch.  
> **Previous recap:** `docs/23-smk069-development-recap-through-2026-08-31.md`

---

## 1. Executive status

| Area | Status | Current position |
|---|---|---|
| POS inbound -> SyteLine Customer Order | ✅ Stable | Do not redesign unless a regression is found |
| Stable result-code contract | ✅ Stable | Existing `POS-xxx` contract preserved |
| POS site-aware hardening | ✅ Prepared / applied path | V2 patch made Mongoose Apply Database safe |
| Shipment UET fields | ✅ Implemented | `SMK069_Uf_api_post`, `SMK069_Uf_api_post_date` |
| Shipment API view | ✅ Current design | `SMK069_ShipmentAPI_mst`, must expose `site_ref` |
| Shipment JSON builder | ✅ Implemented | `SMK069BuildShipmentJsonSp` |
| Shipment prepare/log | ✅ Implemented | `SMK069PrepareShipmentSendSp` |
| Shipment complete/result | ✅ Implemented | `SMK069CompleteShipmentSendSp` |
| Shipment API log | ✅ Designed/created | `ue_SMK069_shipment_api_log_mst` |
| Shipment form UAT | ✅ Preview/Prepare available | UAT/debug only, not production scheduler |
| Actual HTTP POST sender | ⏳ Pending | Must become server-side production sender |
| POS Shipment endpoint/auth | ⏳ Pending | Exact URL/auth/response contract not yet confirmed |
| Scheduler | ⏳ Pending | Must run automatically every 1 hour by default; interval adjustable |
| Retry/error flow | 🟡 Foundation exists | Log statuses N/S/E, final sender/retry still required |

---

## 2. Non-negotiable production requirement

The Shipment requirement is:

> Shipment data from SyteLine must be sent to the POS Outlet API automatically on a schedule every **1 hour** by default, and the interval must be changeable.

Therefore:

- the production mechanism must **not depend on a user opening a form**;
- the form is only for UAT/debug/manual verification;
- the final sender must be server-side;
- scheduling must be configuration-driven, not implemented with `WAITFOR DELAY` inside SQL;
- the default schedule is hourly;
- the interval must be adjustable without changing the business stored procedures.

Target production flow:

```text
Scheduled job (default every 1 hour)
        |
        v
Resolve active Site
        |
        v
Find pending shipments for that Site
        |
        v
Build JSON
        |
        v
Prepare outbound log
        |
        v
POST to POS API
     /       \
 SUCCESS    FAILED
    |          |
    v          v
Log = S      Log = E
api_post=1   api_post remains 0
post_date    retry_count + 1
```

---

# PART A — POS INBOUND BASELINE

## 3. POS inbound is considered stable

The POS inbound direction is:

```text
POS
-> Receive JSON
-> raw inbound
-> canonical mapping view
-> validation
-> server-side price
-> generated SyteLine co_num
-> temp
-> Process Customer Order
-> co_mst / coitem_mst / co_bln_mst
```

The current stable package used as the base of the site-aware hardening is:

```text
Receive Core   V2.4.8
Public Receive V2.4.8
Run CSV        V2.8.1
Process CO     V2.8.3
E2E            V1.3
```

The older discussion/version labels may mention V2.4.7 / V2.8 / V2.8.2, but the V4 hardening package is based on the versions above.

Important existing behavior must remain unchanged:

- POS sends `cust_po`, not the final SyteLine `co_num`;
- SyteLine generates `co_num`;
- pricing is resolved server-side;
- the canonical mapping source is `ue_SMK069_pos_sales_inbound_mapping_view`;
- one atomic POS order is identified by `SiteRef + cust_po`;
- the existing `POS-xxx` result/error-code contract must be preserved;
- do not change API/IDO method signatures without an explicit requirement.

---

## 4. POS site-aware hardening

A site-aware patch was prepared on 3 Sep 2026:

```text
SMK069_POS_SiteAware_Hardening_Apply_20260903_v2.sql
```

The V2 revision fixes the Mongoose Apply Database compile-order problem that occurred when a new CSV `SiteRef` column was added and referenced in the same SQL batch.

The patch base header is:

```text
Core V2.4.8
Public V2.4.8
Process V2.8.3
CSV V2.8.1
E2E V1.3
```

### Site context standard

All new/hardened SMK069 procedures use:

```sql
DECLARE @Site SiteType
SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
EXEC SetSiteSp @Site, NULL
```

The application must scope reads/writes so data from multiple sites in the same CSI database cannot mix.

Examples:

```sql
WHERE site_ref = @Site
```

or for custom tables:

```sql
WHERE SiteRef = @Site
```

Logical keys that previously looked global must be considered site-scoped, for example:

```text
SiteRef + BatchId
SiteRef + cust_po
SiteRef + co_num
```

### SP audit list from 3 Sep 2026

Shipment procedures already showed Site Context:

```text
SMK069BuildShipmentJsonSp       YES
SMK069CompleteShipmentSendSp    YES
SMK069PrepareShipmentSendSp     YES
```

The POS/CSV procedures were then targeted by the V2 hardening patch:

```text
SMK069ConfirmCsvUploadSp
SMK069ImportCsvFileSp
SMK069InitializeCsvTestBatchSp
SMK069ProcessCustomerOrderSp
SMK069ReceiveAndProcessPosSalesJsonSp
SMK069ReceivePosSalesJsonCoreSp
SMK069ReceivePosSalesJsonHttpSp
SMK069ReceivePosSalesJsonSp
SMK069RunCsvTestBatchSp
SMK069ValidateCustomerSp
SMK069ValidateFilteredStagingSp
```

Audit query:

```sql
SELECT
    p.name AS procedure_name,
    CASE
        WHEN m.definition LIKE '%CONTEXT_INFO%'
            THEN 'YES'
        ELSE 'NO'
    END AS HasSiteContext,
    CASE
        WHEN m.definition LIKE '%''DEFAULT''%'
            THEN 'CHECK'
        ELSE 'OK'
    END AS HasDefaultLiteral
FROM sys.procedures p
JOIN sys.sql_modules m
    ON m.object_id = p.object_id
WHERE p.name LIKE 'SMK069%'
ORDER BY p.name;
```

A `HasDefaultLiteral = CHECK` result is not automatically an error; the actual use of the literal must be reviewed.

---

# PART B — SHIPMENT REQUIREMENT AND DATA MODEL

## 5. Shipment outbound direction

The new direction is the reverse of POS inbound:

```text
SyteLine Shipment
-> build POS Shipment JSON
-> send to POS Outlet API
-> receive response
-> mark shipment posted only after confirmed success
```

Source requirement:

```text
MF_SMK_API_SHIPMENT_REV_1.1
Issued 26 Aug 2026
```

The source document specifies the hourly/adjustable schedule and the Shipment payload mapping.

---

## 6. Shipment UET fields

Extended table:

```text
shipment_mst
Class: SMK069_CL_Shipment
```

UET fields:

```text
SMK069_Uf_api_post       int
SMK069_Uf_api_post_date  datetime
```

Physical fields were verified.

Historical NULL flags were normalized with:

```sql
UPDATE shipment_mst
SET SMK069_Uf_api_post = 0
WHERE SMK069_Uf_api_post IS NULL;
```

Meaning:

```text
NULL/0 = pending / not successfully posted
1      = successfully posted
```

Code should continue using:

```sql
ISNULL(SMK069_Uf_api_post, 0)
```

defensively.

---

## 7. Shipment view

Current view name:

```text
dbo.SMK069_ShipmentAPI_mst
```

The view must expose:

```text
site_ref
cust_code
whse_code
doc_no
DN_No
Delivery_date
Store_Order_No
store_code
Vehicle_number
product_code
shipment_qty
UOM
Price
Batch
Expiry_date
Api_post
Api_post_date
```

All Shipment procedures must filter the view by the active site:

```sql
WHERE site_ref = @Site
```

Important Mongoose Query Execution Form note:

- do not put a normal `ORDER BY` inside the view just to control form display;
- ordering required for JSON DETAIL should be applied inside the JSON subquery.

---

## 8. Confirmed Shipment joins

Confirmed Customer Order linkage:

```text
coitem.co_num     = shipment_line.ref_num
coitem.co_line    = shipment_line.ref_line_suf
coitem.co_release = shipment_line.ref_release
```

All relevant joins must also include `site_ref`.

Confirmed detail mapping:

```text
PRODUCT_CODE = coitem.item
SHIPMENT_QTY = shipment_seq.qty_shipped
UOM          = coitem.u_m
PRICE        = coitem.price
BATCH        = shipment_seq.lot
EXPIRY_DATE  = lot.exp_date
```

A single shipment line can split into multiple lots. The JSON DETAIL must preserve that lot-level granularity.

Do **not** aggregate different batches into one detail row.

---

## 9. Multiple DOC_NO protection

Historical data proved that one `shipment_id` can reference more than one Customer Order / DOC_NO.

Example:

```text
shipment_id = 1
-> references multiple COs
```

Therefore the JSON builder intentionally rejects a Shipment with more than one distinct nonblank `doc_no`.

Do not use `TOP 1` to silently pick an arbitrary header.

---

## 10. Known Shipment test data

Useful UAT examples recorded during development:

### DN 22 — positive JSON case

```text
DN                = 22
cust_num          = C000001
whse              = PLG
doc_no            = CG26080002
Store_Order_No    = RRO/2608/002
Vehicle           = B 1212 KKG
item              = AA00024
UOM               = CTN
price             = 5000
```

Lot-level quantities:

```text
12  batch 260812-002-1B-0
6   batch 260812-003-1B-0
3   batch 260813-008-2A-0
9   batch 260814-015-1C-0
```

This case successfully produced a JSON preview.

### DN 24 — negative qty case

```text
DN = 24
shipment_qty = 0 for all rows
ship_date blank
```

Expected result: JSON builder rejects because no detail has `shipment_qty > 0`.

### DN 1 — multiple document case

Expected result: JSON builder rejects because more than one DOC_NO is associated with the shipment.

---

# PART C — SHIPMENT STORED PROCEDURES

## 11. Site-aware standard for every Shipment SP

Every Shipment SP must contain:

```sql
DECLARE @Site SiteType
SELECT @Site = RTRIM(CONVERT([nvarchar](8), CONTEXT_INFO(), (0)))
-- SELECT @Site = 'default'
EXEC SetSiteSp @Site, NULL
```

and every `_mst` table access must be scoped to that active site.

For custom log data:

```sql
WHERE SiteRef = @Site
```

Shipment logical idempotency key:

```text
SiteRef + ShipmentId
```

not just `ShipmentId`.

---

## 12. SMK069BuildShipmentJsonSp

Purpose:

```text
Shipment ID
-> validate pending shipment
-> validate quantity
-> validate one DOC_NO
-> build one Shipment JSON object
-> preserve lot-level DETAIL
```

Current behavior:

- only reads the active site;
- rejects missing/already-posted Shipment;
- rejects Shipment with no quantity greater than zero;
- rejects no DOC_NO;
- rejects more than one DOC_NO;
- validates required header fields;
- validates PRODUCT_CODE;
- preserves batch/lot-level rows;
- blank STORE_CODE is currently a warning, not a hard failure.

Example successful DN22 payload shape:

```json
{
  "CUST_CODE": "C000001",
  "WHS_CODE": "PLG",
  "DOC_NO": "CG26080002",
  "DN_NO": "22",
  "DELIVERY_DATE": "2026-08-19",
  "STORE_ORDER_NO": "RRO/2608/002",
  "STORE_CODE": "Del",
  "VEHICLE_NUMBER": "B 1212 KKG",
  "DETAIL": [
    {
      "PRODUCT_CODE": "AA00024",
      "SHIPMENT_QTY": 12,
      "UOM": "CTN",
      "PRICE": 5000,
      "BATCH": "260812-002-1B-0",
      "EXPIRY_DATE": null
    }
  ]
}
```

The actual payload contains all qualifying detail rows, not only the single example row above.

---

## 13. Outbound log

Table:

```text
dbo.ue_SMK069_shipment_api_log_mst
```

Business columns:

```text
ShipmentId
EndpointUrl
RequestDate
RequestJson
ResponseDate
ResponseHttpCode
ResponseJson
ProcessStatus
ErrorMessage
RetryCount
```

Mongoose standard columns include:

```text
CreatedBy
UpdatedBy
CreateDate
RecordDate
RowPointer
NoteExistsFlag
InWorkflow
SiteRef
```

`RowPointer` is the primary key.

Current status codes:

```text
N = New / ready
S = Success
E = Error
```

Potential future states may include `P` (Processing) and `R` (Retry), but they are not required for the current minimum flow.

---

## 14. SMK069PrepareShipmentSendSp

Purpose:

```text
Shipment ID
-> Build JSON
-> validate
-> create outbound log status N
-> return LogRowPointer + payload
```

Current behavior:

- site-aware;
- checks Shipment belongs to active Site;
- delegates JSON construction to `SMK069BuildShipmentJsonSp`;
- does not create a log if payload creation fails;
- if the same `SiteRef + ShipmentId` already has a NEW log, returns the existing log/payload instead of creating a duplicate;
- snapshot Endpoint URL can be stored on the log.

Important:

```text
Prepare != Posted
```

Do not set `shipment_mst.SMK069_Uf_api_post = 1` during Prepare.

---

## 15. SMK069CompleteShipmentSendSp

Purpose:

```text
Log RowPointer + HTTP/business result
-> update outbound log
-> update Shipment posted flag only on confirmed success
```

Success path:

```text
log.ProcessStatus = S
log.ResponseDate / HttpCode / ResponseJson populated
shipment.SMK069_Uf_api_post = 1
shipment.SMK069_Uf_api_post_date = GETDATE()
```

Failure path:

```text
log.ProcessStatus = E
RetryCount = RetryCount + 1
shipment remains pending
```

Safety rule:

- a failed attempt must never reset a Shipment that was already successfully posted.

---

# PART D — FORM UAT STATUS

## 16. SMK SHIPMENT API TEST

The Shipment form is an UAT/debug tool only.

Existing useful actions:

```text
Preview JSON
Prepare Send
```

The form has already demonstrated:

- DN22 positive JSON preview;
- pretty-printed payload;
- Prepare Send returning an outbound Log ID.

An experiment was started to add a direct FormScript HTTP POST button.

### Decision as of 3 Sep 2026

Do **not** treat the direct FormScript HTTP sender experiment as the production baseline.

The project direction remains:

```text
Form = UAT/debug
Server-side sender = production
Scheduler = automatic production execution
```

The FormScript experiment can be revisited if a one-shipment connectivity test is useful, but it must not delay the server-side sender/scheduler.

---

# PART E — OPEN MAPPINGS / EXTERNAL CONTRACT

## 17. WHS_CODE is not finalized

The source Shipment requirement contains an ambiguous/invalid draft expression similar to:

```sql
IIF(sh.whse,'R963','R975')
```

because the first argument of SQL Server `IIF` must be a Boolean condition.

Current DN22 preview showed:

```text
WHS_CODE = PLG
```

Do not assume `PLG` is the final POS warehouse code.

Final SyteLine -> POS warehouse conversion must be confirmed before production.

---

## 18. STORE_CODE needs final source confirmation

The requirement references `customer_mst.cust_type`, while development also identified the canonical POS inbound mapping view as a possible reverse source for POS store/outlet information.

DN22 preview showed:

```text
STORE_CODE = Del
```

Do not hardcode this value.

The final STORE_CODE derivation should be verified against the functional requirement/master data before production.

---

## 19. Endpoint, authentication, and response contract are not yet confirmed

The Shipment requirement does not provide enough information to finalize:

- production endpoint URL;
- authentication mechanism;
- exact success response;
- exact error response;
- whether HTTP 2xx alone means business success;
- partial-detail failure semantics.

Therefore:

- never hardcode a production URL/token into SQL or source files;
- do not mark a Shipment as posted based only on HTTP 200 until the POS business response contract is known;
- sensitive credentials must not be committed to this repository.

---

# PART F — NEXT IMPLEMENTATION SEQUENCE

## 20. Recommended next steps

Continue in this order.

### Step 1 — verify current tenant state

Re-run the SMK069 site-context audit and confirm all intended POS/CSV + Shipment SPs show `HasSiteContext = YES`.

Also verify the Shipment view exposes `site_ref`.

### Step 2 — finalize Shipment endpoint contract

Obtain from POS team:

```text
UAT endpoint
Production endpoint
Authentication
Headers
Example success response
Example business-error response
HTTP status behavior
Duplicate DN behavior
```

### Step 3 — build server-side one-Shipment sender

Create a server-side method that can:

```text
active Site
-> Build JSON
-> Prepare Send
-> HTTP POST
-> parse POS response
-> Complete Send
```

This method should be callable manually for one Shipment during UAT.

### Step 4 — build pending-batch sender

Create server-side batch orchestration, conceptually:

```text
SMK069SendPendingShipments
```

Responsibilities:

1. resolve active Site;
2. find pending Shipments for that Site;
3. send each Shipment independently;
4. continue after individual failures;
5. return a summary such as Candidate / Success / Failed / Skipped.

### Step 5 — schedule automatically

Configure a Mongoose/background scheduler:

```text
Default: every 1 hour
Adjustable: yes
```

Do not embed the interval in stored procedures.

### Step 6 — retry and operational visibility

Complete:

- failed-log retry rules;
- Shipment error/retry UI;
- duplicate protection;
- operational summary;
- final UAT matrix.

---

## 21. Suggested UAT matrix for Shipment

| Test | Scenario | Expected |
|---|---|---|
| S01 | Valid DN22-like shipment | JSON built and API request sent |
| S02 | Shipment qty all zero | Reject before HTTP |
| S03 | Multiple DOC_NO | Reject before HTTP |
| S04 | Already posted Shipment | Do not send again |
| S05 | HTTP/auth failure | Log E, Shipment remains pending |
| S06 | POS business error with HTTP 2xx | Log E, Shipment remains pending |
| S07 | Confirmed POS success | Log S, api_post=1, post date set |
| S08 | Retry prior failure | New/retry attempt controlled, no duplicate success |
| S09 | Same Shipment ID on different sites | No cross-site collision |
| S10 | Scheduled batch with mixed good/bad shipments | Good shipments succeed; bad ones logged; job continues |

---

# PART G — IMPORTANT DO-NOT-REDO NOTES

## 22. Do not reopen completed decisions unnecessarily

When resuming this project:

- do not redesign POS inbound from scratch;
- do not remove the stable `POS-xxx` result-code contract;
- do not generate a new `co_num` in Process if Receive already generated it;
- do not bypass the canonical inbound mapping view;
- do not remove SiteRef filtering from `_mst` operations;
- do not group Shipment lots/batches together;
- do not silently pick one DOC_NO when a Shipment references multiple documents;
- do not set Shipment posted flag during JSON Build or Prepare;
- do not make the form the production scheduler;
- do not hardcode production endpoint credentials;
- do not assume HTTP 200 equals POS business success until the response contract is confirmed.

---

## 23. Resume prompt for a future session

A future session can start with:

```text
Continue SMK069 API POS / Shipment SyteLine.

Use docs/24-smk069-current-handoff-2026-09-03.md as the current
source of truth.

POS inbound is stable. Do not redesign it.

Current focus is Shipment outbound:
- site-aware Build / Prepare / Complete SPs already exist
- outbound log already exists
- form is UAT/debug only
- production requirement is automatic scheduling every 1 hour by default,
  with adjustable interval
- next work is server-side one-Shipment HTTP sender, then pending batch sender,
  then scheduler/retry
- endpoint/auth/exact POS success-response contract still needs confirmation
- WHS_CODE and STORE_CODE final mapping still need confirmation

Continue incrementally and keep every Shipment _mst read/write scoped by active Site.
```

---

## 24. Current source-of-truth hierarchy

When documents conflict, use this order:

1. exact confirmed tenant behavior / latest UAT;
2. this handoff document;
3. stable result-code package V4 and the 3 Sep site-aware hardening V2;
4. `docs/23-smk069-development-recap-through-2026-08-31.md`;
5. older draft API documents.

Functional requirements from the signed/source Shipment specification remain authoritative for business intent, especially the automatic hourly/adjustable schedule.

---

## 25. Final status — 3 Sep 2026

POS inbound is stable enough to stop consuming development attention.

Shipment outbound has a solid SQL foundation:

```text
Shipment API flags
+ Site-aware view
+ Site-aware JSON builder
+ Site-aware Prepare
+ Site-aware Complete
+ outbound log
+ UAT form
```

The major remaining work is no longer data discovery; it is the transport/runtime layer:

```text
POS endpoint/auth contract
-> server-side HTTP sender
-> business-response parser
-> pending Shipment orchestration
-> retry
-> automatic hourly/adjustable scheduler
-> final UAT
```

That is the point from which development should resume.


---

## 26. Post-handoff progress — server-side transport foundation

A server-side Shipment HTTP transport foundation was added after this handoff
was originally prepared.

New source:

```text
extension-classes/SMK069ShipmentSenderExtension.cs
implementation/21-create-smk069-shipment-server-side-transport.md
database/patches/2026-09-03-smk069-shipment-production-readiness-audit.sql
tests/payloads/shipment-dn22-current-preview.json
```

Current status of the production path is now:

```text
Build JSON                 stable SQL
Prepare outbound log       stable SQL
Server-side HTTP transport implemented foundation
Complete result            stable SQL
One-Shipment orchestration next
Pending batch              pending
Hourly TaskMan schedule    pending
```

Safety behavior:

- the transport does not update Shipment or outbound log directly;
- blank/default success mode is `UNCONFIRMED`;
- HTTP 2xx alone does not produce `BusinessSuccess=1` in that mode;
- real endpoint credentials are runtime inputs and are not committed;
- the exact existing Build/Prepare/Complete parameter metadata must be read from
  the tenant audit before the final orchestration is wired.

The next implementation step is therefore no longer to write a Form HTTP
sender. It is:

```text
tenant metadata audit
+ POS endpoint/auth/response sample
-> one-Shipment server-side orchestration
-> pending batch
-> TaskMan hourly schedule
```


### Query Execution note

The original production-readiness audit was first written as one multi-result
SQL script. In SyteLine **Apply Database**, `SELECT` result sets are not
displayed like SSMS; Apply Database only reports execution status.

For tenant verification, use:

```text
database/patches/2026-09-03-smk069-shipment-production-readiness-query-execution.sql
```

Run each numbered `SELECT` block separately in **Query Execution**. The
queries are read-only and require no data change.

The most important result for the next code step is **Q3**, the exact parameter
metadata for:

```text
SMK069BuildShipmentJsonSp
SMK069PrepareShipmentSendSp
SMK069CompleteShipmentSendSp
```


### One-Shipment orchestration implemented after tenant metadata confirmation

Tenant Query Execution confirmed the exact Build/Prepare/Complete parameters,
`ShipmentViewSiteRefCheck = PASS`, and DN22 as four separate lot rows at Site
`Default`.

`SMK069ShipmentSenderExtension.cs` now includes:

```text
SMK069SendOneShipment
```

It executes:

```text
Prepare
-> server-side HTTP POST
-> Complete
```

Prepare is not duplicated by a separate Build call. HTTP/business failure still
runs Complete with `IsSuccess=0`, so the outbound attempt can be recorded as
error while the Shipment remains pending. Positive business success is never
generated from HTTP 2xx while `SuccessMode=UNCONFIRMED`.

Next gate: deploy/register the extension method and perform one-Shipment UAT
after the POS UAT endpoint/auth/response contract is available. Pending-batch
orchestration and hourly TaskMan scheduling follow that UAT.
