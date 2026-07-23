# 03 — Database Design

## Naming

| Jenis | Pola |
|---|---|
| Object pada metadata SyteLine | `SMK_RSC_POS_<Name>_mst` |
| Physical table Cloud | `dbo.ue_SMK_RSC_POS_<Name>_mst` |
| Custom IDO (rencana) | `SMKRSCPos<Name>` |
| Stored procedure (rencana) | `SMKRSCPos<Action>Sp` atau nama yang mengikuti standar environment |

## Design Status

Seluruh tabel masih merupakan **candidate design / PoC**. Raw data resmi, accounting flow, kebijakan retensi, dan jalur posting belum final. Tabel dapat disederhanakan, dikembangkan, atau tidak digunakan setelah data source diterima. Perubahan dilakukan dengan versioning dan migration plan; source data tidak boleh hilang atau tertimpa.

## Entity Model

```text
SMK_RSC_POS_Inbound_mst
   0..1 ─── 1 SMK_RSC_POS_Batch_mst
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

Kolom bisnis utama:

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

Inbound digunakan untuk:

- mencatat request sebelum parsing dimulai;
- menyediakan idempotency dan exact-payload duplicate detection;
- mempertahankan raw payload atau referensi penyimpanannya sesuai policy;
- mencatat hasil parsing, counts, response, dan error;
- menautkan request ke batch setelah staging berhasil dibuat;
- mendukung retensi dan purge raw payload tanpa menghapus metadata audit yang diperlukan.

`nvarchar(max)`/long-text support, ukuran maksimum request, storage mode, client metadata, dan kebijakan retensi harus diverifikasi pada tenant serta disetujui Security/Infrastructure.

## Candidate Table Tambahan

| Table | Purpose |
|---|---|
| `SMK_RSC_POS_RawLine_mst` | Alternatif landing table bila source resmi berbentuk flat/minimal |

Candidate table tidak otomatis wajib dibuat. Keputusan implementasi mengikuti raw data dan flow resmi.

## Integrity Rules

- inbound request dapat ada tanpa batch bila parsing gagal;
- `batch_num` inbound hanya diisi setelah batch berhasil dibuat;
- transaksi tidak boleh ada tanpa batch;
- line/payment tidak boleh ada tanpa transaksi;
- posting preview tidak boleh ada tanpa batch;
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
- raw payload tidak boleh ditimpa oleh hasil parsing atau mapping;
- `RowPointer` harus unik;
- posting tidak boleh dilakukan dua kali.

## Reconciliation Rules

```text
Batch trans_count = COUNT(transaction)
Batch totals = SUM(transaction totals)
Transaction item_count = COUNT(active/non-void lines sesuai aturan)
Transaction totals = SUM(line totals) + header-only charges sesuai desain
Transaction payment_amt = SUM(payment.payment_amt)
Transaction tax_amt = SUM(line tax_amt) atau hasil rule header-level tax
Inbound row_count = accepted_count + rejected_count, bila partial acceptance didukung
Posting preview debit total = posting preview credit total
Posting preview domestic debit total = posting preview domestic credit total
```

Toleransi pembulatan, treatment void/refund, pajak, account revenue/discount/service, suspense account, approval flow, exchange-rate direction, target posting module, raw-payload retention, dan partial acceptance belum final dan harus disetujui Finance/SyteLine/Security.
