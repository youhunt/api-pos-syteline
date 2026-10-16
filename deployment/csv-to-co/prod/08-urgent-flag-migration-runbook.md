# Urgent flag — pindah ke environment lain (Patch 36–39)

**Tanggal:** 16 Oktober 2026  
**Scope:** `is_urgent` + `urgent_remark` dari payload POS / CSV sampai Customer Order Blanket Line dan Release  
**Referensi isi fitur:** `docs/csv-to-co/50-urgent-flag.md`  
**Script cek:** `08-urgent-flag-precheck-verify.sql` (read-only; dipakai sebelum dan sesudah)

## 1. Yang ikut dipindah

| Kelompok | Isi | Dibuat lewat |
|---|---|---|
| UET Mongoose | `Uf_SMK069_is_urgent` (int) dan `Uf_SMK069_urgent_remark` (nvarchar 255) pada **`co_bln_mst`** (class `SMK069_CL_co_bln`) dan **`coitem_mst`** (class `SMK069_CL_coitem`) | Mongoose + **Impact Schema** (bukan `ALTER TABLE`) |
| Tabel `ue_` | kolom `is_urgent`, `urgent_remark` pada inbound, temp, dan csv upload | Patch 36 dan 37 |
| Procedure | `SMK069ReceivePosSalesJsonCoreSp`, `SMK069ProcessCustomerOrderSp` (36, 38), `SMK069ImportCsvFileSp`, `SMK069RunCsvTestBatchSp` (37) | Patch (edit in-place pada definisi aktif) |
| Constraint | `CK_SMK069CsvBatch_Status` mengizinkan `P` (partial) | Patch 39 |
| IDO | property `IsUrgent`, `UrgentRemark` pada `ue_SMK069PosCsvUpload`; property `coiUf_SMK069_*` pada `SLCoitems` | Form/IDO editor Mongoose (manual) |
| Form | kolom grid Is Urgent + Urgent Remark pada `ue_SMK069PosCsvBatchConsole` dan `ue_SMK069_BlanketReleases` | Form Editor / import XML |

**Tidak ikut / tidak berubah:** mapping view `ue_SMK069_pos_sales_inbound_mapping_view` (milik Eva / SMK), signature procedure (metadata IDO method tidak perlu disentuh), form Error Processing, history table.

## 2. Prasyarat target

1. Target sudah punya fitur CSV/POS → Customer Order SMK069 pada versi yang **sama dengan sumber** (termasuk Peak Season). Patch 36–38 mengedit definisi aktif lewat anchor teks; bila versi target berbeda, patch berhenti (fail-closed) dan tidak mengubah apa pun.
2. Jalankan `08-urgent-flag-precheck-verify.sql` di target. Grup **A** dan **C** harus OK. Grup **B** harus OK sebelum Patch 36 dan 38 (lihat langkah 2). Grup **D** menunjukkan patch yang sudah/belum terpasang.
3. **PRD:** paket kanonik `02-deploy-canonical-runtime.sql` belum bisa dibangkitkan ulang karena Core/Receive kanonik di repo masih tertinggal dari TRN (lihat `07-trn-to-prd-delta-2026-10-12.md` bagian 10–13). Jadi pasang Patch 36–39 **di atas definisi setara TRN**, yaitu setelah delta TRN → PRD (bagian 2–5 dokumen itu) terpasang. Jangan menimpa Core dengan salinan repo.

## 3. Urutan pelaksanaan

| # | Langkah | Hasil yang diharapkan |
|---|---|---|
| 0 | Script-out cadangan: `SMK069ReceivePosSalesJsonCoreSp`, `SMK069ProcessCustomerOrderSp`, `SMK069ImportCsvFileSp`, `SMK069RunCsvTestBatchSp`; simpan juga hasil `SELECT definition FROM sys.check_constraints WHERE name = N'CK_SMK069CsvBatch_Status'` | file cadangan |
| 1 | Jalankan script cek | grup A, C OK |
| 2 | Mongoose: buat UET pada `co_bln_mst` dan `coitem_mst`, class dan table extension (Active 1, Extend All Records 1), lalu **Impact Schema**. PRD: `coitem_mst` besar, jalankan di luar jam sibuk | script cek grup B OK |
| 3 | **Patch 36** (`2026-10-14-smk069-36-urgent-flag.sql`) | `[PATCH-36] ... SUCCESS` |
| 4 | **Patch 37** (`...-37-urgent-flag-csv.sql`) | `[PATCH-37] ... SUCCESS` |
| 5 | Resync IDO `ue_SMK069PosCsvUpload`; pastikan property `IsUrgent` dan `UrgentRemark` ada (tambah manual bila belum) | property muncul |
| 6 | **Patch 38** (`...-38-urgent-flag-coitem.sql`) | `[PATCH-38] OK ...`, `Backfill ... N baris`, `SUCCESS` |
| 7 | **Patch 39** (`...-39-csv-batch-status-partial.sql`) | `[PATCH-39] SUCCESS` (atau "dilewati" bila constraint sudah memuat P / tidak ada) |
| 8 | Form: export form dari environment sumber setelah kolom ditambah, import ke target; atau tambah dua kolom manual (lihat bagian 5) | grid menampilkan kolom |
| 9 | Jalankan script cek lagi | semua OK, ringkasan 0 |
| 10 | UAT minimal (bagian 4) | sesuai harapan |
| 11 | Kabari tim POS: environment tujuan sudah siap, nama key resmi `is_urgent` / `urgent_remark` (nama lama tetap diterima) | |

Cara jalan patch: Apply Database, **satu batch, tanpa `GO`**. Semua patch aman dijalankan ulang (procedure yang sudah bermarkah dilewati). Bila ada patch berhenti dengan `THROW` (anchor, precheck), tidak ada procedure yang berubah; kirim pesan lengkapnya.

## 4. UAT minimal di target

Pakai `cust_po` dan BatchId **baru** untuk setiap uji, dan customer/item yang ada di mapping target (nilai `B005` / `POSITEM001` pada contoh hanya ilustrasi).

| # | Uji | Harapan |
|---|---|---|
| 1 | `tests/payloads/pos-sales-urgent-sample.json` (line 1 normal, line 2 urgent "kirim hari ini") | CO dibuat; `co_bln_mst` dan `coitem_mst`: line 1 = 0 + NULL, line 2 = 1 + "kirim hari ini" |
| 2 | `tests/payloads/pos-sales-urgent-sample-legacy-keys.json` (nama key lama) | hasil sama (alias diterima) |
| 3 | Payload lama tanpa kedua key | sukses; 0 + NULL |
| 4 | `tests/payloads/csv-urgent/csv-u2-urgent-and-normal.csv` lewat **Upload & Process CSV to CO** | grid CSV menampilkan Is Urgent / Urgent Remark; CO dibuat |
| 5 | CSV dengan satu `cust_po` yang sudah terdaftar dan satu baru | batch berstatus partial (`P`), **tanpa** error 547; PO baru tetap jadi CO |
| 6 | Buka form Releases pada CO hasil uji 1 | kolom Is Urgent tercentang pada line 2; remark tampil; keduanya read-only |

Query verifikasi nilai ada di `docs/csv-to-co/50-urgent-flag.md`, bagian UAT dan "UAT form Releases".

## 5. Yang tidak ikut otomatis (cek manual)

- **IDO:** definisi IDO tidak ikut lewat SQL. `ue_SMK069PosCsvUpload` perlu `IsUrgent` dan `UrgentRemark`; `SLCoitems` menampilkan `coiUf_SMK069_is_urgent` dan `coiUf_SMK069_urgent_remark` setelah UET dan Impact Schema (bila tidak muncul, refresh metadata IDO).
- **Form:** import XML menimpa seluruh form di target. Gunakan **export dari environment sumber setelah kolom ditambah**, dan hanya bila form target sama dengan versi sumber (misalnya form target tidak punya tab/komponen tambahan yang tidak ada di sumber). Bila berbeda, tambah dua kolom grid secara manual: Data Source `object2.IsUrgent` / `object2.UrgentRemark` pada console CSV, dan `object.coiUf_SMK069_is_urgent` / `object.coiUf_SMK069_urgent_remark` pada Releases, semuanya Read Only. Bila form terkunci, check-in atau unlock dulu.
- **Layout kolom per user:** user yang pernah menyimpan layout grid mungkin tidak melihat kolom baru di posisi semula.
- **Form Customer Order Blanket Lines standar:** belum dikerjakan; tanyakan ke bisnis bila dibutuhkan.
- **Release manual:** release yang ditambah user secara manual tidak mewarisi nilai urgent dari blanket line.

## 6. Rollback

1. Procedure: jalankan ulang script cadangan langkah 0 (kembali ke definisi sebelum patch).
2. Constraint: kembalikan definisi lama dari cadangan bila perlu (hanya bila ada alasan; `P` yang diizinkan tidak merugikan).
3. UET dan kolom `is_urgent` / `urgent_remark` boleh dibiarkan: kolom tidak dipakai procedure lama dan tidak mengubah perilaku.
4. Form: import ulang export form sebelum perubahan.
