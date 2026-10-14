# Urgent flag — Is_Urgent + Urgent Remark

**Tanggal:** 14 Oktober 2026
**Scope:** CSV / POS inbound → Blanket Customer Order
**Patch:** `database/patches/csv-to-co/2026-10-14-smk069-36-urgent-flag.sql`
**Kode:** SMK069

## Kebutuhan

> Dibutuhkan penambahan field `Is_urgent` dan `urgent_remark` pada form Customer Order Blanket Line.
> Field tersebut juga ditambah di payload API Sales. Kebutuhan ini agar user mengetahui apakah order ini urgent atau tidak.

Artinya ada dua perubahan yang harus berjalan bersama:

```text
1. Payload API Sales membawa Is_Urgent dan Urgent Remark (per line)
2. Customer Order Blanket Line di SyteLine menyimpan dan menampilkan keduanya
```

## Kontrak payload

Contoh payload dari bisnis (disimpan juga di `tests/payloads/pos-sales-urgent-sample.json`):

```json
[
  {
    "custnum": "B005",
    "order_date": "2026-09-24",
    "cust_po": "POS09240001",
    "whse": "P963",
    "coline": 1,
    "item": "POSITEM001",
    "qty_ordered": 10,
    "u_m": "PCS",
    "is_peak_season": 1,
    "Is_Urgent": 0,
    "Urgent Remark": ""
  }
]
```

| Key payload | Tipe | Default | Arti |
|---|---|---|---|
| `Is_Urgent` | integer 0/1 | 0 | 1 = urgent, 0 = normal |
| `Urgent Remark` | teks | kosong | alasan / keterangan urgent, maksimal 255 karakter |

Aturan baca:

- **Key `Urgent Remark` memakai spasi**, persis seperti contoh bisnis. Key dibaca tanpa membedakan huruf besar/kecil, dan alias berikut juga diterima: `is_urgent`, `isurgent`, `urgent_remark`, `urgent remark`, `urgentremark`.
- `Is_Urgent` bernilai `1` atau `"1"` → disimpan 1. **Selain 1 → 0**: `0`, kosong, key tidak ada, `true`, `"Y"`, `2`, teks apa pun. Tanpa error dan tanpa kode `POS-xxx` baru.
- Kedua field **opsional**. Payload lama tanpa field ini tetap diterima dan dianggap tidak urgent.
- `Urgent Remark` **tidak wajib** walau `Is_Urgent` = 1 (remark berasal dari POS). Kosong disimpan `NULL`; teks lebih dari 255 karakter dipotong tanpa error.
- Nilai berlaku **per line** (`coline`), mengikuti Customer Order Blanket Line.
- Field ini tidak ikut aturan validasi apa pun: tidak ada kode `POS-xxx` baru, dan tidak ada penolakan order karena nilainya.

## Alur data

```text
Payload JSON  [{ ..., "Is_Urgent": 1, "Urgent Remark": "..." }]
 → SMK069ReceivePosSalesJsonSp
 → SMK069ReceivePosSalesJsonCoreSp
     inbound.raw_json                       (payload apa adanya)
     PATCH-36 blok 1: inbound.is_urgent / urgent_remark   (sebelum mapping view)
     mapping view → #MapView → INSERT temp
     PATCH-36 blok 2: temp.is_urgent / urgent_remark      (key: SiteRef + co_num + co_line + cust_po)
 → SMK069ProcessBatchCustomerOrdersSp
 → SMK069ProcessCustomerOrderSp
     INSERT co_bln_mst (..., Uf_SMK069_is_urgent, Uf_SMK069_urgent_remark)
```

`ue_SMK069_pos_sales_inbound_mapping_view` (milik Eva / SMK) **tidak diubah**. Nilai urgent diambil dari inbound, bukan dari view.

## Objek yang berubah

| Objek | Perubahan |
|---|---|
| `ue_SMK069_pos_sales_inbound_mst` | + `is_urgent INT NOT NULL DEFAULT 0`, + `urgent_remark NVARCHAR(255) NULL` |
| `ue_SMK069_temp_sales_mst` | + `is_urgent INT NOT NULL DEFAULT 0`, + `urgent_remark NVARCHAR(255) NULL` |
| `SMK069ReceivePosSalesJsonCoreSp` | 2 blok `PATCH-36` (baca payload ke inbound; sync inbound ke temp) |
| `SMK069ProcessCustomerOrderSp` | kedua `INSERT INTO co_bln_mst` (insert utama dan cabang repair) membawa 2 kolom UET |
| `co_bln_mst` (UET) | + `Uf_SMK069_is_urgent`, + `Uf_SMK069_urgent_remark` — **dibuat lewat Mongoose, bukan SQL** |
| Form Customer Order Blanket Lines | + checkbox dan field teks — **metadata Mongoose** |
| `ue_SMK069_pos_csv_upload_mst`, `SMK069ImportCsvFileSp`, `SMK069RunCsvTestBatchSp`, form CSV | Jalur CSV — **Patch 37**, lihat bagian "Jalur CSV" di bawah |

Signature procedure tidak berubah, jadi metadata IDO method tidak perlu disentuh.

## Langkah 1 — UET pada `co_bln_mst`

Mengikuti pola `itemcust_mst` (lihat `44-uet-itemcust-peak-season-pos-um.md`).

```text
User Field Name : Uf_SMK069_is_urgent
User Data Type  : int
Decimals        : 0
Initial Value   : 0
Description     : Flag order urgent dari payload API Sales

User Field Name : Uf_SMK069_urgent_remark
User Data Type  : <blank / tanpa UDT>
Data Type       : nvarchar
Length          : 255
Description     : Keterangan urgent dari payload API Sales
```

Class dan table extension:

```text
Class Name         : SMK069_CL_co_bln
Fields             : Uf_SMK069_is_urgent, Uf_SMK069_urgent_remark

Table Name         : co_bln_mst
Class Name         : SMK069_CL_co_bln
Active             : 1
Extend All Records : 1
```

Setelah itu jalankan **Impact Schema** seperti pada `itemcust_mst`. Jangan menambah kolom fisik dengan `ALTER TABLE` manual lalu menjalankan Impact Schema sesudahnya: Impact Schema akan mencoba menambah kolom yang sudah ada.

Verifikasi di database:

```sql
SELECT c.name, t.name AS type_name, c.max_length
FROM sys.columns AS c
JOIN sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.co_bln_mst')
  AND c.name IN (N'Uf_SMK069_is_urgent', N'Uf_SMK069_urgent_remark');
-- harapan: int (4) dan nvarchar (510 byte = 255 karakter)
```

Patch 36 berhenti di precheck bila kolom ini belum ada atau `urgent_remark` lebih pendek dari 255 karakter.

## Langkah 2 — Patch 36

Urutan:

```text
1. UET co_bln_mst + Impact Schema (Langkah 1)
2. Script-out SMK069ReceivePosSalesJsonCoreSp dan SMK069ProcessCustomerOrderSp dari tenant (cadangan rollback)
3. Jalankan 2026-10-14-smk069-36-urgent-flag.sql — satu batch, tanpa GO
4. UAT (di bawah)
5. Tambahkan field ke form Customer Order Blanket Lines (Langkah 3)
```

### Kenapa patch mengedit definisi yang sedang aktif

Catatan delta 12 Okt 2026 (`deployment/csv-to-co/prod/07-trn-to-prd-delta-2026-10-12.md`) menyebut source canonical Core dan Receive di repo **tertinggal** dari TRN (retry BatchId yang sama + history). Kalau Patch 36 menimpa Core dengan salinan repo, perubahan TRN itu hilang.

Maka patch ini membaca `OBJECT_DEFINITION` dari tenant, menyisipkan blok `PATCH-36` pada teks anchor, lalu `CREATE OR ALTER` ulang:

- Semua anchor dicek **dulu** untuk semua procedure. Anchor tidak ditemukan atau ditemukan lebih dari sekali → `THROW`, tidak ada procedure yang diubah.
- Re-runnable: procedure yang sudah memuat `PATCH-36` dilewati.
- Bila **versi pertama** Patch 36 (remark 250, `true` dianggap urgent) sudah pernah dijalankan, jalankan ulang file ini: blok `PATCH-36` di Core diperbarui otomatis (edit upgrade U1–U3) dan kolom `urgent_remark` dilebarkan ke 255. Source `SMK069ProcessCustomerOrderSp` tidak berubah antar versi.
- Perubahan procedure dalam satu transaksi.
- Akhir baris CRLF/LF tidak berpengaruh (dinormalkan sebelum dibandingkan).

File canonical di repo sudah memuat blok yang sama. Hasil patch pada source HEAD identik dengan file canonical (sudah dicek saat patch dibangkitkan).

### Bila patch berhenti karena anchor

Pesan error menyebut anchor mana dan berapa kali ditemukan. Artinya definisi TRN/PRD berbeda dari repo di titik itu. Pasang manual dengan menyalin blok `PATCH-36` dari file canonical:

```text
SMK069ReceivePosSalesJsonCoreSp
  blok 1: sebelum komentar "3. Snapshot BUSINESS SOURCE from mapping view"
          (setelah UPDATE inbound yang mengisi is_peak_season, sebelum #MapView dibuat)
  blok 2: tepat setelah INSERT ke ue_SMK069_temp_sales_mst
          dan baris "SET @TransferredRows = @@ROWCOUNT;"

SMK069ProcessCustomerOrderSp
  kedua INSERT INTO dbo.co_bln_mst:
    daftar kolom : + Uf_SMK069_is_urgent, Uf_SMK069_urgent_remark (sebelum allow_on_pick_list)
    daftar nilai : + ISNULL(s.is_urgent, 0), s.urgent_remark      (sebelum 0 untuk allow_on_pick_list)
```

## Langkah 3 — Form Customer Order Blanket Lines

Metadata Mongoose (tidak ada di repo SQL). Pada Form Editor untuk form Customer Order Blanket Lines (IDO sumbernya dicek di Form Editor; kemungkinan `SLCoBlns`):

```text
Is Urgent?      checkbox  → property Uf_SMK069_is_urgent
Urgent Remark   text      → property Uf_SMK069_urgent_remark
```

Setelah Impact Schema, property `Uf_*` biasanya sudah muncul di IDO. Bila belum, refresh metadata IDO. Keputusan bisnis (14 Okt 2026): kedua field **read-only dan disabled** (`Enabled = False`), karena nilainya berasal dari POS. User hanya melihat, tidak mengubah.

## UAT

Siapkan item, customer, dan harga yang valid di tenant. Nilai `B005` / `POSITEM001` pada contoh hanya ilustrasi kontrak.

| # | Skenario | Harapan |
|---|---|---|
| U1 | Payload contoh bisnis (kedua line `Is_Urgent` 0, remark kosong) | CO dibuat; `co_bln_mst.Uf_SMK069_is_urgent` 0 dan `Uf_SMK069_urgent_remark` NULL di kedua line |
| U2 | Line 1 `Is_Urgent` 1, `Urgent Remark` "Kirim pagi"; line 2 `Is_Urgent` 0 | Line 1: 1 + "Kirim pagi"; line 2: 0 + NULL. Satu `cust_po`, dua nilai berbeda |
| U3 | Payload lama tanpa kedua key | Sukses seperti sebelumnya; kedua line 0 + NULL |
| U4 | Alias: `"is_urgent": 1`, `"urgent_remark": "x"` | Sama dengan `Is_Urgent` 1 dan remark "x" |
| U5 | `Urgent Remark` 300 karakter | Sukses; tersimpan 255 karakter pertama |
| U6 | `"Is_Urgent"` = `"Y"`, `2`, `true`, atau `"abc"` | Sukses; disimpan 0 (selain 1 → 0) |
| U7 | Order urgent dengan quantity salah (POS-108) | Ditolak seperti biasa, tidak ada CO; inbound berisi `is_urgent` 1 |
| U8 | Kirim ulang BatchId sukses yang sama | Tidak ada CO kedua; nilai tidak berubah |
| U9 | Buka form Customer Order Blanket Lines pada CO hasil U2 | Checkbox dan remark tampil sesuai nilai per line, dan keduanya disabled |
| U10 | `Is_Urgent` 1 dengan `Urgent Remark` kosong | Sukses; urgent 1, remark NULL (remark tidak wajib) |

Query verifikasi (ganti `<BatchId>` dan `<CustPo>`):

```sql
-- 1. inbound
SELECT row_no, cust_po, co_line, is_urgent, urgent_remark, inbound_status, validation_msg
FROM dbo.ue_SMK069_pos_sales_inbound_mst
WHERE batch_id = N'<BatchId>'
ORDER BY row_no;

-- 2. staging temp
SELECT cust_po, co_line, is_urgent, urgent_remark, process_status, created_co_num
FROM dbo.ue_SMK069_temp_sales_mst
WHERE cust_po = N'<CustPo>'
ORDER BY co_line;

-- 3. Customer Order Blanket Line
SELECT b.co_num, b.co_line, b.item, b.Uf_SMK069_is_urgent, b.Uf_SMK069_urgent_remark
FROM dbo.co_bln_mst AS b
WHERE b.co_num IN (SELECT created_co_num FROM dbo.ue_SMK069_temp_sales_mst WHERE cust_po = N'<CustPo>')
ORDER BY b.co_line;
```

Ketiga query harus menunjukkan nilai yang sama per `co_line`.

## Jalur CSV — Patch 37

Selain Postman, pengujian memakai form **SMK POS CSV TO BLANKET CO** (`ue_SMK069PosCsvBatchConsole`). Form itu tidak lewat payload JSON dari POS, jadi Patch 36 saja belum cukup: JSON hasil CSV belum membawa urgent. Patch 37 menutup celah itu.

```text
file CSV
 → SMK069ImportCsvFileSp          parse header + baris, tulis ke detail CSV
     PATCH-37: is_urgent / urgent_remark → @ParsedUrgent → UPDATE detail sebelum COMMIT
 → ue_SMK069_pos_csv_upload_mst   + is_urgent INT NOT NULL DEFAULT 0, + urgent_remark NVARCHAR(255) NULL
 → SMK069RunCsvTestBatchSp        bentuk JSON
     PATCH-37: JSON ikut membawa "is_urgent" dan "urgent_remark"
 → SMK069ReceivePosSalesJsonSp → Core (Patch 36) → co_bln_mst
```

Kolom CSV bersifat opsional dan aturannya sama dengan payload API:

| Header CSV (huruf besar/kecil bebas) | Arti |
|---|---|
| `is_urgent`, `isurgent`, `Is_Urgent`, `Is Urgent` | 1 = urgent; selain 1 (kosong, 0, `Y`, 2, teks) = 0, tanpa error |
| `urgent_remark`, `urgentremark`, `Urgent Remark` | Teks bebas, tidak wajib, kosong = NULL, dipotong 255 karakter |

Nama header dinormalisasi parser (huruf kecil, spasi dan `-` menjadi `_`), jadi header `Urgent Remark` dengan spasi otomatis cocok. CSV lama tanpa kedua kolom tetap diterima dan hasilnya Normal (0 / NULL). Tidak ada kode `POS-xxx` baru.

### Urutan pemasangan

1. **Patch 36 harus sudah terpasang.** Patch 37 berhenti di precheck (error 510384) bila Core belum memuat blok Patch 36.
2. Jalankan `database/patches/csv-to-co/2026-10-14-smk069-37-urgent-flag-csv.sql` lewat Apply Database (satu batch, tanpa GO). Cara kerjanya sama dengan Patch 36: definisi aktif `SMK069ImportCsvFileSp` dan `SMK069RunCsvTestBatchSp` diedit in-place pada anchor yang harus ada tepat sekali, semuanya atau tidak sama sekali. Bila anchor tidak cocok, patch berhenti dengan error 510386 dan menyebut anchor yang gagal; kirim pesannya agar anchor bisa disesuaikan. Sebelum menjalankan, script-out kedua procedure sebagai cadangan.
3. **Resynchronize IDO `ue_SMK069PosCsvUpload`** agar property `IsUrgent` dan `UrgentRemark` muncul.
4. Pasang kolom grid pada form (lihat `forms/csv-to-co/04-SMK069PosCsvBatchConsole-Urgent.md`): import XML siap pakai, atau tambah dua kolom manual.

### UAT jalur CSV

File contoh ada di `tests/payloads/csv-urgent/`. Upload lewat tombol **Upload & Process CSV to CO**, atau **Upload Only** lalu **Retry / Process CO**. Setiap file memakai `cust_po` berbeda, jadi tidak bentrok satu sama lain; bila ingin mengulang file yang sama, ubah `cust_po` di dalam file.

| # | File | Harapan |
|---|---|---|
| C1 | `csv-u2-urgent-and-normal.csv` | Grid CSV: baris 1 Is Urgent tercentang + "Kirim pagi", baris 2 tidak tercentang. CO dibuat; `co_bln_mst` line 1 = 1 + "Kirim pagi", line 2 = 0 + NULL |
| C2 | `csv-u3-old-format-no-urgent-columns.csv` | Sukses seperti sebelumnya; kedua line 0 + NULL |
| C3 | `csv-u6-non-one-becomes-zero.csv` | Sukses; `Y` dan `2` tersimpan 0; remark "salah format" tetap tersimpan |
| C4 | `csv-u4-contract-header-names.csv` (header `Is_Urgent`, `Urgent Remark`; remark berisi koma dalam tanda kutip) | Line 1 = 1 + "Kirim pagi, sebelum jam 8"; line 2 = 0 + NULL |
| C5 | Upload ulang CSV yang sama lewat **Re-Parse CSV** sebelum diproses | Detail CSV dibangun ulang dengan nilai urgent yang sama |
| C6 | Buka form Customer Order Blanket Lines pada CO hasil C1 | Checkbox dan remark tampil per line, keduanya disabled |

Cek per tahap (ganti `<BatchId>` dengan Batch Id yang tampil di form dan `<CustPo>` dengan `cust_po` file):

```sql
-- 1. detail CSV (yang tampil di grid form)
SELECT row_no, cust_po, coline, is_peak_season, is_urgent, urgent_remark, upload_status, result_message
FROM dbo.ue_SMK069_pos_csv_upload_mst
WHERE batch_id = N'<BatchId>'
ORDER BY row_no;

-- 2. inbound, 3. temp, 4. co_bln_mst: pakai query pada bagian UAT di atas
```

Bila tahap 1 benar tetapi inbound salah: JSON belum membawa nilai (cek `SMK069RunCsvTestBatchSp`). Bila tahap 1 sudah salah: parser (`SMK069ImportCsvFileSp`) atau nama header CSV.

## Keputusan desain

- **Selain 1 → 0, tanpa penolakan** (keputusan bisnis 14 Okt 2026). Hanya `1` / `"1"` yang menjadi urgent; `"Y"`, `2`, `true` tersimpan 0 tanpa pesan error, dan tidak ada kode `POS-xxx` baru. Konsekuensinya POS yang salah kirim format tidak mendapat peringatan.
- **Nilai disimpan di inbound lebih dulu, lalu temp, lalu `co_bln_mst`.** Temp menjadi satu-satunya sumber bagi `SMK069ProcessCustomerOrderSp`, sama seperti field lain.
- **`UPDATE` setelah `INSERT` untuk inbound dan temp**, bukan menambah kolom ke daftar kolom `INSERT`. Tabel `ue_` punya trigger `INSTEAD OF INSERT` hasil generate Mongoose yang daftar kolomnya bisa belum memuat kolom baru (kasus `is_peak_season` di DEV, lihat `deployment/csv-to-co/prod/04-mongoose-metadata-checklist.md`). `UPDATE` tidak melewati trigger itu, jadi nilai urgent tetap tersimpan.
- **Mapping view tidak disentuh.** Urgent tidak memengaruhi mapping item/harga.
- **Insert langsung ke kolom UET saat membuat line**, bukan `UPDATE` sesudahnya, sehingga baris `co_bln_mst` tidak disentuh dua kali.

## Belum dikerjakan

- **Form Error Processing**: tidak menampilkan urgent. Bisa ditambah seperti checkbox Peak Season bila diminta.
- **Tabel history inbound** (`ue_SMK069_pos_sales_inbound_hist`): tidak ditambah kolom urgent. Source archive retry TRN belum ada di repo, jadi tidak aman menambah kolom `NOT NULL` ke history tanpa melihat statement archive-nya.
- **Paket PROD** (`deployment/csv-to-co/prod/`): `02-deploy-canonical-runtime.sql` sengaja tidak dibangkitkan ulang karena Core/Receive canonical belum disinkronkan dari TRN. Item yang harus ikut saat regenerasi dicatat di `07-trn-to-prd-delta-2026-10-12.md` bagian 10.
- **Status eksekusi.** Patch 36 sudah dijalankan di DEV lewat Apply Database (14 Okt 2026, selesai tanpa error). Patch 37 (jalur CSV) belum dijalankan. Hasil UAT belum tercatat; UAT wajib dijalankan di DEV/TRN dulu.

## Keputusan bisnis — 14 Oktober 2026

```text
Urgent Remark wajib bila Is_Urgent = 1 : TIDAK (remark datang dari POS)
Is_Urgent selain 1                      : jadi 0, tanpa error, tanpa kode POS baru
Field di form Blanket Line              : read-only dan disabled
Panjang Urgent Remark                   : 255 karakter (permintaan tim POS)
```

## Pertanyaan terbuka

1. Key `Urgent Remark` memakai spasi — sudah disepakati dengan tim POS, atau bisa distandarkan ke `urgent_remark`? Keduanya diterima sekarang.
