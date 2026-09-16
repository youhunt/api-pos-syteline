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

Gunakan:

```text
cust_po
```

sebagai business linkage utama.

Contoh:

```text
cust_po = DEV4-233
```

Nomor teknis `R...` bukan lagi identifier bisnis yang dibawa ke mana-mana. Legacy Core masih dapat menghasilkan nilai tersebut sebagai transient selector sebelum proses berhasil.

Setelah Customer Order sukses:

```text
ue_SMK069_temp_sales_mst.co_num = actual SyteLine CO number
```

Jadi tidak diperlukan field target CO baru sebagai source of truth.

## New CO numbering — Patch 24

Format baru:

```text
P + YYMMDD + 3-digit running
```

Example:

```text
P260916001
P260916002
```

Running number reset per tanggal karena `YYMMDD` menjadi bagian prefix.

Total panjang nomor = 10 karakter.

Existing standard Customer Order **tidak direnumber**. Patch 24 hanya mengubah format untuk CO baru.

## Released Date — Patch 24

Rule final:

```text
coitem_mst.release_date = co_mst.order_date
```

Untuk CO baru nilai ditulis saat insert line.

Untuk existing matching Blanket CO / historical integration rows, Patch 24 memperbaiki `release_date` yang NULL atau berbeda dari header `order_date`.

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

Mencegah silent success saat mapping batch tidak menghasilkan order. Error:

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

Pendekatan menambah field terpisah `syteline_co_num` tidak dipakai sebagai desain final.

Jika Patch 23 belum pernah diterapkan: jangan apply.

Jika sudah pernah diterapkan: Patch 24 tetap kompatibel; field legacy tersebut hanya disinkronkan dan bukan source of truth.

### Patch 24 — active latest

File:

```text
database/patches/csv-to-co/2026-09-16-smk069-24-co-number-custpo-release-date.sql
```

Patch 24 melakukan:

```text
new CO number             = PYYMMDD###
staging co_num on success = actual SyteLine CO
business pending linkage  = cust_po
operator messages         = cust_po, bukan R...
coitem.release_date       = order_date
historical Processed rows = safe relink by SiteRef + customer + cust_po
```

Historical relink hanya dilakukan bila business Cust PO resolve ke tepat satu Blanket CO. Existing standard CO tidak diubah nomornya.

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

## Retry / idempotency

- Retry process/master-data error tetap gunakan BatchId yang sama bila payload tidak berubah.
- `cust_po` adalah business idempotency key.
- Temp row `P` tidak diproses ulang sebagai order baru.
- Untuk POS-108 karena source quantity salah, submit corrected request/batch baru.
- Failed/unprocessed row dapat masih memegang transient `R...` sampai proses berhasil.

## Canonical source

```text
database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql
database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql
database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql
database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql
```

Deployment corrections Patch 21/22/24 tetap source of truth untuk tenant processor sampai canonical `SMK069ProcessCustomerOrderSp.sql` direbase penuh.

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

After Patch 24:

1. Query current rows by `cust_po` (`DEV4-233`, `DEV4-238`), not by R-number.
2. Verify staging `co_num` now equals the actual existing SyteLine CO number.
3. Verify `coitem_mst.release_date = co_mst.order_date`.
4. Hit one new valid PO.
5. Verify new CO number follows `PYYMMDD###`.
6. Verify staging `co_num` equals that same new CO number.
7. Verify header `type=B`, correct `cust_po`, `consolidate=1`.
8. Verify coitem `stat=O`, `consolidate=1`, correct release date.
9. Verify matching `co_bln_mst`, `stat=O`, `allow_on_pick_list=0`.
10. Quantity-invalid test must still return `[POS-108]` with no CO.
