# Initial PoC Test Cases

## Test Result Status

```text
PASS    = actual result sesuai expected result
FAIL    = actual result berbeda
BLOCKED = test belum dapat dilakukan karena dependency belum tersedia
N/A     = tidak berlaku untuk profile/flow terpilih
```

## Core Test Matrix

| ID | Area | Scenario | Expected Result |
|---|---|---|---|
| TST-001 | Metadata | Custom table dan IDO berhasil dibuat | Object tersedia, property type benar, standard columns terisi |
| TST-002 | IDO | Load inbound collection | Data tampil, default order benar, payload text tidak otomatis dimuat |
| TST-003 | Security | User view mencoba direct insert/update/delete | Operasi ditolak |
| TST-004 | Minimal Receive | Kirim `minimal-valid.json` | 1 inbound, 1 batch, 3 raw lines, status sukses |
| TST-005 | Minimal Grouping | Group raw lines | 2 distinct transactions; TRX001=225000; TRX002=125000 |
| TST-006 | Reconciliation | Hitung batch total | Batch total = 350000 |
| TST-007 | Item Mapping | Semua item memiliki mapping aktif | `item`, `syteline_qty`, dan `u_m` terisi tanpa mengubah source fields |
| TST-008 | Unmapped Item | Kirim `minimal-item-unmapped.json` | Row error, message item mapping tidak ditemukan, tidak masuk preview |
| TST-009 | Retry | Tambahkan mapping lalu retry inbound/batch error | Mapping berhasil, retry count naik, tidak ada duplicate source row |
| TST-010 | Idempotency | Kirim ulang payload valid dengan idempotency key sama | Response duplicate/idempotent; tidak ada batch kedua |
| TST-011 | Request ID | Request ID sama dengan payload berbeda | Ditolak atau diarahkan ke conflict policy; tidak silently overwrite |
| TST-012 | Duplicate Hash | Payload identik dengan request ID berbeda | Duplicate exact-payload terdeteksi sesuai policy |
| TST-013 | Invalid JSON | Kirim malformed JSON | Inbound audit tercatat, batch tidak dibuat, error jelas |
| TST-014 | Missing Field | Hilangkan `businessDate` atau `transactionNumber` | Validation error pada field yang tepat |
| TST-015 | Duplicate Row Number | Dua source row memiliki nomor sama dalam batch | PK/validation menolak duplicate, transaction rollback konsisten |
| TST-016 | Negative Quantity | Kirim `minimal-negative-qty.json` | Diterima sebagai candidate refund/return atau ditolak sesuai rule final; tidak diasumsikan diam-diam |
| TST-017 | Quantity Conversion | Mapping factor 6, source qty 2 | Source qty tetap 2; SyteLine qty = 12 |
| TST-018 | Expired Mapping | Mapping item expired pada business date | Mapping tidak digunakan; status error |
| TST-019 | Ambiguous Mapping | Lebih dari satu mapping aktif berlaku | Status error ambiguous mapping |
| TST-020 | Site Isolation | Query dari site berbeda | Data tidak bocor antar-site |
| TST-021 | Process Log | Valid, error, dan retry process | Log append-only tersedia dan attempt dapat ditelusuri |
| TST-022 | Preview Generate | Generate preview dari data valid | Account/source reference terisi dan preview terbentuk |
| TST-023 | Preview Balance | Preview valid | Total debit = total credit |
| TST-024 | Preview Unbalanced | Ubah/generate line tidak balance | Approval/posting ditolak |
| TST-025 | Preview Rebuild | Mapping berubah lalu rebuild | Generation baru dibuat; generation lama tidak ditimpa |
| TST-026 | Approval | User tanpa hak mencoba approve | Ditolak |
| TST-027 | Posted Protection | Preview sudah posted diproses ulang | Ditolak; tidak ada transaksi target kedua |
| TST-028 | Payload Access | User biasa membuka raw payload | Ditolak atau payload tidak ditampilkan |
| TST-029 | Payload Purge | Admin purge sesuai retention | Payload hilang, metadata audit tetap ada, purged flag/date terisi |
| TST-030 | Concurrent Duplicate | Dua request idempotency sama dikirim hampir bersamaan | Hanya satu inbound/batch yang diproses sebagai owner; tidak ada double posting |

## Detailed First Run

### TST-004 — Minimal Valid Receive

Payload:

```text
tests/payloads/minimal-valid.json
```

Expected:

```text
Inbound count          = 1
Batch count            = 1
Raw line count         = 3
Distinct transactions  = 2
Accepted count         = 3
Rejected count         = 0
Batch total            = 350000
```

Source values to verify:

```text
TRX001 / PIZZA001 / qty 2 / total 200000
TRX001 / DRINK001 / qty 1 / total 25000
TRX002 / PIZZA002 / qty 1 / total 125000
```

### TST-008 — Unmapped Item

Payload:

```text
tests/payloads/minimal-item-unmapped.json
```

Expected:

- inbound dan batch tetap dapat ditelusuri sesuai acceptance policy;
- row `UNKNOWN999` berstatus error;
- error code/message menunjukkan item belum dimapping;
- source row tetap tersimpan;
- row error tidak digunakan untuk posting preview;
- retry dapat dilakukan setelah mapping ditambahkan.

### TST-010 — Idempotency

Langkah:

1. kirim `minimal-valid.json`;
2. catat inbound ID dan batch number;
3. kirim file yang sama tanpa mengubah idempotency key;
4. bandingkan jumlah inbound dan batch.

Expected:

- tidak ada batch bisnis kedua;
- response menyatakan duplicate/already accepted;
- referensi batch awal dikembalikan;
- process log menunjukkan duplicate handling;
- tidak ada posting preview atau target posting ganda.

### TST-023 — Preview Balance

Expected query/result:

```text
SUM(debit_amt) = SUM(credit_amt)
SUM(dom_debit_amt) = SUM(dom_credit_amt)
```

Preview hanya boleh menjadi ready/approved ketika semua mapping valid dan selisih berada dalam tolerance yang disetujui.

## Execution Record Template

```text
Test Case ID      :
Test Date         :
Tester            :
Environment       :
Site              :
Application Build :
Payload/File      :
Expected Result   :
Actual Result     :
Inbound ID        :
Request ID        :
Batch Number      :
Preview Number    :
Result            : PASS / FAIL / BLOCKED / N/A
Evidence Location :
Defect/Notes      :
```
