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

The tenant mapping view `ue_SMK069_pos_sales_inbound_mapping_view` will be updated by Eva / SMK. This repository must not create a competing view patch unless ownership changes explicitly.

Patch 27 does **not** yet replace the POS-108 quantity rule with the new Peak/Normal multiple rule. The mapping/conversion view must be audited first.

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

### Patch 28 Rev.2 — active latest

File:

```text
database/patches/csv-to-co/2026-09-22-smk069-28-validation-status-reject-custpo.sql
```

Consumes `ValidationStatus` from Eva/SMK's mapping view and enforces atomic CustPO rejection when any item is `N`. Rev.2 fixes the missing `@MappingRejectedOrders` declaration that caused Rev.1 compile error.

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

## Retry / idempotency

- Retry process/master-data error tetap gunakan BatchId yang sama bila payload tidak berubah.
- `cust_po` adalah business idempotency key.
- Temp row `P` tidak diproses ulang sebagai order baru.
- Untuk POS-108 karena source quantity salah, submit corrected request/batch baru.
- Failed/unprocessed row dapat masih memegang transient legacy `R...` sampai process berhasil, tetapi downstream processor melakukan lookup/update berdasarkan `cust_po`.

## Canonical source

```text
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