# 06 — Financial Posting Options

> Jalur posting final belum diputuskan. Dokumen ini menjadi bahan diskusi dengan Finance dan SyteLine functional consultant.

## Tujuan

Mengubah data POS yang sudah tervalidasi menjadi transaksi SyteLine yang dapat digunakan untuk laporan keuangan dan, bila dibutuhkan, inventory.

## Opsi A — General Ledger Journal

```text
POS Staging
   → summarize per date/outlet/account
   → General Journal
   → Post Journal
   → General Ledger
```

### Kelebihan

- Paling sederhana untuk volume tinggi.
- Tidak membuat ribuan customer order/invoice.
- Cocok untuk rekap penjualan harian.
- Mudah direkonsiliasi per outlet/periode.

### Kekurangan

- Detail customer/order tidak tersedia di modul operasional.
- Settlement aggregator dan receivable perlu desain khusus.
- Inventory tidak otomatis berkurang kecuali dibuat proses tambahan.

### Contoh Jurnal Tunai/QRIS

```text
Debit  Cash / QRIS Clearing
Credit Food Sales
Credit Beverage Sales
Credit Tax Payable
Credit Service Charge Revenue
```

## Opsi B — Accounts Receivable Transaction

```text
POS Staging
   → AR transaction/invoice
   → AR posting
   → GL
```

### Cocok untuk

- Penjualan melalui aggregator.
- Piutang terhadap GoFood/GrabFood/partner.
- Settlement tidak diterima pada hari transaksi.
- Rekonsiliasi receivable dan deduction/commission.

### Contoh Penjualan Aggregator

Saat penjualan:

```text
Debit  Receivable - Aggregator
Credit Sales Revenue
Credit Tax Payable
```

Saat settlement:

```text
Debit  Bank
Debit  Commission Expense
Debit  Other Deduction (bila ada)
Credit Receivable - Aggregator
```

## Opsi C — Customer Order → Shipment → Invoice

```text
POS Staging
   → Customer Order
   → Shipment
   → Invoice
   → AR
   → GL
```

### Kelebihan

- Jejak transaksi operasional lengkap.
- Dapat berinteraksi dengan inventory dan invoicing standard.

### Kekurangan

- Berpotensi terlalu berat untuk transaksi restoran berjumlah besar.
- Membuat volume dokumen SyteLine sangat tinggi.
- Memerlukan customer, item, warehouse, price, tax, shipment, dan posting rules lengkap.

## Opsi D — Hybrid Finance + Inventory

```text
Sales/payment value → GL or AR
Item/quantity       → inventory consumption/issue
```

Kemungkinan paling realistis bila perusahaan membutuhkan laporan finansial sekaligus kontrol penggunaan inventory.

## Posting Granularity

Pilihan granularitas:

| Level | Kelebihan | Risiko |
|---|---|---|
| Per receipt | Audit detail tinggi | Volume transaksi sangat besar |
| Per outlet per day | Balance antara detail dan volume | Perlu drill-down ke staging |
| Per payment/category per day | Posting efisien | Detail hanya tersedia di staging |
| Per batch | Sangat sederhana | Rekonsiliasi lebih sulit bila batch multi-date |

Rekomendasi awal untuk PoC: buat preview **per outlet + business date + account + unit code**, tetapi simpan detail receipt pada staging.

## Candidate Posting Preview Columns

```text
batch_num
business_date
outlet_code
posting_seq
posting_type
acct
unit_code1
unit_code2
unit_code3
unit_code4
debit_amt
credit_amt
currency_code
source_reference
mapping_source
validation_status
error_message
```

## Rekonsiliasi Minimum

Sebelum posting:

```text
Total Debit = Total Credit
```

Selain itu:

```text
SUM(POS net sales) = revenue + tax + service + rounding treatment
SUM(payment)       = cash/bank/receivable/voucher/control accounts
SUM(settlement)    = bank + fee/deduction treatment
```

## Area yang Harus Diputuskan Finance

1. Penjualan diakui gross atau net of discount.
2. Diskon mengurangi revenue atau masuk discount account terpisah.
3. PB1/VAT/tax treatment dan account.
4. Service charge sebagai revenue atau liability.
5. Rounding account.
6. Cash over/short.
7. Complimentary/free item.
8. Void/refund pada hari yang sama atau periode berbeda.
9. Voucher sebagai payment atau liability.
10. Aggregator receivable, commission, promo subsidy, dan settlement delay.
11. Unit code untuk outlet, region, channel, dan profit center.
12. Periode accounting yang sudah ditutup.

## Contoh Posting Preview

```text
Business Date: 2026-07-23
Outlet       : PH-SBY-001

Debit  110100 Cash on Hand              2,000,000
Debit  110220 QRIS Clearing             5,000,000
Debit  110310 Aggregator Receivable     3,000,000
Credit 410100 Food Sales                8,000,000
Credit 410200 Beverage Sales            1,000,000
Credit 210100 Tax Payable               1,000,000
                                      -----------
Total Debit                            10,000,000
Total Credit                           10,000,000
```

## Keputusan Final yang Harus Didokumentasikan

Setelah workshop, repository harus mencatat:

```text
Selected posting route
Posting granularity
Source-to-account mapping
Tax treatment
Discount treatment
Refund/void rules
Settlement rules
Inventory rules
Rounding tolerance
Closed-period behavior
Retry/reversal behavior
Approval owner
Effective date
```
