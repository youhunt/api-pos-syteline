# 03 — Database Design

## Naming

| Jenis | Pola |
|---|---|
| Object pada metadata SyteLine | `SMK_RSC_POS_<Name>_mst` |
| Physical table Cloud | `dbo.ue_SMK_RSC_POS_<Name>_mst` |
| Custom IDO (rencana) | `SMKRSCPos<Name>` |
| Stored procedure (rencana) | `SMKRSCPos<Action>Sp` atau nama yang mengikuti standar environment |

## Entitas

```text
SMK_RSC_POS_Batch_mst
  1 ─── n SMK_RSC_POS_Tran_mst
              1 ─── n SMK_RSC_POS_TranLine_mst
              1 ─── n SMK_RSC_POS_Payment_mst
  1 ─── n SMK_RSC_POS_ProcessLog_mst
  1 ─── n SMK_RSC_POS_PostingPreview_mst

SMK_RSC_POS_OutletMap_mst  → mapping outlet/site/warehouse/dimensi
SMK_RSC_POS_ItemMap_mst    → mapping item/U-M/quantity
SMK_RSC_POS_PaymentMap_mst → mapping payment/account/customer/settlement
SMK_RSC_POS_TaxMap_mst     → mapping tax code/rate/account/rounding
SMK_RSC_POS_RevenueMap_mst → rule mapping revenue/discount/service account
```

## Design Status

Seluruh tabel pada dokumen ini masih merupakan **candidate design / PoC**. Raw data resmi, accounting flow, dan jalur posting belum final. Tabel dapat disederhanakan, dikembangkan, atau tidak digunakan setelah data source diterima. Perubahan dilakukan dengan versioning dan migration plan; source data tidak boleh hilang atau tertimpa.

## Common Framework Columns

Custom table mengikuti kolom standar Mongoose:

| Column | Type | Default | Purpose |
|---|---|---|---|
| `CreateDate` | `CurrentDateType` | `getdate()` | Tanggal dibuat |
| `CreatedBy` | `UsernameType` | `suser_sname()` | User pembuat |
| `InWorkflow` | `FlagNyType` | `0` | Workflow flag |
| `NoteExistsFlag` | `FlagNyType` | `0` | Note flag |
| `RecordDate` | `CurrentDateType` | `getdate()` | Tanggal perubahan record |
| `RowPointer` | `RowPointerType` | `newid()` | Identifier framework |
| `SiteRef` | `SiteType` | dari `context_info()` | Site owner record |
| `UpdatedBy` | `UsernameType` | `suser_sname()` | User terakhir memperbarui |

## Tables

### 1. Batch

Physical table: `dbo.ue_SMK_RSC_POS_Batch_mst`

Satu record mewakili satu penerimaan/kelompok data POS untuk periode bebas.

Primary key rancangan saat ini:

```text
batch_num
```

Kolom bisnis utama:

```text
batch_num, ext_batch_num, request_id, source_system, input_type,
outlet_code, period_start, period_end, received_date, trans_count,
gross_amt, discount_amt, tax_amt, service_amt, rounding_amt,
net_amt, payment_amt, stat, validation_msg, error_msg,
validate_date, process_date, processed_by, syteline_ref, retry_count
```

### 2. Transaction Header

Physical table: `dbo.ue_SMK_RSC_POS_Tran_mst`

Primary key:

```text
batch_num + trans_num
```

Kolom bisnis utama:

```text
batch_num, trans_num, receipt_num, outlet_code, business_date,
trans_datetime, trans_type, orig_trans_num, cashier_code,
order_type, sales_channel, currency_code, item_count, gross_amt,
discount_amt, tax_amt, service_amt, rounding_amt, net_amt,
payment_amt, stat, validation_msg, error_msg, syteline_ref, process_date
```

### 3. Transaction Line

Physical table: `dbo.ue_SMK_RSC_POS_TranLine_mst`

Primary key:

```text
batch_num + trans_num + line_num
```

Kolom bisnis utama:

```text
batch_num, trans_num, line_num, parent_line_num, pos_item_code,
item, item_desc, line_type, qty, u_m, unit_price, gross_amt,
discount_amt, tax_amt, service_amt, net_amt, tax_code,
promo_code, void_flag, stat, validation_msg, error_msg,
syteline_ref, process_date
```

Catatan desain: sebelum inventory flow final, pertimbangkan penambahan `pos_qty` dan `syteline_qty` agar quantity sumber tidak tertimpa hasil konversi.

### 4. Payment

Physical table: `dbo.ue_SMK_RSC_POS_Payment_mst`

Primary key:

```text
batch_num + trans_num + payment_seq
```

Kolom bisnis utama:

```text
batch_num, trans_num, payment_seq, payment_code, payment_desc,
payment_type, currency_code, payment_amt, fee_amt,
net_settlement_amt, reference_num, bank_code, card_type,
masked_card_num, approval_code, terminal_id, merchant_id,
settlement_date, acct, unit_code1, unit_code2, unit_code3,
unit_code4, stat, validation_msg, error_msg, syteline_ref, process_date
```

### 5. Process Log

Physical table: `dbo.ue_SMK_RSC_POS_ProcessLog_mst`

Primary key:

```text
log_id
```

Kolom bisnis utama:

```text
log_id, batch_num, trans_num, line_num, payment_seq, request_id,
correlation_id, process_level, process_name, process_status,
message_type, error_code, message_text, technical_detail,
processed_count, success_count, error_count, attempt_num,
started_date, completed_date, duration_ms, processed_by, syteline_ref
```

### 6. Outlet Mapping

Physical table: `dbo.ue_SMK_RSC_POS_OutletMap_mst`

Primary key:

```text
source_system + outlet_code
```

Kolom bisnis utama:

```text
source_system, outlet_code, outlet_name, target_site, whse,
cust_num, currency_code, unit_code1, unit_code2, unit_code3,
unit_code4, active_flag, effective_date, expiration_date, notes
```

### 7. Item Mapping

Physical table: `dbo.ue_SMK_RSC_POS_ItemMap_mst`

Primary key:

```text
source_system + target_site + pos_item_code
```

Kolom bisnis utama:

```text
source_system, target_site, pos_item_code, pos_item_desc,
pos_category, item, pos_u_m, u_m, qty_conv_factor,
inventory_flag, active_flag, effective_date, expiration_date, notes
```

### 8. Payment Mapping

Physical table: `dbo.ue_SMK_RSC_POS_PaymentMap_mst`

Primary key:

```text
source_system + target_site + payment_code
```

Kolom bisnis utama:

```text
source_system, target_site, payment_code, payment_desc,
payment_type, currency_code, acct, unit_code1, unit_code2,
unit_code3, unit_code4, fee_acct, fee_unit_code1,
fee_unit_code2, fee_unit_code3, fee_unit_code4, cust_num,
bank_code, settlement_type, settlement_days, active_flag,
effective_date, expiration_date, notes
```

Payment mapping digunakan untuk:

- menentukan cash/bank/clearing/receivable/liability account;
- menentukan account biaya MDR atau komisi;
- mengisi unit code hasil mapping;
- mengarahkan channel tertentu ke customer bila flow AR dipakai;
- menentukan apakah settlement immediate, delayed, AR, atau non-settlement.

### 9. Tax Mapping

Physical table: `dbo.ue_SMK_RSC_POS_TaxMap_mst`

Primary key:

```text
source_system + target_site + pos_tax_code
```

Kolom bisnis utama:

```text
source_system, target_site, pos_tax_code, pos_tax_desc,
tax_type, posting_mode, syteline_tax_code, tax_rate,
tax_inclusive_flag, taxable_flag, tax_acct, unit_code1,
unit_code2, unit_code3, unit_code4, rounding_mode,
tolerance_amt, active_flag, effective_date, expiration_date, notes
```

Tax mapping digunakan untuk:

- menerjemahkan kode pajak POS ke tax code atau account SyteLine;
- menentukan apakah pajak diproses melalui tax mechanism, direct account, atau tanpa posting terpisah;
- menyimpan expected rate dan tax-inclusive behavior;
- menentukan rounding rule dan tolerance rekonsiliasi;
- mengisi unit code untuk posting pajak.

Nama domain/UDD untuk target tax code harus diverifikasi pada tenant. Sementara itu `syteline_tax_code` dirancang sebagai `nvarchar(20)`.

### 10. Revenue Mapping

Physical table: `dbo.ue_SMK_RSC_POS_RevenueMap_mst`

Primary key:

```text
map_id
```

Kolom bisnis utama:

```text
map_id, source_system, target_site, rule_name, priority,
amount_type, outlet_code, pos_item_code, pos_category,
sales_channel, order_type, line_type, currency_code, acct,
unit_code1, unit_code2, unit_code3, unit_code4,
debit_credit, reverse_on_refund, active_flag,
effective_date, expiration_date, notes
```

Revenue mapping menggunakan rule fleksibel:

- kriteria yang `NULL` dianggap wildcard;
- rule dapat ditentukan per item, kategori, outlet, channel, order type, line type, currency, atau kombinasi;
- priority paling kecil dievaluasi lebih dahulu;
- bila priority sama, rule dengan kriteria paling spesifik dipilih;
- hasil ambigu menyebabkan validasi gagal;
- `amount_type` membedakan revenue, discount, service charge, dan komponen lain;
- debit/credit ditentukan eksplisit;
- refund dapat membalik sisi posting melalui `reverse_on_refund`.

### 11. Posting Preview

Physical table: `dbo.ue_SMK_RSC_POS_PostingPreview_mst`

Primary key:

```text
preview_num + line_num
```

Kolom bisnis utama:

```text
preview_num, line_num, batch_num, generation_num, posting_group,
target_module, source_level, trans_num, source_line_num, payment_seq,
component_type, mapping_source, mapping_ref, posting_date,
currency_code, exch_rate, acct, unit_code1, unit_code2,
unit_code3, unit_code4, description, reference_num, source_amt,
debit_amt, credit_amt, dom_debit_amt, dom_credit_amt,
approval_stat, approved_by, approved_date, posting_stat,
posted_date, syteline_ref, validation_msg, error_msg
```

Posting preview digunakan untuk:

- menggabungkan hasil outlet, item, payment, tax, dan revenue mapping;
- menghasilkan line debit-credit sebelum posting aktual;
- menyimpan source reference dan mapping reference untuk audit;
- memvalidasi account, unit code, currency, exchange rate, dan accounting period;
- memastikan total debit dan credit balance;
- mendukung approval sebelum posting;
- mempertahankan generation history saat preview dibangun ulang;
- menyimpan referensi hasil SyteLine setelah posting berhasil.

Aturan pokok:

```text
SUM(debit_amt) = SUM(credit_amt)
SUM(dom_debit_amt) = SUM(dom_credit_amt)
```

Satu line hanya boleh mengisi debit atau credit, tidak keduanya. Preview yang error, tidak balance, belum approved saat approval diwajibkan, atau sudah posted tidak boleh diposting ulang.

## Candidate Tables Berikutnya

| Table | Purpose |
|---|---|
| `SMK_RSC_POS_Inbound_mst` | Raw payload dan receive metadata bila diperlukan |
| `SMK_RSC_POS_RawLine_mst` | Alternatif landing table bila source resmi berbentuk flat/minimal |

Candidate table tidak otomatis wajib dibuat. Keputusan implementasi mengikuti raw data dan flow resmi.

## Integrity Rules

Relasi antar custom table dapat diterapkan melalui metadata/logic dan validasi server-side. Foreign key fisik perlu dipertimbangkan terhadap pola upgrade dan standard Cloud environment.

Aturan minimum:

- transaksi tidak boleh ada tanpa batch;
- line/payment tidak boleh ada tanpa transaksi;
- posting preview tidak boleh ada tanpa batch;
- `period_end >= period_start`;
- `business_date` harus sesuai aturan periode;
- `line_num` dan `payment_seq` positif;
- `qty_conv_factor > 0`;
- mapping hanya boleh dipakai bila aktif dan berlaku pada tanggal bisnis;
- payment mapping harus menghasilkan account valid;
- fee account wajib bila fee akan diposting secara terpisah;
- tax mapping harus menghasilkan tax code atau account sesuai `posting_mode`;
- tax rate, rounding, dan tolerance harus mengikuti rule yang disetujui Finance;
- revenue mapping harus menghasilkan tepat satu rule pemenang untuk setiap komponen yang akan diposting;
- account dan unit code harus valid pada target site;
- posting preview harus balance dalam transaction dan domestic currency;
- preview approved/posted tidak boleh ditimpa oleh rebuild;
- `RowPointer` harus unik;
- posting tidak boleh dilakukan dua kali.

## Reconciliation Rules

```text
Batch trans_count = COUNT(transaction)
Batch totals      = SUM(transaction totals)
Transaction item_count = COUNT(active/non-void lines sesuai aturan)
Transaction totals = SUM(line totals) + header-only charges sesuai desain
Transaction payment_amt = SUM(payment.payment_amt)
Transaction tax_amt = SUM(line tax_amt) atau hasil rule header-level tax
Posting preview debit total = posting preview credit total
Posting preview domestic debit total = posting preview domestic credit total
```

Toleransi pembulatan, treatment void/refund, treatment pajak, account revenue/discount/service, penggunaan suspense account, approval flow, exchange-rate direction, dan target posting module belum final dan harus disetujui Finance/SyteLine.
