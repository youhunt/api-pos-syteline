# 09 — Open Questions

Dokumen ini berisi pertanyaan yang harus dijawab sebelum desain dianggap final.

## Data Source dan Pengiriman

1. POS mengirim data langsung ke SyteLine atau melalui middleware?
2. Mekanisme push, pull, file import, atau kombinasi?
3. Frekuensi pengiriman: real-time, per jam, closing harian, atau periode bebas?
4. Satu request hanya satu outlet atau dapat berisi banyak outlet?
5. Source menyediakan `externalBatchNum` dan `requestId` yang benar-benar unik?
6. Bagaimana mekanisme resend jika POS timeout?
7. Berapa volume transaksi, item line, dan payment line per hari?
8. Berapa ukuran request maksimum?
9. Apakah payload dikompresi?
10. Timezone dan aturan business-date cutoff?

## Transaction Model

1. Tipe transaksi yang tersedia: sale, void, refund, cancel, complimentary?
2. Void/refund dikirim sebagai transaksi baru, negative amount, atau update?
3. Bagaimana referensi ke transaksi original?
4. Apakah receipt number unik per outlet/per date atau global?
5. Apakah transaksi dapat diubah setelah closing?
6. Apakah transaksi offline dikirim terlambat?

## Item dan Quantity

1. Apakah item POS sama dengan item SyteLine?
2. Apakah package/combo dikirim sebagai parent-child lines?
3. Apakah modifier/topping perlu diproses sebagai inventory?
4. Quantity menggunakan U/M apa?
5. Apakah perlu conversion factor?
6. Apakah quantity digunakan untuk inventory posting atau hanya reporting?
7. Bagaimana waste, complimentary, cancellation, dan recipe consumption diperlakukan?

## Payment dan Settlement

1. Payment methods apa saja yang dikirim?
2. Apakah split payment didukung?
3. Apakah QRIS/card reference dikirim?
4. Apakah aggregator dianggap payment atau receivable?
5. Apakah settlement datang pada payload yang sama atau file/API terpisah?
6. Bagaimana fee, commission, promo subsidy, MDR, dan deduction dikirim?
7. Bagaimana voucher/gift card diperlakukan?
8. Apakah cash over/short tersedia?

## Finance dan Posting

1. Jalur final: GL, AR, Customer Order, Inventory, atau hybrid?
2. Posting per receipt, per outlet/date, per category/payment, atau per batch?
3. Chart of Accounts dan unit code mapping?
4. Treatment discount?
5. Treatment tax/PB1/VAT?
6. Treatment service charge?
7. Treatment rounding?
8. Treatment refund lintas periode?
9. Apa yang dilakukan bila accounting period sudah closed?
10. Apakah posting memerlukan approval?
11. Bagaimana reversal jika posting sudah berhasil tetapi source direvisi?

## SyteLine Technical

1. Versi SyteLine/Mongoose yang digunakan?
2. REST API path dan authentication standard environment?
3. Apakah custom IDO Extension Class diperbolehkan di Cloud tenant?
4. Apakah custom stored procedure diperbolehkan dan bagaimana deployment-nya?
5. Apakah background task/TaskMan tersedia untuk custom process?
6. Bagaimana mekanisme package export/import antar environment?
7. Apakah foreign key fisik direkomendasikan atau dihindari?
8. Apakah `SiteRef` harus masuk seluruh primary key custom table pada tenant ini?
9. Bagaimana view custom table dibentuk?
10. Apakah ada naming convention resmi selain prefix `SMK_` dan physical `ue_`?

## Security dan Operations

1. Authentication dan service account?
2. IP whitelist/VPN/API gateway?
3. TLS/certificate requirement?
4. Rate limit?
5. Data retention staging dan process log?
6. Siapa yang memonitor error?
7. Siapa yang boleh retry/cancel/process?
8. SLA penerimaan dan posting?
9. Bagaimana alert untuk batch gagal?
10. Apakah payload mentah boleh disimpan berdasarkan policy perusahaan?

## Decision Log Template

Setelah pertanyaan dijawab, catat:

```text
Decision ID:
Date:
Topic:
Decision:
Reason:
Approved By:
Effective Date:
Impacted Objects:
Follow-up:
```
