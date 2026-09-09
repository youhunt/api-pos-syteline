# 03 — Database Design

## Naming

| Jenis | Pola |
|---|---|
| Object pada metadata SyteLine | `SMK_RSC_POS_<Name>_mst` |
| Physical table Cloud | `dbo.ue_SMK_RSC_POS_<Name>_mst` |
| Custom IDO (rencana) | `SMKRSCPos<Name>` |
| Stored procedure (rencana) | `SMKRSCPos<Action>Sp` atau nama sesuai standar environment |

## Design Status

Seluruh tabel masih merupakan **candidate design / PoC**. Raw data resmi, accounting flow, kebijakan retensi, dan jalur posting belum final. Tabel dapat disederhanakan, dikembangkan, atau tidak digunakan setelah source sample diterima.

Perubahan harus mengikuti prinsip berikut:

- source data tidak boleh hilang atau ditimpa hasil mapping;
- perubahan struktur menggunakan versioning dan migration plan;
- field tambahan sebaiknya backward-compatible;
- tabel lengkap dan tabel raw minimal merupakan profile alternatif, bukan kewajiban untuk selalu digunakan bersama.

## Entity Model

### Profile lengkap

```text
SMK_RSC_POS_Inbound_mst
   0..1 ─── 1 SMK_RSC_POS_Batch_mst
                  1 ─── n SMK_RSC_POS_Tran_mst
                              1 ─── n SMK_RSC_POS_TranLine_mst
                              1 ─── n SMK_RSC_POS_Payment_mst
                  1 ─── n SMK_RSC_POS_ProcessLog_mst
                  1 ─── n SMK_RSC_POS_PostingPreview_mst
```

### Profile minimal/flat

```text
SMK_RSC_POS_Inbound_mst
   0..1 ─── 1 SMK_RSC_POS_Batch_mst
                  1 ─── n SMK_RSC_POS_RawLine_mst
                  1 ─── n SMK_RSC_POS_ProcessLog_mst
                  1 ─── n SMK_RSC_POS_PostingPreview_mst
```

Profile minimal digunakan bila source hanya mengirim tanggal, nomor transaksi, item, quantity, dan total. Transaction header dapat dibentuk dengan grouping `business_date + trans_num`.

Mapping tables:

```text
SMK_RSC_POS_OutletMap_mst  → outlet/site/warehouse/customer/dimensi
SMK_RSC_POS_ItemMap_mst    → item/U-M/quantity conversion
SMK_RSC_POS_PaymentMap_mst → payment/account/customer/settlement
SMK_RSC_POS_TaxMap_mst     → tax code/rate/account/rounding
SMK_RSC_POS_RevenueMap_mst → revenue/discount/service account rules
```

Inbound dapat tidak memiliki batch ketika request ditolak atau payload gagal diparsing.

## Common Framework Columns

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

## Table Catalog

### 1. Batch

```text
Object   : SMK_RSC_POS_Batch_mst
Physical : dbo.ue_SMK_RSC_POS_Batch_mst
PK       : batch_num
```

```text
batch_num, ext_batch_num, request_id, source_system, input_type,
outlet_code, period_start, period_end, received_date, trans_count,
gross_amt, discount_amt, tax_amt, service_amt, rounding_amt,
net_amt, payment_amt, stat, validation_msg, error_msg,
validate_date, process_date, processed_by, syteline_ref, retry_count
```

### 2. Transaction Header

```text
Object   : SMK_RSC_POS_Tran_mst
Physical : dbo.ue_SMK_RSC_POS_Tran_mst
PK       : batch_num + trans_num
```

```text
batch_num, trans_num, receipt_num, outlet_code, business_date,
trans_datetime, trans_type, orig_trans_num, cashier_code,
order_type, sales_channel, currency_code, item_count, gross_amt,
discount_amt, tax_amt, service_amt, rounding_amt, net_amt,
payment_amt, stat, validation_msg, error_msg, syteline_ref, process_date
```

### 3. Transaction Line

```text
Object   : SMK_RSC_POS_TranLine_mst
Physical : dbo.ue_SMK_RSC_POS_TranLine_mst
PK       : batch_num + trans_num + line_num
```

```text
batch_num, trans_num, line_num, parent_line_num, pos_item_code,
item, item_desc, line_type, qty, u_m, unit_price, gross_amt,
discount_amt, tax_amt, service_amt, net_amt, tax_code,
promo_code, void_flag, stat, validation_msg, error_msg,
syteline_ref, process_date
```

Source quantity/U-M tidak boleh ditimpa hasil konversi. Bila diperlukan, tambahkan `pos_qty`, `syteline_qty`, dan `pos_u_m` secara terpisah.

### 4. Payment

```text
Object   : SMK_RSC_POS_Payment_mst
Physical : dbo.ue_SMK_RSC_POS_Payment_mst
PK       : batch_num + trans_num + payment_seq
```

```text
batch_num, trans_num, payment_seq, payment_code, payment_desc,
payment_type, currency_code, payment_amt, fee_amt,
net_settlement_amt, reference_num, bank_code, card_type,
masked_card_num, approval_code, terminal_id, merchant_id,
settlement_date, acct, unit_code1, unit_code2, unit_code3,
unit_code4, stat, validation_msg, error_msg, syteline_ref, process_date
```

### 5. Process Log

```text
Object   : SMK_RSC_POS_ProcessLog_mst
Physical : dbo.ue_SMK_RSC_POS_ProcessLog_mst
PK       : log_id
```

```text
log_id, batch_num, trans_num, line_num, payment_seq, request_id,
correlation_id, process_level, process_name, process_status,
message_type, error_code, message_text, technical_detail,
processed_count, success_count, error_count, attempt_num,
started_date, completed_date, duration_ms, processed_by, syteline_ref
```

### 6. Outlet Mapping

```text
Object   : SMK_RSC_POS_OutletMap_mst
Physical : dbo.ue_SMK_RSC_POS_OutletMap_mst
PK       : source_system + outlet_code
```

```text
source_system, outlet_code, outlet_name, target_site, whse,
cust_num, currency_code, unit_code1, unit_code2, unit_code3,
unit_code4, active_flag, effective_date, expiration_date, notes
```

### 7. Item Mapping

```text
Object   : SMK_RSC_POS_ItemMap_mst
Physical : dbo.ue_SMK_RSC_POS_ItemMap_mst
PK       : source_system + target_site + pos_item_code
```

```text
source_system, target_site, pos_item_code, pos_item_desc,
pos_category, item, pos_u_m, u_m, qty_conv_factor,
inventory_flag, active_flag, effective_date, expiration_date, notes
```

### 8. Payment Mapping

```text
Object   : SMK_RSC_POS_PaymentMap_mst
Physical : dbo.ue_SMK_RSC_POS_PaymentMap_mst
PK       : source_system + target_site + payment_code
```

```text
source_system, target_site, payment_code, payment_desc,
payment_type, currency_code, acct, unit_code1, unit_code2,
unit_code3, unit_code4, fee_acct, fee_unit_code1,
fee_unit_code2, fee_unit_code3, fee_unit_code4, cust_num,
bank_code, settlement_type, settlement_days, active_flag,
effective_date, expiration_date, notes
```

### 9. Tax Mapping

```text
Object   : SMK_RSC_POS_TaxMap_mst
Physical : dbo.ue_SMK_RSC_POS_TaxMap_mst
PK       : source_system + target_site + pos_tax_code
```

```text
source_system, target_site, pos_tax_code, pos_tax_desc,
tax_type, posting_mode, syteline_tax_code, tax_rate,
tax_inclusive_flag, taxable_flag, tax_acct, unit_code1,
unit_code2, unit_code3, unit_code4, rounding_mode,
tolerance_amt, active_flag, effective_date, expiration_date, notes
```

Target tax-code domain/UDD harus diverifikasi pada tenant. Sementara `syteline_tax_code` menggunakan `nvarchar(20)`.

### 10. Revenue Mapping

```text
Object   : SMK_RSC_POS_RevenueMap_mst
Physical : dbo.ue_SMK_RSC_POS_RevenueMap_mst
PK       : map_id
```

```text
map_id, source_system, target_site, rule_name, priority,
amount_type, outlet_code, pos_item_code, pos_category,
sales_channel, order_type, line_type, currency_code, acct,
unit_code1, unit_code2, unit_code3, unit_code4,
debit_credit, reverse_on_refund, active_flag,
effective_date, expiration_date, notes
```

Kriteria `NULL` dianggap wildcard. Rule dipilih berdasarkan priority, specificity, dan effective date. Hasil ambigu menyebabkan validasi gagal.

### 11. Posting Preview

```text
Object   : SMK_RSC_POS_PostingPreview_mst
Physical : dbo.ue_SMK_RSC_POS_PostingPreview_mst
PK       : preview_num + line_num
```

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

Aturan pokok:

```text
SUM(debit_amt) = SUM(credit_amt)
SUM(dom_debit_amt) = SUM(dom_credit_amt)
```

Satu line hanya boleh mengisi debit atau credit. Preview error, unbalanced, belum approved ketika approval diwajibkan, atau sudah posted tidak boleh diposting.

### 12. Inbound Request

```text
Object   : SMK_RSC_POS_Inbound_mst
Physical : dbo.ue_SMK_RSC_POS_Inbound_mst
PK       : inbound_id
```

```text
inbound_id, request_id, idempotency_key, correlation_id,
source_system, source_reference, outlet_code, endpoint_name,
http_method, content_type, payload_version, payload_format,
storage_mode, payload_text, payload_location, content_length,
payload_sha256, client_ip, user_agent, received_date, stat,
parsed_date, batch_num, row_count, accepted_count, rejected_count,
response_code, response_message, error_msg, retry_count,
retention_date, purged_flag, purged_date
```

Inbound digunakan untuk request tracking, idempotency, optional raw-payload retention, parsing result, response/error, retry, dan purge control.

`nvarchar(max)`/long-text support, ukuran maksimum request, storage mode, client metadata, dan kebijakan retensi harus diverifikasi pada tenant serta disetujui Security/Infrastructure.

### 13. Minimal Raw Line

```text
Object   : SMK_RSC_POS_RawLine_mst
Physical : dbo.ue_SMK_RSC_POS_RawLine_mst
PK       : batch_num + source_row_num
```

Source minimal:

```text
business_date, trans_num, pos_item_code, pos_qty, total_amt
```

Kolom bisnis/proses lengkap:

```text
batch_num, source_row_num, business_date, trans_num,
pos_item_code, pos_qty, total_amt, item, syteline_qty,
u_m, stat, validation_msg, error_msg, process_date, syteline_ref
```

Aturan penting:

- `source_row_num` menjaga uniqueness walaupun item yang sama muncul dua kali dalam transaksi;
- `pos_qty` dan `total_amt` adalah source values dan tidak boleh ditimpa;
- `item`, `syteline_qty`, dan `u_m` adalah hasil mapping;
- transaction summary dibentuk dengan grouping `business_date + trans_num`;
- jumlah transaksi menggunakan distinct transaction identity, bukan jumlah raw rows;
- payment, tax, discount, service charge, void/refund, currency, dan outlet yang tidak tersedia tidak boleh diisi dengan asumsi tersembunyi.

## Profile Selection

| Kondisi Source | Profile yang Dipertimbangkan |
|---|---|
| Payload lengkap header-detail-payment | `Batch + Tran + TranLine + Payment` |
| Payload flat/minimal | `Batch + RawLine` |
| Payload gagal parsing atau perlu idempotency audit | `Inbound` tetap digunakan |
| Membutuhkan simulasi accounting | `PostingPreview` |
| Membutuhkan troubleshooting/retry | `ProcessLog` |

Keputusan final dibuat setelah contoh raw data, data dictionary, volume, serta accounting flow resmi diterima.

## Integrity Rules

- inbound request dapat ada tanpa batch bila parsing gagal;
- `batch_num` inbound hanya diisi setelah batch berhasil dibuat;
- transaksi tidak boleh ada tanpa batch;
- line/payment tidak boleh ada tanpa transaksi;
- raw line tidak boleh ada tanpa batch;
- posting preview tidak boleh ada tanpa batch;
- `source_row_num > 0` dan unik dalam batch;
- `period_end >= period_start`;
- `business_date` harus sesuai aturan periode;
- `line_num` dan `payment_seq` positif;
- `qty_conv_factor > 0`;
- mapping hanya boleh dipakai bila aktif dan berlaku pada business date;
- payment mapping harus menghasilkan account valid;
- fee account wajib bila fee diposting terpisah;
- tax mapping harus menghasilkan tax code atau account sesuai `posting_mode`;
- revenue mapping harus menghasilkan tepat satu rule pemenang;
- account dan unit code harus valid pada target site;
- posting preview harus balance dalam transaction dan domestic currency;
- preview approved/posted tidak boleh ditimpa oleh rebuild;
- idempotency policy harus mencegah staging/posting ganda;
- raw payload dan source row values tidak boleh ditimpa oleh hasil parsing/mapping;
- `RowPointer` harus unik;
- posting tidak boleh dilakukan dua kali.

## Reconciliation Rules

```text
Batch trans_count = COUNT(transaction identity)
Batch totals = SUM(transaction totals)
Transaction item_count = COUNT(active/non-void lines sesuai aturan)
Transaction totals = SUM(line totals) + header-only charges sesuai desain
Transaction payment_amt = SUM(payment.payment_amt)
Transaction tax_amt = SUM(line tax_amt) atau hasil rule header-level tax
Inbound row_count = accepted_count + rejected_count, bila partial acceptance didukung
RawLine transaction total = SUM(total_amt) per business_date + trans_num
RawLine transaction count = COUNT(DISTINCT business_date + trans_num)
Posting preview debit total = posting preview credit total
Posting preview domestic debit total = posting preview domestic credit total
```

Toleransi pembulatan, treatment void/refund, pajak, account revenue/discount/service, suspense account, approval flow, exchange-rate direction, target posting module, raw-payload retention, partial acceptance, dan default untuk field source yang tidak tersedia belum final dan harus disetujui Finance/SyteLine/Security.