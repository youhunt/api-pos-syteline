# CSV / POS Inbound → Blanket Customer Order

## Scope

Modul ini hanya menangani inbound POS/CSV sampai menjadi **Blanket Customer Order type `B`** di SyteLine.

Shipment outbound, DN retry, TaskMan Shipment, dan endpoint Shipment berada di workstream `shipment` dan tidak boleh dicampur ke sini kecuali ada dependency nyata.

## Arsitektur aktif — 16 Sep 2026

Canonical public entry point:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Flow:

```text
POS JSON / CSV
→ SMK069ReceivePosSalesJsonSp
→ SMK069ReceivePosSalesJsonCoreSp
→ quantity validation
→ ue_SMK069_temp_sales_mst
→ SMK069ProcessBatchCustomerOrdersSp
→ SMK069ProcessCustomerOrderSp
→ co_mst + coitem_mst + co_bln_mst
```

IDO method tetap:

```text
Transactional = False
```

karena `SMK069ProcessCustomerOrderSp` memiliki transaction per order.

## Business identity — keputusan final 16 Sep 2026

Business linkage utama:

```text
cust_po
```

Contoh:

```text
cust_po = DEV4-233
```

Nomor teknis legacy `R...` bukan business key downstream.

Final semantics:

```text
cust_po    = business order identity / linkage
              contoh DEV4-233

co_num     = actual SyteLine Customer Order setelah processing sukses
              contoh P260916001

R...       = transient/legacy compatibility value sebelum sukses saja
```

Setelah Customer Order sukses:

```text
ue_SMK069_temp_sales_mst.co_num = actual SyteLine CO number
```

Tidak diperlukan field target CO terpisah sebagai source of truth.

## New CO numbering — Patch 24

Format baru:

```text
P + YYMMDD + 3-digit daily running
```

Example:

```text
P260916001
P260916002
```

Running reset per tanggal karena `YYMMDD` menjadi bagian prefix. Total panjang = 10 karakter.

Existing standard Customer Order **tidak direnumber**. Patch 24 hanya mengubah format CO baru dan relink staging historical ke nomor CO existing yang sudah terbentuk.

## Released Date — Patch 24

Rule final:

```text
coitem_mst.release_date = co_mst.order_date
```

Untuk CO baru nilai ditulis saat insert line. Untuk existing matching Blanket CO / historical integration rows, Patch 24 memperbaiki `release_date` yang NULL atau berbeda dari header `order_date`.

## Canonical Cust PO linkage — Patch 25

Patch 24 sudah memindahkan pending match ke `cust_po`, tetapi tenant processor masih membawa legacy `co_num` pada Batch → per-order call.

Patch 25 menutup gap itu:

```text
Batch discovery / pending -> cust_po
Batch cursor              -> cust_po
Batch -> per-order call   -> cust_po
Per-order staging reads   -> cust_po
Per-order staging updates -> cust_po
Idempotency               -> customer + cust_po
```

`SMK069ProcessCustomerOrderSp.@SourceCoNum` tetap dipertahankan sebagai **nama parameter kompatibilitas**, tetapi caller baru mengirim `cust_po` pada parameter tersebut.

Legacy direct retry yang masih mengirim `R...` dapat resolve satu kali ke `cust_po`; setelah resolve, business processing memakai `cust_po`.

## Peak Season flag — Patch 27

Confirmed contract on 21 Sep 2026:

```text
is_peak_season INT NOT NULL DEFAULT 0
0 = Normal
1 = Peak Season
```

Persisted in:

```text
ue_SMK069_pos_sales_inbound_mst
ue_SMK069_temp_sales_mst
```

The CSV UAT console also uses a supporting `is_peak_season` column on `ue_SMK069_pos_csv_upload_mst`, because its detail grid is backed by that table.

Canonical Receive copies the value from JSON into inbound + temp by `cust_po + coline` after Core receive/validate. Canonical CSV parser/runner can carry the same optional field.

Forms:

```text
SMK API SALES ERROR PROCESSING
  Peak Season -> object.is_peak_season
  read-only checkbox beside CustPo

SMK POS CSV TO BLANKET CO
  Peak Season -> CSV detail is_peak_season
  read-only checkbox beside CustPo
```

The working DEV definition of `ue_SMK069_pos_sales_inbound_mapping_view` has
now been captured canonically in this repository and is included in the PROD
runtime deployment. Historical ownership/context remains documented, but PROD
no longer requires manual reconstruction of the view.

Patch 27 does **not** yet replace the POS-108 quantity rule with the new Peak/Normal multiple rule. The mapping/conversion view must be audited first.

## Customer Contracts UET

Additional customer-item master fields are configured through Mongoose UET:

```text
Uf_SMK069_is_peak_season
  type    = int
  default = 0

Uf_SMK069_pos_um
  UDT     = UMType
  type    = nvarchar(3)

Class = SMK069_CL_itemcust
Table = itemcust_mst
Active = 1
Extend All Records = 1
```

Customer Contracts UI exposes:

```text
POS U/M
Is Peak Season?
```

This UET metadata must be included in production deployment packaging. Detailed documentation:

```text
docs/csv-to-co/44-uet-itemcust-peak-season-pos-um.md
docs/csv-to-co/45-peak-season-aware-quantity-validation.md
docs/csv-to-co/46-pos204-duplicate-custpo-message.md
docs/csv-to-co/47-cross-batch-duplicate-custpo-rejection.md
docs/csv-to-co/48-lineage-based-cross-batch-duplicate-custpo.md
docs/csv-to-co/49-pos204-reused-batch-payload-mismatch.md
docs/csv-to-co/45-peak-season-aware-quantity-validation.md
```

## ValidationStatus gate — Patch 28

Source of truth:

```text
ue_SMK069_pos_sales_inbound_mapping_view.ValidationStatus
```

Rules:

```text
V = item valid
N = item invalid

If any item in a cust_po is N:
→ reject the whole cust_po
→ mark still-transferable inbound rows Error
→ remove its temp V rows before ProcessBatch
→ no Customer Order is created for that cust_po
→ [POS-109]
```

Other valid CustPOs in the same batch can continue.

The mapping view itself remains owned by Eva / SMK. Patch 28 only consumes `ValidationStatus`.

## Peak-aware quantity validation — Patch 29

The POS-108 quantity validation now selects `itemcust` by:

```text
cust_item
cust_num
Uf_SMK069_is_peak_season = inbound.is_peak_season
```

Then it runs the existing `SMK030_UomConvQty2/Getumcf` formula. This prevents Normal and Peak customer-item mappings from being mixed during quantity validation.

A POS-108 rejection happens **after** Receive Core created inbound rows; the rejected rows remain in inbound with status `E`, while temp `V` rows for that CustPO are removed and no CO is created.

## Quantity multiple rule — Patch 18

Business rule:

```text
SMK030_UomConvQty2(
    qty_ordered,
    Getumcf(u_m, mapped item, '', ''),
    'To Base'
)
```

Invalid bila:

```text
converted_base_qty <> FLOOR(converted_base_qty)
```

Result:

```text
root line  -> [POS-108] Quantity tidak sesuai kelipatan U/M.
sibling PO -> [POS-203] Order ditolak karena terdapat line lain yang tidak valid.
```

Atomic rejection tetap per `cust_po`.

## Auto CO corrections

### Patch 19

Memastikan `dbo.SMK069ProcessBatchCustomerOrdersSp` tersedia di tenant.

### Patch 20

Mencegah silent success saat mapping batch tidak menghasilkan order.

```text
[POS-302] Auto CO tidak menemukan order mapping untuk batch
```

### Patch 21

Memastikan header:

```text
co_mst.cust_po      = business cust_po
co_mst.type         = B
co_mst.consolidate  = 1
```

Idempotency menggunakan `customer + cust_po`.

### Patch 22

Membuat `co_bln_mst` untuk setiap staging line dan memastikan:

```text
stat               = O
allow_on_pick_list = 0
```

### Patch 23

**WITHDRAWN / SUPERSEDED.**

Pendekatan menambah field `syteline_co_num` tidak dipakai sebagai desain final.

Jika Patch 23 belum pernah diterapkan: jangan apply.

### Patch 24

File:

```text
database/patches/csv-to-co/2026-09-16-smk069-24-co-number-custpo-release-date.sql
```

Patch 24 melakukan:

```text
new CO number             = PYYMMDD###
staging co_num on success = actual SyteLine CO
coitem.release_date       = order_date
historical Processed rows = safe relink by SiteRef + customer + cust_po
```

### Patch 26

Persists the actual SyteLine CO into `ue_SMK069_temp_sales_mst.created_co_num` for the Error Processing form, including safe backfill for historical Processed rows.

Canonical `SMK069ProcessCustomerOrderSp.sql` now includes the same behavior for production baseline.

### Patch 27

File:

```text
database/patches/csv-to-co/2026-09-21-smk069-27-peak-season-flag.sql
```

Adds Peak Season data plumbing for API/CSV and the two required forms. Mapping-view exposure is owned by Eva / SMK and is outside this patch.

### Patch 28 Rev.2

File:

```text
database/patches/csv-to-co/2026-09-22-smk069-28-validation-status-reject-custpo.sql
```

Consumes `ValidationStatus` from Eva/SMK's mapping view and enforces atomic CustPO rejection when any item is `N`. Rev.2 fixes the missing `@MappingRejectedOrders` declaration that caused Rev.1 compile error.

### Patch 29

File:

```text
database/patches/csv-to-co/2026-09-22-smk069-29-peak-season-aware-qty-validation.sql
```

Makes quantity validation use the `itemcust` row whose `Uf_SMK069_is_peak_season` matches inbound `is_peak_season`.

### Patch 31

File:

```text
database/patches/csv-to-co/2026-09-23-smk069-31-explicit-pos204-duplicate-custpo-message.sql
```

Clarifies POS-204 so users see that the CustPO was already registered/processed and that changing only BatchId does not create a new business transaction.

### Patch 33

File:

```text
database/patches/csv-to-co/2026-09-23-smk069-33-reject-cross-batch-duplicate-custpo-by-lineage.sql
```

Replacement for withdrawn Patch 32. Uses only tenant-proven lineage columns:
`inbound_id + source_system + batch_id + cust_po + inbound_status`.
The earliest transferred inbound row identifies the original successful batch.
A different source/batch for the same existing CustPO is rejected as `POS-204`.

### Patch 34

File:

```text
database/patches/csv-to-co/2026-09-23-smk069-34-preserve-pos204-on-reused-batch.sql
```

Fixes contradictory `[POS-000] Request ditolak / Success=false` when an already-used BatchId is invoked with a different payload.

### Patch 35 — active latest

File:

```text
database/patches/csv-to-co/2026-09-23-smk069-35-peak-season-before-mapping-view.sql
```

Fixes a proven ordering defect: `is_peak_season` used to be copied into inbound only after Core had already materialized the mapping view. Core now persists the payload Peak flag before `#MapView`, so Peak/Normal customer-item/U/M mapping is selected correctly.

### Patch 32 — WITHDRAWN / DO NOT APPLY

File:

```text
database/patches/csv-to-co/2026-09-23-smk069-32-reject-cross-batch-duplicate-custpo.sql
```

Patch 32 attempted to distinguish original replay from a different BatchId using inbound timestamp columns. Tenant execution proved those assumed columns are unavailable. The patch is withdrawn and the canonical Receive has been restored to pre-Patch-32 behavior. Do not apply Patch 32.

### Patch 25

File:

```text
database/patches/csv-to-co/2026-09-16-smk069-25-canonical-custpo-linkage.sql
```

Patch 25 memastikan legacy `R...` tidak lagi dibawa sebagai downstream business key.

## Deployment sequence

Apply Database, satu executable batch / tanpa `GO`:

```text
14  2026-09-14-smk069-14-coitem-status-open.sql
15  2026-09-14-smk069-15-canonical-receive-to-co.sql
16  2026-09-14-smk069-16-route-csv-through-public-receive.sql
17  2026-09-14-smk069-17-consolidate-header-and-line.sql
18  2026-09-15-smk069-18-reject-non-multiple-qty-per-po.sql
19  2026-09-15-smk069-19-ensure-process-batch-customer-orders.sql
20  2026-09-15-smk069-20-fail-when-batch-has-no-co-mapping.sql
21  2026-09-15-smk069-21-fix-blanket-type-and-cust-po.sql
22  2026-09-15-smk069-22-create-blanket-lines.sql
24  2026-09-16-smk069-24-co-number-custpo-release-date.sql
25  2026-09-16-smk069-25-canonical-custpo-linkage.sql
26  2026-09-16-smk069-26-persist-created-co-num.sql
27  2026-09-21-smk069-27-peak-season-flag.sql
28  2026-09-22-smk069-28-validation-status-reject-custpo.sql
29  2026-09-22-smk069-29-peak-season-aware-qty-validation.sql
30  2026-09-22-smk069-30-clarify-pos204-existing-custpo.sql
31  2026-09-23-smk069-31-explicit-pos204-duplicate-custpo-message.sql
33  2026-09-23-smk069-33-reject-cross-batch-duplicate-custpo-by-lineage.sql
34  2026-09-23-smk069-34-preserve-pos204-on-reused-batch.sql
35  2026-09-23-smk069-35-peak-season-before-mapping-view.sql
```

Patch 23 tidak ada di active deployment sequence.

## Target final result

Header:

```text
co_mst.co_num      = PYYMMDD### untuk CO baru
co_mst.type        = B
co_mst.cust_po     = business Cust PO
co_mst.consolidate = 1
```

CO item:

```text
coitem_mst.stat         = O
coitem_mst.consolidate  = 1
coitem_mst.release_date = co_mst.order_date
```

Blanket line:

```text
co_bln_mst.item               = staging item
co_bln_mst.blanket_qty        = staging qty_ordered
co_bln_mst.cont_price         = staging unit_price
co_bln_mst.stat               = O
co_bln_mst.allow_on_pick_list = 0
```

Staging setelah success:

```text
co_num         = actual SyteLine CO number
cust_po        = business Customer PO
process_status = P
```

## Error Processing form semantics

Final binding/logical meaning:

```text
SyteLine CO Number = object.created_co_num
Business/Source PO = object.cust_po
Peak Season        = object.is_peak_season (read-only checkbox)
```

`R...` tidak dipakai sebagai user-facing business reference.

## POS-204 — existing/conflicting CustPO

`POS-204` means `ORDER_ALREADY_EXISTS`: the same business `cust_po` has already been registered/processed or conflicts with prior data. A new `BatchId` does not make the same `cust_po` a new business order because `cust_po` is the idempotency key. Patch 31 clarifies the text; Patch 33 enforces this across new/different BatchIds using inbound lineage; Patch 34 preserves POS-204 when a previously-used BatchId is called with a different payload.

Patch 30 does not change this business rule; it only fixes the public message so POS-204 no longer falls through to the misleading generic text `Data payload tidak terdaftar atau tidak sesuai di Infor`.

Diagnostic order: query inbound rows for the `cust_po`, then `co_mst.cust_po`, then staging. Reuse the existing successful order rather than creating another CO. If the prior order was not actually successful, inspect `validation_msg`/`process_status` before retrying.

## Retry / idempotency

- Retry process/master-data error tetap gunakan BatchId yang sama bila payload tidak berubah.
- `cust_po` adalah business idempotency key.
- Temp row `P` tidak diproses ulang sebagai order baru.
- Untuk POS-108 karena source quantity salah, submit corrected request/batch baru.
- Failed/unprocessed row dapat masih memegang transient legacy `R...` sampai process berhasil, tetapi downstream processor melakukan lookup/update berdasarkan `cust_po`.

## Canonical source

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonCoreSp.sql
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
```

`SMK069ProcessBatchCustomerOrdersSp.sql` dan `SMK069ProcessCustomerOrderSp.sql` sudah direbase ke desain final Cust PO + `PYYMMDD###` + Blanket lines + Release Date + `created_co_num`. Public Receive/CSV canonical sources juga sudah membawa `is_peak_season`.

## Operational docs

```text
docs/csv-to-co/30-csv-to-customer-order-one-hit.md
docs/csv-to-co/31-patch13-rerun-uat.md
docs/csv-to-co/32-canonical-receive-pos-sales-json-to-co.md
docs/csv-to-co/33-consolidated-flag.md
docs/csv-to-co/34-pos-108-qty-multiple-rejection.md
docs/csv-to-co/35-auto-co-not-running-diagnostic.md
docs/csv-to-co/36-auto-co-blanket-type-cust-po.md
docs/csv-to-co/37-auto-co-create-blanket-lines.md
docs/csv-to-co/38-syteline-co-number-traceability.md
docs/csv-to-co/39-final-co-number-custpo-release-date.md
docs/csv-to-co/42-peak-season-flag.md
docs/csv-to-co/43-validation-status-custpo-rejection.md
docs/csv-to-co/44-uet-itemcust-peak-season-pos-um.md
```

## Current UAT gate

After Patch 24 **dan Patch 25**:

1. Query historical rows by `cust_po` (`DEV4-233`, `DEV4-238`), bukan R-number.
2. Verify staging `co_num` equals actual existing SyteLine CO number.
3. Verify historical/current `coitem_mst.release_date = co_mst.order_date`.
4. Hit one **new** valid PO.
5. Verify new CO number follows `PYYMMDD###`.
6. Verify staging `co_num` equals the same new CO number.
7. Verify header `type=B`, correct `cust_po`, `consolidate=1`.
8. Verify coitem `stat=O`, `consolidate=1`, correct Release Date.
9. Verify matching `co_bln_mst`, `stat=O`, `allow_on_pick_list=0`.
10. Retry same successful BatchId must not create duplicate CO.
11. Quantity-invalid test must still return `[POS-108]` with no CO.
12. ValidationStatus mixed-item test: any `N` must reject the whole CustPO with `[POS-109]` and no CO.
13. Cross-batch duplicate test: existing CustPO under a different source/batch must return `[POS-204]`; Patch 33 uses earliest transferred `inbound_id` lineage. Patch 34 also prevents `[POS-000] Request ditolak` when a used BatchId is invoked with a different payload. Patch 32 remains withdrawn.

## Receive Core canonical source — captured 23 Sep 2026

The DEV tenant definition of:

```text
dbo.SMK069ReceivePosSalesJsonCoreSp
```

is now stored canonically at:

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonCoreSp.sql
```

This closes the previous source-parity gap where only references/documentation
and wrapper patches were stored in the repository while the Core procedure
itself existed only in the tenant.


## Peak Season mapping order — proven 23 Sep 2026

The business source remains:

```text
ue_SMK069_pos_sales_inbound_mapping_view
```

The Core procedure already transfers temp values from `#MapView`. The defect was not use of `inbound_mst` as business source; it was timing. Before Patch 35 the inbound Peak flag was still default `0` while the mapping view was evaluated. Patch 35 sets `inbound.is_peak_season` from `raw_json` before the mapping-view snapshot.


## Production migration package — 24 Sep 2026

Use:

```text
deployment/csv-to-co/prod/
```

Production rule:

```text
DO NOT replay Patch 01..35 for a fresh PROD baseline.
Use the consolidated canonical runtime deployment.
```

Files:

```text
00-capture-dev-baseline.sql
00b-capture-table-keys-and-indexes.sql
00c-create-core-physical-tables.sql
00e-ensure-itemcust-peak-posum-physical.sql   (fallback only)
00f-verify-itemcust-uet-physical.sql
01-preflight.sql
02-deploy-canonical-runtime.sql
03-post-deploy-verify.sql
04-mongoose-metadata-checklist.md
05-prod-uat-checklist.md
06-turnkey-cutover.md
```

External metadata still migrated separately:

```text
- Mongoose UET metadata (verified DEV itemcust setup)
- IDO/form/event metadata
- public Receive IDO method with Transactional=False
```

The mapping view is now part of the canonical SQL deployment.

Patch 32 remains withdrawn and is not part of production deployment.


## DEV UET Impact Schema verified — 28 Sep 2026

For this workstream the verified UET relationship is:

```text
SMK069_CL_itemcust
  -> Uf_SMK069_is_peak_season
  -> Uf_SMK069_pos_um

itemcust_mst
  -> SMK069_CL_itemcust
  Active = 1
  Extend All Records = 1
```

UET Impact Schema completed successfully in DEV. Use the same UET metadata +
Impact Schema flow in PROD. Direct physical-column SQL is fallback only.


## Field-map seed captured — 28 Sep 2026

The external JSON-to-canonical field map is still required by
`SMK069ReceivePosSalesJsonCoreSp` before the business mapping view is read.

Verified DEV configuration:

```text
source_system = POS
SiteRef       = Default
active rows   = 36
```

The exact configuration has been embedded as an idempotent seed in:

```text
deployment/csv-to-co/prod/00c-create-core-physical-tables.sql
```

Therefore PROD no longer requires a manual field-map data entry step.
