# TRN → PRD Delta — Same Batch Retry, Error History, Friendly POS-108

**Date:** 12 October 2026
**Scope:** CSV / POS inbound → Blanket Customer Order only
**Repository:** youhunt/api-pos-syteline

This is the single checklist for moving the current working TRN changes to PRD.

> Important: the existing PROD package dated 24 September 2026 is behind the current TRN for same-BatchId retry/history and the latest POS-108 message handling. Do not assume 02-deploy-canonical-runtime.sql already contains these October changes.

## 1. Current TRN behavior to preserve

### Failed request may be corrected with the SAME BatchId

Final behavior:

~~~
first request, same BatchId
→ validation fails
→ current inbound rows remain E

corrected request, same BatchId
→ previous E attempt archived
→ current failed batch removed safely
→ corrected payload inserted as a new current attempt
→ validation runs again
~~~

Safety rules:

~~~
- retry is allowed only when the existing current batch consists only of E rows
- never delete temp rows with process_status = P
- only safe V temp rows from the failed attempt may be cleaned
- if a Customer Order already exists, duplicate protection still applies
- cust_po remains the business idempotency key
~~~

### Error History

TRN now has a History tab on ue_SMK069APISalesErrorProcessing / SMK API SALES ERROR PROCESSING.

History shows current errors plus archived retry attempts.

Expected archive reasons:

~~~
CURRENT_ERROR
RETRY_SAME_BATCH
~~~

### Friendly POS-108

For a mapping row where ValidationStatus=N is actually caused by a quantity-multiple failure, the API must expose the business reason, not the internal mapping term.

Example:

~~~
[POS-108] Request ditolak. 1 baris bermasalah:
[cust_po=DEV4-1004]
Quantity tidak sesuai kelipatan U/M
[coline=1, item=AC20002B, qty_ordered=376.00000000,
 u_m=PCS, qty_hasil_konversi=25.06667, u_m_hasil=TRY]
~~~

The persisted inbound/history message must be consistent:

~~~
root invalid line  -> POS-108
valid sibling line -> POS-203
~~~

Do not expose ValidationStatus=N to the external POS caller for this proven quantity-multiple case.

## 2. Repository files that MUST be updated before PRD deployment

### A. Canonical SQL procedures — UPDATE

Path:

~~~
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonCoreSp.sql
~~~

Required delta:

~~~
- detect failed same-BatchId retry
- archive previous E attempt
- clean only safe temp V rows
- delete previous current inbound rows for that failed batch
- accept corrected payload under the same BatchId
- preserve existing idempotent behavior for non-failed/current successful batches
~~~

Current repository status on 12 Oct 2026: NOT YET SYNCED to the final TRN same-BatchId retry implementation.

Path:

~~~
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
~~~

Required delta:

~~~
- friendly POS-108 composition for quantity-multiple failures
- do not expose "ValidationStatus mapping" for that case
- count only the true root invalid line in the API message
- persist root line as POS-108
- persist valid sibling lines as POS-203
- leave all unrelated validation branches unchanged
~~~

Current repository status on 12 Oct 2026: PARTIALLY BEHIND TRN.

### B. New SQL history objects — ADD

Canonical table source to add:

~~~
database/tables/csv-to-co/ue_SMK069_pos_sales_inbound_hist.sql
~~~

Object:

~~~
dbo.ue_SMK069_pos_sales_inbound_hist
~~~

Purpose: immutable archive of previous failed attempts before same-BatchId retry.

Canonical view source to add:

~~~
database/views/csv-to-co/ue_SMK069_pos_sales_inbound_history_v.sql
~~~

Object:

~~~
dbo.ue_SMK069_pos_sales_inbound_history_v
~~~

Expected view semantics:

~~~
archived attempts from ue_SMK069_pos_sales_inbound_hist
UNION ALL
current inbound E rows as CURRENT_ERROR
~~~

Current repository status on 12 Oct 2026: MISSING.

### C. Mongoose IDO — ADD

Required IDO:

~~~
ue_SMK069PosSalesInboundHistory
~~~

Source:

~~~
dbo.ue_SMK069_pos_sales_inbound_history_v
~~~

Expected important properties:

~~~
HistoryKey
HistoryId
InboundId
SiteRef
SourceSystem
BatchId
RowNo
CustPo
OrderDate
CoNum
CoLine
Item
QtyOrdered
UM
Whse
InboundStatus
ValidationMsg
RawJson
AttemptNo
ArchivedDate
ArchiveReason
IsCurrent
~~~

The IDO is read-only.

Current repository status on 12 Oct 2026: MISSING — export verified TRN IDO before PRD import.

### D. Error Processing form — UPDATE FROM VERIFIED TRN EXPORT

Form:

~~~
ue_SMK069APISalesErrorProcessing
~~~

Use the verified TRN FormsAndObjects export as the migration source.

TRN form adds:

~~~
PrimaryDataSource:
V(fds_DataSource) V(fds_SC2)

Secondary collection:
OBJECT2(
  ue_SMK069PosSalesInboundHistory(
    CA(IGVR)
    OBJNAME(History)
    ORDERBY(ArchivedDate DESC, AttemptNo DESC, RowNo)
    LOCKMODE(Row)
  )
)

Notebook:
- Error Processing
- History

History grid datasource:
objects2

Refresh:
RefreshHistory -> object2

Events:
StdFormInitCompleted -> RefreshHistory()
StdFormRefresh       -> RefreshHistory()
~~~

The existing Preview / Validate / Process-Reprocess behavior must remain.

Current repository status on 12 Oct 2026:

~~~
FINAL TRN XML EXISTS OUTSIDE REPO
PRD XML is older and has no History tab
~~~

Repository artifact still to add:

~~~
forms/csv-to-co/exports/ue_SMK069APISalesErrorProcessing-TRN-2026-10-12.xml
~~~

### E. Public Receive IDO method — VERIFY IN PRD

Method:

~~~
SMK069ReceivePosSalesJsonSp
~~~

Required:

~~~
Transactional = False
~~~

Reason: the SQL layer owns the required transaction behavior and failed inbound/history must survive a business-error response.

Do not redeploy it as Transactional=True.

## 3. PROD deployment package files that must be regenerated

After canonical TRN SQL is synchronized, update:

~~~
deployment/csv-to-co/prod/02-deploy-canonical-runtime.sql
deployment/csv-to-co/prod/03-post-deploy-verify.sql
deployment/csv-to-co/prod/04-mongoose-metadata-checklist.md
deployment/csv-to-co/prod/05-prod-uat-checklist.md
deployment/csv-to-co/prod/MANIFEST.md
~~~

Required additions:

~~~
02:
- create/align inbound history table
- create/alter history view
- deploy final Core SP
- deploy final public Receive SP

03:
- verify history table exists
- verify history view exists
- verify Core contains same-Batch retry markers
- verify public Receive contains friendly POS-108 markers

04:
- add ue_SMK069PosSalesInboundHistory
- add History secondary collection/form parity
- keep Transactional=False

05:
- test first failure
- test same BatchId corrected retry
- verify attempt 1 archived
- verify current attempt changes
- verify no duplicate CO
- verify POS-108 external message
- verify persisted History POS-108/POS-203

MANIFEST:
- refresh hashes only after canonical sources are final
~~~

## 4. Recommended PRD deployment order

~~~
1. Backup/export current PRD objects
2. Deploy ue_SMK069_pos_sales_inbound_hist
3. Deploy ue_SMK069_pos_sales_inbound_history_v
4. Deploy final SMK069ReceivePosSalesJsonCoreSp
5. Deploy final SMK069ReceivePosSalesJsonSp
6. Import/resync ue_SMK069PosSalesInboundHistory IDO
7. Confirm public Receive Transactional=False
8. Import verified TRN ue_SMK069APISalesErrorProcessing form
9. Refresh Mongoose metadata/cache
10. Smoke-test History form
11. Run API UAT
~~~

Do not import the TRN form before the History IDO/view exists.

## 5. Minimum PRD UAT

### Test A — quantity invalid

Example:

~~~
AC20002B
qty = 376 PCS
mapped = 25.06667 TRY
~~~

Expected:

~~~
API    -> POS-108, one root line
History root line -> POS-108
History sibling   -> POS-203
No CO created
~~~

### Test B — corrected SAME BatchId

Send corrected quantity using the same failed BatchId.

Expected:

~~~
old failed attempt -> history / RETRY_SAME_BATCH
new attempt        -> evaluated from corrected payload
no duplicate CO
~~~

### Test C — successful replay

After a Customer Order already exists, another replay must not create a second CO.

## 6. Current go/no-go

As of 12 Oct 2026:

~~~
TRN functional behavior : READY / tested
TRN form export          : READY
PRD form baseline        : OLD (no History)
Repo canonical Core SP   : NEEDS SYNC
Repo canonical Receive SP: NEEDS SYNC
Repo history table/view  : MISSING
Repo History IDO export  : MISSING
PROD package             : NEEDS REGENERATION
~~~

Therefore:

> **NO-GO for PRD deployment from the repository package until the canonical SQL + History objects + IDO/form artifacts above are synchronized.**
