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

SMK_RSC_POS_OutletMap_mst  → mapping outlet/site/warehouse/dimensi
SMK_RSC_POS_ItemMap_mst    → mapping item/U-M/quantity
SMK_RSC_POS_PaymentMap_mst → mapping payment/account/customer/settlement
```

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

## Candidate Tables Berikutnya

| Table | Purpose |
|---|---|
| `SMK_RSC_POS_TaxMap_mst` | Mapping tax code ke tax system/account |
| `SMK_RSC_POS_RevenueMap_mst` | Mapping category/item/channel ke revenue account |
| `SMK_RSC_POS_PostingPreview_mst` | Preview debit-credit sebelum posting |
| `SMK_RSC_POS_Inbound_mst` | Raw payload dan receive metadata bila diperlukan |

## Integrity Rules

Relasi antar custom table dapat diterapkan melalui metadata/logic dan validasi server-side. Foreign key fisik perlu dipertimbangkan terhadap pola upgrade dan standard Cloud environment.

Aturan minimum:

- transaksi tidak boleh ada tanpa batch;
- line/payment tidak boleh ada tanpa transaksi;
- `period_end >= period_start`;
- `business_date` harus sesuai aturan periode;
- `line_num` dan `payment_seq` positif;
- `qty_conv_factor > 0`;
- mapping hanya boleh dipakai bila aktif dan berlaku pada tanggal bisnis;
- payment mapping harus menghasilkan account valid;
- fee account wajib bila fee akan diposting secara terpisah;
- `RowPointer` harus unik;
- posting tidak boleh dilakukan dua kali.

## Reconciliation Rules

```text
Batch trans_count = COUNT(transaction)
Batch totals      = SUM(transaction totals)
Transaction item_count = COUNT(active/non-void lines sesuai aturan)
Transaction totals = SUM(line totals) + header-only charges sesuai desain
Transaction payment_amt = SUM(payment.payment_amt)
```

Toleransi pembulatan dan treatment void/refund belum final dan harus disetujui Finance.