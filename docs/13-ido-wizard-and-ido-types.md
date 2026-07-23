# 13 — IDO Wizard and Architectural IDO Roles

## Status

Dokumen ini menjelaskan perbedaan antara **IDO sebagai object teknis Mongoose** dan istilah **Entity IDO, Monitor/Composite IDO, serta Service IDO** yang digunakan sebagai pembagian tanggung jawab pada arsitektur project ini.

Istilah tiga jenis IDO tersebut adalah **architectural roles**, bukan tiga tipe object resmi yang berbeda pada layar Mongoose. Secara teknis semuanya tetap berupa IDO Mongoose yang memiliki properties, tables, dan/atau methods.

## Jawaban Ringkas tentang Wizard

Benar: untuk IDO yang langsung mewakili tabel, proses normalnya menggunakan **New IDO / IDO Wizard**.

Alur umumnya:

```text
Tabel sudah tersedia pada IDO Project
        ↓
Open IDOs / IDO Projects form
        ↓
New IDO
        ↓
Pilih Project Name
        ↓
Pilih Primary Base Table
        ↓
Tentukan IDO Name dan alias
        ↓
Generate/pilih properties
        ↓
Next → review → Finish
        ↓
Check In
```

Wizard membantu membuat metadata awal. Setelah wizard selesai, tetap diperlukan review terhadap:

- property name;
- primary key;
- required/read-only behavior;
- update permissions;
- default order;
- secondary tables;
- subcollections;
- methods;
- security;
- form binding;
- REST exposure.

## 1. Entity IDO

### Maksudnya

Entity IDO adalah IDO yang fokus mewakili satu tabel bisnis atau staging.

Contoh project ini:

```text
Table : SMK_RSC_POS_Batch_mst
IDO   : SMKRSCPosBatches
```

```text
Table : SMK_RSC_POS_RawLine_mst
IDO   : SMKRSCPosRawLines
```

Entity IDO dipakai untuk:

- `LoadCollection`;
- menampilkan data pada grid/form;
- filter dan sorting;
- melihat satu record;
- menjadi parent atau child collection;
- controlled update jika memang diizinkan.

### Cara membuat

Entity IDO paling cocok dibuat melalui IDO Wizard karena sudah memiliki primary base table yang jelas.

Contoh:

```text
Project Name       : SMK_RSC_POS
Primary Base Table : SMK_RSC_POS_Batch_mst
IDO Name           : SMKRSCPosBatches
Table Alias         : b
```

Wizard membuat kerangka IDO dan properties dari kolom tabel. Setelah itu metadata diperiksa dan disesuaikan.

### Hubungan dengan form

```text
Custom Form Batch Monitoring
             ↓ binding
SMKRSCPosBatches
             ↓
SMK_RSC_POS_Batch_mst
```

Jadi kalimat **query data dan binding custom form** berarti form mengambil dan menampilkan data melalui IDO, bukan query langsung ke tabel.

## 2. Monitor/Composite IDO

### Maksudnya

Monitor/Composite IDO adalah IDO yang digunakan untuk tampilan gabungan, dashboard, atau monitoring lintas tabel.

Contoh kebutuhan:

```text
Batch Number
Status Batch
Jumlah Transaction
Jumlah Error Line
Total Debit
Total Credit
Balance Difference
Last Error Message
```

Informasi tersebut berasal dari beberapa tabel, bukan hanya `Batch_mst`.

### Bentuk teknis

Monitor IDO masih merupakan IDO biasa. Implementasinya dapat berupa salah satu pola berikut:

1. IDO berbasis database view;
2. IDO dengan primary base table ditambah secondary tables;
3. IDO dengan derived/unbound properties;
4. IDO dengan custom load method;
5. kombinasi pola di atas.

Contoh:

```text
Database View : SMK_RSC_POS_BatchMonitor_v
IDO           : SMKRSCPosBatchMonitor
Mode          : Read-only
```

atau:

```text
Primary Table   : SMK_RSC_POS_Batch_mst
Secondary Table : aggregated process/error source
IDO             : SMKRSCPosBatchMonitor
```

### Apakah memakai wizard?

Bisa dimulai dengan wizard, terutama bila memakai table/view sebagai primary base table. Namun join, secondary table, derived property, custom load, dan read-only policy biasanya perlu dilanjutkan manual setelah wizard.

Monitor IDO tidak dipakai untuk mengubah transaksi sumber atau menjalankan posting.

## 3. Service IDO

### Maksudnya

Service IDO adalah IDO yang fokus menyediakan **methods** untuk menjalankan proses bisnis.

Candidate service IDO project ini:

```text
SMKRSCPosIntegration
```

Candidate methods:

```text
ReceiveCompleteBatch
ReceiveMinimalBatch
ValidateBatch
RetryBatch
GeneratePostingPreview
ApprovePostingPreview
PostBatch
CancelBatch
PurgeInboundPayload
```

Pemanggilan utamanya menggunakan `Invoke`, bukan direct CRUD.

```text
Postman / REST
       ↓ Invoke
SMKRSCPosIntegration.ReceiveMinimalBatch
       ↓
Create Inbound + Batch + Raw Lines + Process Log
```

### Apakah Service IDO object khusus?

Tidak. Service IDO adalah istilah arsitektur project ini. Secara teknis tetap IDO Mongoose.

IDO Mongoose baru umumnya membutuhkan primary base table, kecuali dibuat sebagai extension dari IDO lain. Karena itu candidate implementasi service IDO harus memilih salah satu pola:

#### Opsi A — Berbasis Batch table

```text
IDO Name           : SMKRSCPosIntegration
Primary Base Table : SMK_RSC_POS_Batch_mst
Collection Usage   : dibatasi
Method Usage       : utama
```

Kelebihan:

- tidak menambah service table baru;
- method secara alami berhubungan dengan batch;
- cocok untuk PoC.

#### Opsi B — Extend IDO lain

Service IDO dapat meng-extend IDO yang sesuai, kemudian menambahkan custom methods.

#### Opsi C — Dedicated control table

Membuat tabel kontrol khusus hanya bila benar-benar dibutuhkan oleh standar tenant. Opsi ini belum direkomendasikan karena menambah tabel tanpa kebutuhan source resmi.

Untuk PoC project ini, kandidat awal adalah **Opsi A**, dengan collection write dibatasi dan proses utama dilakukan melalui methods.

### Cara menambahkan method

Setelah IDO tersedia dan di-check-out:

```text
IDO / IDO Methods form
        ↓
New Method
        ↓
IDO Method Wizard
        ↓
Pilih Stored Procedure atau Extension Class
        ↓
Tentukan Method Name
        ↓
Atur Transactional bila diperlukan
        ↓
Finish → Check In
```

Method dapat berbasis:

- stored procedure;
- IDO extension class method.

Operasi receive yang menyentuh beberapa tabel harus menggunakan transaction boundary yang jelas.

## Perbandingan Praktis

| Role | Secara teknis | Base data | Penggunaan utama | Wizard |
|---|---|---|---|---|
| Entity IDO | IDO biasa | Satu primary table | Query/form binding | Ya, paling langsung |
| Monitor/Composite IDO | IDO biasa | View/table + join/derived/custom load | Dashboard read-only | Bisa, lalu dilanjutkan manual |
| Service IDO | IDO biasa dengan methods | Table atau extend IDO | Invoke proses bisnis | IDO Wizard + IDO Method Wizard |

## Analogi Sederhana

```text
Entity IDO  = lemari arsip
Monitor IDO = layar ringkasan isi banyak lemari
Service IDO = petugas yang menerima, memeriksa, memproses, dan memindahkan arsip
```

Pada project ini:

```text
SMKRSCPosBatches
= membuka dan melihat arsip batch

SMKRSCPosBatchMonitor
= melihat ringkasan batch, jumlah error, dan balance dalam satu layar

SMKRSCPosIntegration.ValidateBatch
= menjalankan validasi batch dan menulis hasilnya
```

## Rekomendasi Implementasi Project

### Tahap pertama

Buat entity IDO menggunakan wizard:

```text
SMKRSCPosInbounds
SMKRSCPosBatches
SMKRSCPosRawLines
SMKRSCPosItemMaps
SMKRSCPosProcessLogs
```

### Tahap kedua

Buat form sederhana untuk memastikan `LoadCollection`, filter, dan subcollection berjalan.

### Tahap ketiga

Buat service IDO dan method minimum:

```text
ReceiveMinimalBatch
ValidateBatch
RetryBatch
```

### Tahap keempat

Buat monitor/composite IDO setelah kebutuhan dashboard sudah jelas. Monitor tidak perlu dipaksakan dibuat sejak awal.

## Kesimpulan

Wizard memang mengikuti tabel untuk membuat kerangka IDO. Pembagian Entity, Monitor, dan Service tidak berarti terdapat tiga wizard yang berbeda.

```text
Entity  → IDO hasil wizard dari table
Monitor → IDO read-only untuk gabungan/summary
Service → IDO yang diberi methods untuk proses bisnis
```

Entity IDO dibuat lebih dahulu. Monitor dan service dikembangkan setelah kebutuhan query gabungan serta proses bisnisnya jelas.