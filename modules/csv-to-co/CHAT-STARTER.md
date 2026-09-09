# Chat Starter — CSV → Blanket Customer Order

Copy seluruh prompt berikut ke chat baru agar pembahasan tidak tercampur dengan Shipment:

```text
Kita lanjut project private GitHub `youhunt/api-pos-syteline`, tetapi CHAT INI KHUSUS WORKSTREAM:

CSV / POS INBOUND → BLANKET CUSTOMER ORDER

Jangan membawa pembahasan Shipment outbound, DN scheduler, retry Shipment, endpoint infor_dn, atau TaskMan Shipment ke chat ini kecuali saya secara eksplisit memintanya.

Repository sudah dipisahkan. Mulai dari:
- modules/csv-to-co/README.md
- docs/csv-to-co/30-csv-to-customer-order-one-hit.md
- database/patches/csv-to-co/
- database/procedures/csv-to-co/
- database/stored-procedures/csv-to-co/
- forms/csv-to-co/
- ido/csv-to-co/
- implementation/csv-to-co/

Target akhir:
CSV / POS JSON → Receive / Validate → ue_SMK069_temp_sales_mst → SMK069ProcessBatchCustomerOrdersSp → SMK069ProcessCustomerOrderSp → Blanket Customer Order type B pada:
- co_mst
- coitem_mst
- co_bln_mst

Entry point:
- Direct JSON/Postman one-hit: SMK069ReceiveAndProcessPosSalesJsonSp
- CSV one-hit: SMK069RunCsvTestBatchSp

Status terakhir 9 Sep 2026:
- Batch UAT: CSV-20260909-072038-835E3D
- CSV parse berhasil: Rows=2, FormatErrors=0
- Detail:
  Row 1 DEV4 | cust_po DEV4-216 | whse PLG | AC20002B | qty 375 PCS
  Row 2 DEV4 | cust_po DEV4-216 | whse PLG | AC20003B | qty 120 PCS
- Sebelumnya POS-402 karena standard Mongoose SiteRef detail tidak sesuai.
- Business field CSV `siteref` boleh kosong.
- Patch 13 Rev.3 sudah berhasil di-apply.
- Batch yang sama boleh langsung dijalankan ulang; tidak perlu New Batch atau Re-Parse kecuali file CSV berubah.

Keterbatasan tenant:
- Apply Database bukan SSMS; patch harus cocok untuk satu executable batch dan tanpa GO.
- Verification SELECT dilakukan terpisah di Query Select.

Cara kerja yang saya inginkan:
1. Audit source repo dulu sebelum menyimpulkan.
2. Kalau ada bug, patch langsung ke GitHub `main`, jangan hanya memberi contoh code.
3. Jangan invent schema tenant yang belum terbukti.
4. Setelah patch laporkan: Commit SHA, file berubah, ringkasan, cara apply/test, dan SQL/migration bila ada.
5. Jaga idempotency dan jangan membuat batch baru hanya untuk retry kalau batch lama masih aman digunakan.

Lanjutkan dari hasil/error CSV → CO terbaru yang saya kirim setelah prompt ini.
```
