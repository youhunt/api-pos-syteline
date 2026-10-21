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

Current repository status on 12 Oct 2026: **ADDED TO REPO** (canonical history table + history view).

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

Current repository status on 12 Oct 2026: **IDO contract documented in repo; exact verified TRN Object Studio XML export is still pending before PRD import.**

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
FINAL TRN XML IS NOW SAVED IN REPO
PRD pre-History XML is also archived in repo for rollback/diff evidence
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
TRN form export          : READY / SAVED IN REPO
PRD form baseline        : OLD (no History)
Repo canonical Core SP   : NEEDS SYNC
Repo canonical Receive SP: NEEDS SYNC
Repo history table/view  : ADDED / READY FOR REVIEW
Repo History IDO export  : CONTRACT READY / EXACT TRN XML STILL PENDING
PROD package             : VERIFY/UAT UPDATED; RUNTIME 02 + MANIFEST STILL NEED REGENERATION
~~~

Therefore:

> **NO-GO for PRD deployment from the repository package until the canonical SQL + History objects + IDO/form artifacts above are synchronized.**


## 7. Repository progress update — History table/view

Completed in repository:

~~~
database/tables/csv-to-co/ue_SMK069_pos_sales_inbound_hist.sql
database/views/csv-to-co/ue_SMK069_pos_sales_inbound_history_v.sql
deployment/csv-to-co/prod/00c-create-core-physical-tables.sql
  -> now includes the history table
~~~

The history table creation intentionally clones the target tenant's inbound column
types from dbo.ue_SMK069_pos_sales_inbound_mst before adding:

~~~
history_id
original_inbound_id
attempt_no
archived_date
archive_reason
~~~

This avoids silently forcing an old repository validation_msg length onto a newer
tenant schema.

The history view exposes:

~~~
archived attempts -> archive_reason from history (e.g. RETRY_SAME_BATCH)
current E         -> CURRENT_ERROR
current T         -> SUCCESS
~~~

Do not regenerate/run the consolidated 02-deploy-canonical-runtime.sql yet from
the repository until the latest TRN Core/Receive procedure bodies are also
synchronized into canonical source. Running an older consolidated runtime after
the October database changes could overwrite the newer procedures.


## 8. Repository progress update — IDO/Form

Completed in repository:

~~~
ido/csv-to-co/03-ue_SMK069PosSalesInboundHistory.md
forms/csv-to-co/exports/ue_SMK069APISalesErrorProcessing-TRN-2026-10-12.xml
forms/csv-to-co/exports/ue_SMK069APISalesErrorProcessing-PRD-before-history-2026-10-12.xml
forms/csv-to-co/exports/README.md
~~~

The exact working TRN form is now preserved as the PRD migration source, and the
old PRD form is preserved as rollback/diff evidence.

Remaining Mongoose gap:

~~~
exact Object Studio XML export of:
ue_SMK069PosSalesInboundHistory
~~~

Until that exact IDO export is captured, use the repository IDO document only as
the contract/reference; do not hand-build a different PRD-only IDO when the
verified TRN object can be exported.


## 9. Repository progress update — verification/UAT

Completed:

~~~
deployment/csv-to-co/prod/03-post-deploy-verify.sql
  -> verifies history table/view
  -> verifies same-Batch retry markers
  -> verifies friendly POS-108 markers
  -> verifies History view columns

deployment/csv-to-co/prod/05-prod-uat-checklist.md
  -> History tab/load/refresh test
  -> corrected retry using SAME failed BatchId
  -> archive/current attempt verification
  -> friendly POS-108 API/History parity test
~~~

Still pending before final PRD package is regenerated:

~~~
1. synchronize exact verified TRN SMK069ReceivePosSalesJsonCoreSp into canonical source
2. synchronize exact verified TRN SMK069ReceivePosSalesJsonSp into canonical source
3. capture exact Object Studio XML for ue_SMK069PosSalesInboundHistory
4. regenerate 02-deploy-canonical-runtime.sql
5. refresh MANIFEST hashes
~~~


## 10. Patch 36 — Urgent flag (14 Oct 2026)

New TRN/DEV change that must be folded into the PRD package when it is regenerated. Reference: `docs/csv-to-co/50-urgent-flag.md`.

~~~
Patch                : database/patches/csv-to-co/2026-10-14-smk069-36-urgent-flag.sql
Canonical (repo)     : SMK069ReceivePosSalesJsonCoreSp.sql    (2 PATCH-36 blocks, on top of the 24 Sep source)
                       SMK069ProcessCustomerOrderSp.sql        (both co_bln_mst INSERTs)
Mongoose             : UET on co_bln_mst (see 04-mongoose-metadata-checklist.md) + Blanket Line form fields
~~~

Because the repo Core is still behind TRN (section 6), Patch 36 was written to edit the **live** definition in place. When the verified TRN Core is synchronized into canonical source, keep the two `PATCH-36` blocks (search for the marker) and re-check they are still anchored at:

~~~
block 1: before section "3. Snapshot BUSINESS SOURCE from mapping view" (before #MapView)
block 2: right after the INSERT into ue_SMK069_temp_sales_mst / SET @TransferredRows = @@ROWCOUNT;
~~~

Still to fold into the regenerated PRD package:

~~~
00c-create-core-physical-tables.sql : add is_urgent INT NOT NULL DEFAULT 0 and urgent_remark NVARCHAR(255) NULL
                                      to ue_SMK069_pos_sales_inbound_mst and ue_SMK069_temp_sales_mst
02-deploy-canonical-runtime.sql     : regenerate with Core + ProcessCustomerOrder containing PATCH-36
01-preflight.sql                    : require co_bln_mst.Uf_SMK069_is_urgent / Uf_SMK069_urgent_remark
03-post-deploy-verify.sql           : markers "INTO #SMK069Urgent", "PATCH-36 Urgent flag - bawa is_urgent",
                                      "Uf_SMK069_is_urgent" in ProcessCustomerOrder; physical columns inbound/temp/co_bln_mst
05-prod-uat-checklist.md            : UAT U1-U9 from docs/csv-to-co/50-urgent-flag.md
MANIFEST.md                         : refresh blob hashes
~~~

Repository status on 14 Oct 2026: patch + canonical edits + docs added; **not yet executed on any tenant**.


## 11. Patch 37 — Urgent flag on the CSV path (14 Oct 2026)

Also to fold into the regenerated PRD package, together with section 10. Reference: `docs/csv-to-co/50-urgent-flag.md`, section "Jalur CSV — Patch 37".

~~~
Patch                : database/patches/csv-to-co/2026-10-14-smk069-37-urgent-flag-csv.sql   (requires Patch 36)
Canonical (repo)     : database/stored-procedures/csv-to-co/SMK069ImportCsvFileSp.sql    (7 PATCH-37 edits)
                       database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql          (1 PATCH-37 edit)
Mongoose             : resync IDO ue_SMK069PosCsvUpload; CSV console grid columns Is Urgent / Urgent Remark
~~~

~~~
00c-create-core-physical-tables.sql : ue_SMK069_pos_csv_upload_mst gets is_urgent INT NOT NULL DEFAULT 0 and urgent_remark NVARCHAR(255) NULL
02-deploy-canonical-runtime.sql     : regenerate with the PATCH-37 versions of ImportCsvFileSp and RunCsvTestBatchSp
03-post-deploy-verify.sql           : markers "@ParsedUrgent" (ImportCsvFileSp) and "AS urgent_remark" (RunCsvTestBatchSp)
05-prod-uat-checklist.md            : UAT C1-C6 from docs/csv-to-co/50-urgent-flag.md
~~~

The CSV upload path was listed as "not included" in section 10; it is now covered by Patch 37. Status: patch + canonical edits + docs added; **not yet executed on any tenant**.


## 12. Patch 38 — Urgent flag on coitem_mst (14 Oct 2026)

Also to fold into the regenerated PRD package. Reference: `docs/csv-to-co/50-urgent-flag.md`, section "Form Customer Order Blanket Releases — Patch 38".

~~~
Patch                : database/patches/csv-to-co/2026-10-14-smk069-38-urgent-flag-coitem.sql   (requires Patch 36 + coitem_mst UET)
Canonical (repo)     : SMK069ProcessCustomerOrderSp.sql   (PATCH-38: INSERT INTO dbo.coitem_mst carries the two UET fields)
Mongoose             : UET on coitem_mst (class SMK069_CL_coitem) + Impact Schema; form Customer Order Blanket Releases fields (IDO SLCoitems properties coiUf_SMK069_is_urgent / coiUf_SMK069_urgent_remark; XML: forms/csv-to-co/exports/ue_SMK069_BlanketReleases-DEV-urgent-2026-10-14.xml)
~~~

~~~
01-preflight.sql                    : require coitem_mst.Uf_SMK069_is_urgent / Uf_SMK069_urgent_remark
02-deploy-canonical-runtime.sql     : regenerate with ProcessCustomerOrderSp containing PATCH-36 and PATCH-38
03-post-deploy-verify.sql           : marker "PATCH-38" and >= 3 occurrences of "Uf_SMK069_is_urgent" in ProcessCustomerOrderSp
05-prod-uat-checklist.md            : UAT R1-R4 from docs/csv-to-co/50-urgent-flag.md
~~~

Status: patch + canonical edit + docs added; **not yet executed on any tenant**.


## 13. Patch 39 — CHECK constraint batch_status allows 'P' (14 Oct 2026)

Found in TRN during Urgent UAT: a CSV batch that mixes a duplicate `cust_po` (POS-204) with a new one is a legitimate PARTIAL, so `SMK069RunCsvTestBatchSp` closes it with `batch_status = 'P'`. The TRN constraint `CK_SMK069CsvBatch_Status` only allowed `D, R, C, E`, so the closing UPDATE failed with 547, the CATCH block overwrote the status with `E` and the message with `[POS-999] ... gagal 547`, although the valid order had already become a Customer Order.

The constraint definition is not in the repo (`00c-create-core-physical-tables.sql` creates the table without it), so PRD may or may not have it.

~~~
Patch      : database/patches/csv-to-co/2026-10-14-smk069-39-csv-batch-status-partial.sql   (independent of 36-38)
Behaviour  : constraint missing -> no-op; already contains 'P' -> no-op; otherwise DROP + ADD with D, R, C, P, E in one transaction
PRD check  : SELECT definition FROM sys.check_constraints WHERE name = N'CK_SMK069CsvBatch_Status'
~~~

Status: patch added; **not yet executed on any tenant** (TRN needs it; run it before further CSV UAT).


## 14. Patch 40 — Friendly POS-108 for PRD (21 Oct 2026)

Observed on 20 Oct 2026: the same quantity-multiple failure is shown as `[POS-108] Quantity tidak sesuai kelipatan U/M ... Material Code` in TRN and as `[POS-109] ... Item/CustPO tidak valid berdasarkan ValidationStatus mapping` (both lines) in PRD.

Evidence collected on 20-21 Oct 2026:

~~~
Definition length (chars)      PRD      TRN
SMK069ReceivePosSalesJsonSp    37,747   47,779   TRN only contains "qty_hasil_konversi"
SMK069ReceivePosSalesJsonCoreSp 47,773  57,088
SMK069ProcessBatchCustomerOrdersSp 6,650 7,019
SMK069ProcessCustomerOrderSp   29,714   30,265
mapping view                    2,736    1,857   same logic, formatting only (compared ignoring whitespace/case)
~~~

- The PRD and TRN mapping views are logically identical. The PRD view is the reformatted repo file, so its SHA-256 differs from the original SMK text even though `ValidationStatus` is computed identically. `ValidationStatus = N` therefore means only "converted quantity is not a whole number" in both tenants, and the PRD POS-109 in the screenshot is a quantity-multiple failure.
- The TRN `SMK069ReceivePosSalesJsonSp` (script-out supplied 21 Oct 2026) equals the repo canonical file plus ONE additive block, "PATCH: Friendly POS-109 API message" (about 250 lines), placed inside `IF @BusinessError = 1` before the `PATCH-34` comment. Nothing else differs after whitespace normalization. The TRN Receive contains no Urgent code (Patches 36-38 live in Core and ProcessCustomerOrder).
- The block reads only the inbound table and the mapping view, and writes only `validation_msg`. It does not depend on Core, ProcessBatch, History objects or Mongoose metadata.

~~~
Patch      : database/patches/csv-to-co/2026-10-21-smk069-40-friendly-pos108.sql
Behaviour  : edits the LIVE Receive definition in place (anchor "PATCH-34: synthesize POS-204 ..." must occur exactly once);
             already contains "Friendly POS-109 API message" -> SKIP (so it is a no-op in TRN);
             anchor missing/duplicated -> THROW 510446 and nothing changes; one transaction; post-check 510448-510450
Canonical  : database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql now equals the TRN definition (normalized)
Verified   : simulated against the old canonical text (LF and CRLF, CREATE and CREATE OR ALTER headers) -> result equals TRN;
             simulated against the TRN text -> SKIP.  Not executed on SQL Server.
~~~

Scope warning: this closes only the message difference of the API response. The rest of the TRN-to-PRD delta (Core +9,315 chars, ProcessBatch +369, ProcessCustomerOrder +551, History objects, IDO/form, same-BatchId retry) is NOT covered; sections 1-9 still apply. Do not regenerate `02-deploy-canonical-runtime.sql` from the repo until Core and ProcessBatch are synchronized from TRN.

PRD steps:

1. Script out the PRD `SMK069ReceivePosSalesJsonSp` as a rollback copy.
2. Run Patch 40 (Apply Database, one batch). Expect `[PATCH-40] OK diperbarui` and `SUCCESS`.
3. Re-run `08-urgent-flag-precheck-verify.sql`: the row `SMK069ReceivePosSalesJsonSp Friendly POS-109 API message` must be OK.
4. Test A of section 5 with a NEW `cust_po` and a NEW BatchId (a `cust_po` already registered gives POS-204): AC20002B with a quantity that is not a multiple. Expect `[POS-108] Request ditolak. 1 baris bermasalah: [cust_po=...] Quantity tidak sesuai kelipatan U/M [coline=..., item=AC20002B, qty_ordered=..., u_m=..., qty_hasil_konversi=..., u_m_hasil=...]`, no Customer Order created, History root POS-108 / sibling POS-203.

Status: patch + canonical sync + docs added; **not yet executed on any tenant**.
