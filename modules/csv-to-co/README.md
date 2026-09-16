# CSV / POS Inbound → Blanket Customer Order

## Scope

Modul ini hanya menangani inbound POS/CSV sampai menjadi **Blanket Customer Order type `B`** di SyteLine.

Shipment outbound, DN retry, TaskMan Shipment, dan endpoint Shipment berada di workstream `shipment` dan tidak boleh dicampur ke sini kecuali ada dependency nyata yang sedang didiagnosis.

## Arsitektur aktif — 16 Sep 2026

Single canonical business entry point:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Flow:

```text
POS JSON ------------------------------┐
                                       │
CSV -> parsed detail -> build JSON ----┼-> SMK069ReceivePosSalesJsonSp
                                       │          ↓
                                       │   SMK069ReceivePosSalesJsonCoreSp
                                       │          ↓
                                       │   quantity multiple validation
                                       │          ↓
                                       │   ue_SMK069_temp_sales_mst
                                       │          ↓
                                       │   SMK069ProcessBatchCustomerOrdersSp
                                       │          ↓
                                       └------> SMK069ProcessCustomerOrderSp
                                                  ↓
                                      co_mst + coitem_mst + co_bln_mst
```

IDO method yang menjalankan flow ini harus tetap:

```text
Transactional = False
```

karena `SMK069ProcessCustomerOrderSp` memiliki transaction per order sendiri.

## Public API contract

Gunakan:

```text
SMK069ReceivePosSalesJsonSp
```

Parameter 1–10 tetap backward-compatible. Parameter tambahan:

```text
11 ProcessedOrders OUT
12 ProcessErrors OUT
13 CreatedCoNums OUT
14 ThrowOnBusinessError = 1
```

Public API default `ThrowOnBusinessError=1`. CSV wrapper memakai `0` agar partial counts dapat dipersist.

## Source-order vs business PO vs generated CO

Ketiga nilai berikut **berbeda dan tidak boleh saling menggantikan**:

```text
co_num / SourceCoNum  = technical Source/POS Order No, contoh R260904069
cust_po               = business Customer PO, contoh DEV4-233
syteline_co_num       = generated SyteLine CO, contoh CO2609xxxx
```

Primary staging key tetap memakai source/POS `co_num`.

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

Hasil:

```text
root offending line -> [POS-108] Quantity tidak sesuai kelipatan U/M.
sibling same cust_po -> [POS-203] Order ditolak karena terdapat line lain yang tidak valid.
```

Reject bersifat atomic per `cust_po`. Current POS operational assumption: satu API hit = satu PO.

## Auto CO corrections

### Patch 19 — batch processor tersedia

Memastikan tenant mempunyai:

```text
dbo.SMK069ProcessBatchCustomerOrdersSp
```

File:

```text
database/patches/csv-to-co/2026-09-15-smk069-19-ensure-process-batch-customer-orders.sql
```

### Patch 20 — no silent success

Jika mapping view tidak menghasilkan order, flow tidak lagi terlihat sukses dengan `ProcessedOrders=0`.

Error:

```text
[POS-302] Auto CO tidak menemukan order mapping untuk batch
```

File:

```text
database/patches/csv-to-co/2026-09-15-smk069-20-fail-when-batch-has-no-co-mapping.sql
```

### Patch 21 — Blanket type + business Cust PO

Tenant UAT membuktikan processor lama menghasilkan:

```text
co_mst.cust_po = Source/POS order   <-- salah
co_mst.type    = R                  <-- salah
```

Patch 21 mengubah menjadi:

```text
co_mst.cust_po      = staging business cust_po
co_mst.type         = B
co_mst.consolidate  = 1
```

Idempotency processor menggunakan `customer + business cust_po`.

File:

```text
database/patches/csv-to-co/2026-09-15-smk069-21-fix-blanket-type-and-cust-po.sql
```

### Patch 22 — create co_bln_mst

Tenant schema dan known-good Blanket membuktikan header type `B` tidak otomatis membuat Blanket Lines pada direct SQL processor kita.

Patch 22 membuat satu `co_bln_mst` per staging line:

```text
co_line                <- staging co_line
item                   <- staging item
blanket_qty            <- qty_ordered
blanket_qty_conv       <- qty_ordered
cont_price             <- unit_price
cont_price_conv        <- unit_price
u_m                    <- staging/item U/M
ship_site              <- SiteRef
whse                   <- warehouse
stat                   = O
allow_on_pick_list     = 0
```

Patch 22 juga dapat repair existing matching Blanket bila header/coitem sudah cocok dan `co_bln_mst` benar-benar masih 0 row.

File:

```text
database/patches/csv-to-co/2026-09-15-smk069-22-create-blanket-lines.sql
```

### Patch 23 — persist SyteLine CO Number

Tenant finding 16 Sep 2026:

```text
R260904069 / DEV4-233 -> Processed, SyteLine CO Number blank
R260904070 / DEV4-238 -> Processed, SyteLine CO Number blank
```

Root cause: generated `@CreatedCoNum` hanya dikembalikan sebagai procedure output / `CreatedCoNums`; staging belum mempunyai field target CO yang dipersist.

Patch 23:

```text
ADD ue_SMK069_temp_sales_mst.syteline_co_num NVARCHAR(10) NULL
persist @CreatedCoNum after successful order process
safe backfill existing Processed rows when exactly one Blanket CO matches
  SiteRef + customer + business cust_po
skip ambiguous historical matches
```

File:

```text
database/patches/csv-to-co/2026-09-16-smk069-23-persist-syteline-co-number.sql
```

Setelah SQL patch, Mongoose metadata perlu disinkronkan:

```text
SQL Table metadata : SMK069_temp_sales_mst
IDO                : ue_SMK069TempSales
new property        : syteline_co_num
form binding        : object.syteline_co_num
```

Kolom **SyteLine CO Number** di form Error Processing harus read-only.

## Deployment sequence

Apply Database, satu executable batch / tanpa `GO`:

```text
14  2026-09-14-smk069-14-coitem-status-open.sql
15  2026-09-14-smk069-15-canonical-receive-to-co.sql
16  2026-09-14-smk069-16-route-csv-through-public-receive.sql
17  2026-09-14-smk069-17-consolidate-header-and-line.sql   (Rev.6)
18  2026-09-15-smk069-18-reject-non-multiple-qty-per-po.sql
19  2026-09-15-smk069-19-ensure-process-batch-customer-orders.sql
20  2026-09-15-smk069-20-fail-when-batch-has-no-co-mapping.sql
21  2026-09-15-smk069-21-fix-blanket-type-and-cust-po.sql
22  2026-09-15-smk069-22-create-blanket-lines.sql
23  2026-09-16-smk069-23-persist-syteline-co-number.sql
```

Patch 17 uses tenant-confirmed fields:

```text
co_mst.consolidate      tinyint
coitem_mst.consolidate  tinyint
```

## Target final result

Header:

```text
co_mst.type        = B
co_mst.cust_po     = business CustPo
co_mst.consolidate = 1
```

CO item:

```text
coitem_mst.stat        = O
coitem_mst.consolidate = 1
```

Blanket line:

```text
co_bln_mst.item               = staging item
co_bln_mst.blanket_qty        = staging qty_ordered
co_bln_mst.cont_price         = staging unit_price
co_bln_mst.stat               = O
co_bln_mst.allow_on_pick_list = 0
```

Traceability staging:

```text
co_num             = Source/POS order
cust_po            = business Customer PO
syteline_co_num    = generated SyteLine CO
process_status     = P after successful processing
```

## Retry / idempotency

- Same safe `BatchId` may be retried for process/master-data failures when source payload is unchanged.
- Temp order `P` is skipped by the batch loop.
- After Patch 21, per-order idempotency uses `customer + business cust_po`.
- For POS-108 source quantity correction, submit corrected source as a new request/batch.
- Do not use a new BatchId merely to force a previously successful PO through again; that can defeat the intended retry semantics.

## Canonical source

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
```

`SMK069ProcessBatchCustomerOrdersSp.sql` is aligned through Patch 23. Patch 21/22 remain deployment corrections to the tenant Customer Order processor until its canonical source is fully rebased.

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
```

## Current UAT gate

After Patch 23:

1. Query `R260904069` and `R260904070` in staging; if each business Cust PO uniquely matches a Blanket CO, `syteline_co_num` should be backfilled.
2. Refresh/resync `ue_SMK069TempSales` metadata and bind the form column to `object.syteline_co_num`.
3. Hit one new valid PO.
4. Verify header `type=B`, correct business `cust_po`, `consolidate=1`.
5. Verify `coitem_mst.stat=O`, `coitem_mst.consolidate=1`.
6. Verify matching `co_bln_mst`, `stat=O`, `allow_on_pick_list=0`.
7. Verify Error Processing shows generated **SyteLine CO Number**.
8. Quantity-invalid test must still return `[POS-108]` with no CO.
