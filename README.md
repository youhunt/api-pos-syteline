# API POS SyteLine

Repository dokumentasi dan artefak pengembangan integrasi **POS Pizza Hut / RSC → Infor SyteLine (Mongoose)**.

## Implementasi SMK069 Saat Ini

Dokumentasi utama untuk alur yang sedang diimplementasikan dan diuji tersedia di:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

Alur final:

```text
CSV mentah
→ binary upload
→ parsed CSV rows
→ canonical JSON
→ raw inbound
→ field mapping dan validation
→ temporary sales staging
→ Process/Reprocess per source order
→ co_mst type B
→ coitem_mst
→ co_bln_mst
```

Prinsip nomor:

```text
staging.co_num         = source/POS order number
co_mst.cust_po         = source/POS order number
staging.created_co_num = generated SyteLine CO number
co_mst.co_num          = generated SyteLine CO number
coitem_mst.co_num      = generated SyteLine CO number
co_bln_mst.co_num      = generated SyteLine CO number
```

Current implementation also includes:

- raw inbound preservation and batch idempotency;
- customer, item, warehouse, quantity, price, exchange-rate, and U/M validation;
- atomic-order validation;
- U/M matching against item base U/M or Global/Item/Customer conversion;
- receive/validation separated from Customer Order creation;
- Blanket Customer Order header with `co_mst.type = 'B'`;
- one `coitem_mst` and one `co_bln_mst` row per staging line;
- caller-safe Mongoose/IDO transaction handling;
- idempotent existing Blanket CO synchronization;
- read-only verification SQL and UAT checklist.

> Repository parity note: the Import & Validate wrapper and current documentation are committed. Exact final tenant source for the parser, Receive procedure, and Process procedure still needs to be exported and synchronized into this branch. See `CHANGELOG.md` and the end-to-end document for the explicit boundary.

## Tujuan Umum

Menyediakan API di dalam SyteLine yang menerima data transaksi POS, menyimpan raw data dan staging, melakukan controlled validation and mapping, lalu membentuk transaksi SyteLine dengan audit trail, duplicate control, error handling, dan retry.

## Prinsip Arsitektur

```text
POS / Postman / CSV Test Console
                 |
                 v
       Custom REST API / Service IDO
                 |
                 v
       Raw Inbound + Canonical Mapping
                 |
                 v
       Validation + Temporary Sales
                 |
                 v
       Controlled Process/Reprocess
                 |
                 v
 co_mst type B + coitem_mst + co_bln_mst
```

Seluruh integrasi berada **di dalam ekosistem SyteLine/Mongoose**, bukan aplikasi web terpisah.

## Konvensi SyteLine Cloud

Nama object yang dibuat pada metadata SyteLine menggunakan prefix `SMK_`. Pada environment Cloud, tabel fisik otomatis memperoleh prefix `ue_`.

Contoh:

```text
Metadata object : SMK069_temp_sales_mst
Physical table  : dbo.ue_SMK069_temp_sales_mst
```

Aturan:

- pada form/metadata object gunakan nama metadata;
- pada SQL/stored procedure gunakan nama physical table `dbo.ue_...`;
- jangan menambahkan `ue_` secara manual pada metadata bila environment membuatnya otomatis.

## Objek Utama SMK069

### Custom Tables

```text
dbo.ue_SMK069_pos_csv_batch_mst
dbo.ue_SMK069_pos_csv_upload_mst
dbo.ue_SMK069_pos_sales_inbound_mst
dbo.ue_SMK069_pos_field_map_mst
dbo.ue_SMK069_temp_sales_mst
```

### Forms

```text
SMK POS CSV TEST CONSOLE
SMK API SALES ERROR PROCESSING
```

### IDOs

```text
ue_SMK069PosCsvBatch
ue_SMK069PosCsvUpload
ue_SMK069TempSales
```

### Stored Procedures

```text
SMK069InitializeCsvTestBatchSp
SMK069ImportCsvFileSp
SMK069RunCsvTestBatchSp
SMK069ReceivePosSalesJsonSp
SMK069ProcessCustomerOrderSp
```

### Standard SyteLine Targets

```text
dbo.co_mst
dbo.coitem_mst
dbo.co_bln_mst
```

## Status Model

### Inbound

```text
R = Raw received
V = Valid
E = Error
T = Transferred to temp
```

### Temporary Sales

```text
N = New
V = Valid / ready
E = Error
P = Processed
C = Cancelled
```

### CSV Batch

```text
D = Draft / parsed
R = Running
E = Error
C = Receive/validation completed
```

`CSV batch status C` does not mean the Customer Order is already created. Customer Order creation occurs in a separate Process/Reprocess step.

## Dokumentasi Penting

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
forms/02-SMK069PosCsvTestConsole.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
database/tables/SMK069_temp_sales_mst.md
tests/evidence/2026-08-06-smk069-um-validation-and-blanket-order-corrections.md
CHANGELOG.md
```

## Current Known Gaps

```text
- exact final parser/Receive/Process SQL source pending repository synchronization;
- conversion factor is not yet applied to converted quantity/price fields;
- CreatedCoNum IDO property/grid requires final tenant verification;
- 100-row/25-order formal UAT evidence is pending;
- final external REST URL, authorization, and security contract is pending;
- Blanket Order release/shipment/invoice lifecycle requires functional confirmation.
```

## Security Principles

- API methods use controlled service methods, not unrestricted direct writes.
- Raw payload follows masking, authorization, size, and retention rules.
- Password, token, secret, card number, PIN, CVV, and authorization headers must not be stored.
- REST permissions follow least privilege.
- Source data is retained for audit and is not silently overwritten.

## Repository

```text
youhunt/api-pos-syteline
```

Documentation and SQL must be updated in the same PR whenever tenant behavior changes, so repository documentation remains aligned with runtime implementation.
