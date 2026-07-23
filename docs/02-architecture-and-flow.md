# 02 — Architecture and Processing Flow

## Arsitektur Konseptual

```text
+--------------------------+
| POS / Postman / Import   |
+------------+-------------+
             |
             | JSON / file / manual entry
             v
+--------------------------+
| SyteLine REST / IDO      |
| Custom Method            |
+------------+-------------+
             |
             v
+--------------------------+
| Staging Tables           |
| Batch / Tran / Line / Pay|
+------------+-------------+
             |
             v
+--------------------------+
| Validation & Mapping     |
| Outlet / Item / Payment  |
+------------+-------------+
             |
             v
+--------------------------+
| Summarize / Preview      |
+------------+-------------+
             |
             v
+--------------------------+
| SyteLine Processing      |
| GL / AR / Inventory      |
+------------+-------------+
             |
             v
+--------------------------+
| Financial Reporting      |
+--------------------------+
```

## Jalur Masuk Data

### Jalur A — API

```text
POS → REST endpoint SyteLine → IDO Method → staging
```

### Jalur B — Custom Form

```text
User → custom form SyteLine → input/import → staging
```

Kedua jalur harus memakai service/method server-side yang sama agar aturan validasi dan duplikasi konsisten.

## Flow Penerimaan

1. SyteLine menerima request.
2. Sistem membuat `request_id` dan `correlation_id` bila belum tersedia.
3. Sistem memeriksa identitas request/batch untuk duplikasi.
4. Header batch disimpan.
5. Header transaksi disimpan.
6. Detail item disimpan.
7. Pembayaran disimpan.
8. Process log dicatat.
9. API mengembalikan status `RECEIVED`, bukan `PROCESSED`.

## Flow Validasi

```text
RECEIVED
   |
   v
Check batch identity
   |
   v
Check outlet mapping
   |
   v
Check transaction uniqueness
   |
   v
Check item mapping and U/M
   |
   v
Check payment mapping
   |
   v
Recalculate totals
   |
   +------ invalid ------> ERROR / INVALID
   |
   v
VALIDATED / READY
```

## Flow Pengolahan

```text
VALIDATED
   |
   v
Create posting preview
   |
   v
Finance/user review (PoC)
   |
   v
Submit processing/background task
   |
   v
Create SyteLine transaction(s)
   |
   v
Store SyteLine references
   |
   v
PROCESSED
```

## Status Batch dan Transaksi

| Kode | Status | Penjelasan |
|---|---|---|
| `N` | New | Record dibuat, belum lengkap diproses |
| `R` | Received | Data diterima dan disimpan di staging |
| `V` | Validated | Semua validasi wajib berhasil |
| `I` | In Process | Sedang diproses ke transaksi SyteLine |
| `P` | Processed | Selesai diproses |
| `E` | Error | Validasi atau proses gagal |
| `C` | Cancelled | Dibatalkan secara terkontrol |

## Idempotency dan Pencegahan Duplikasi

Kandidat identitas unik:

```text
source_system + outlet_code + business_date + trans_num
```

Untuk request/batch:

```text
source_system + ext_batch_num
```

Apabila source tidak menjamin `ext_batch_num`, sistem dapat memakai `request_id` dan/atau `payload_hash`.

Aturan:

- request ulang dengan identitas sama tidak membuat record dan posting baru;
- respons harus mengembalikan status record yang sudah ada;
- retry processing berbeda dengan resend payload;
- retry menambah log/attempt, bukan menggandakan transaksi.

## Transaction Boundary

Penerimaan batch besar tidak harus selalu satu database transaction tunggal. Keputusan perlu mempertimbangkan ukuran payload, timeout, dan kemampuan rollback.

Rekomendasi PoC:

- satu transaksi database untuk satu request kecil;
- untuk batch besar, simpan bertahap dengan status kontrol;
- posting aktual per batch atau unit posting yang dapat di-restart;
- jangan menandai `P` sebelum seluruh referensi wajib tersimpan.

## Background Processing

Untuk volume besar, tombol `Process` pada form sebaiknya mengirim background task. Form tidak menjalankan loop panjang atau posting ribuan transaksi di client.

## Error Handling

Error diklasifikasikan menjadi:

| Kategori | Contoh |
|---|---|
| Structural | Field wajib tidak ada, tipe data salah |
| Duplicate | Batch/transaksi sudah pernah diterima |
| Mapping | Outlet/item/payment/tax tidak ditemukan |
| Reconciliation | Total header tidak sama dengan detail |
| Business | Periode tertutup, akun tidak valid |
| Technical | Timeout, SQL exception, service failure |

Setiap error harus memiliki minimal:

```text
error_code
message_text
technical_detail
batch_num
trans_num (jika relevan)
request_id/correlation_id
attempt_num
```

## Observability

Informasi minimum yang dapat dipantau:

- jumlah batch diterima;
- jumlah transaksi per batch;
- batch valid/error/processed;
- jumlah item tidak termapping;
- jumlah payment tidak termapping;
- durasi proses;
- retry count;
- referensi SyteLine hasil posting.
