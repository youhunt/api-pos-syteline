# 04 — SyteLine Cloud Conventions

## Prefix Physical Table

Pada environment SyteLine Cloud yang digunakan, custom table memperoleh prefix fisik `ue_` secara otomatis.

Contoh:

```text
Input object/metadata : SMK_RSC_POS_Batch_mst
Physical SQL table   : dbo.ue_SMK_RSC_POS_Batch_mst
```

## Aturan Penggunaan Nama

### Saat membuat object pada SyteLine/Mongoose

Gunakan:

```text
SMK_RSC_POS_Batch_mst
```

### Saat query SQL atau stored procedure

Gunakan nama fisik yang benar-benar tersedia:

```sql
SELECT *
FROM dbo.ue_SMK_RSC_POS_Batch_mst;
```

### Larangan

Jangan mengetik prefix `ue_` pada metadata bila sistem menambahkannya otomatis. Hal tersebut berisiko menghasilkan nama seperti:

```text
ue_ue_SMK_RSC_POS_Batch_mst
```

## Suffix `_mst`

Suffix `_mst` mengikuti pola tabel multi-site SyteLine. Implementasi dan view yang dihasilkan harus diverifikasi pada environment aktual, bukan diasumsikan hanya berdasarkan nama.

## Kolom Standar Mongoose

Custom table mempertahankan kolom framework berikut:

```text
CreateDate
CreatedBy
InWorkflow
NoteExistsFlag
RecordDate
RowPointer
SiteRef
UpdatedBy
```

Default yang digunakan mengikuti contoh environment:

```text
CreateDate     = getdate()
CreatedBy      = suser_sname()
InWorkflow     = 0
NoteExistsFlag = 0
RecordDate     = getdate()
RowPointer     = newid()
SiteRef        = rtrim(CONVERT(nvarchar(8), context_info(), 0))
UpdatedBy      = suser_sname()
```

## Data Type

Utamakan user-defined data type SyteLine bila tersedia dan semantik field sesuai, misalnya:

| Business Field | Data Type |
|---|---|
| Date | `DateType` / `CurrentDateType` |
| Amount | `AmountType` |
| Price | `CostPrcType` |
| Item | `ItemType` |
| Quantity | `QtyUnitType` |
| U/M | `UMType` |
| Site | `SiteType` |
| Warehouse | `WhseType` |
| Customer | `CustNumType` |
| Currency | `CurrCodeType` |
| Account | `AcctType` |
| Unit code | `UnitCode1Type` s.d. `UnitCode4Type` |
| Yes/No | `FlagNyType` |
| Username | `UsernameType` |
| GUID | `RowPointerType` |

Gunakan native `nvarchar`, `nchar`, `int`, atau `decimal` bila belum ada domain SyteLine yang tepat.

## Primary Key dan SiteRef

Contoh tabel environment menunjukkan variasi primary key. Sebelum finalisasi, periksa standar tenant dan cara IDO/view dibentuk.

Prinsip aman:

- business key harus eksplisit;
- `RowPointer` tetap unik;
- `SiteRef` wajib tersedia pada tabel multi-site;
- bila key harus unik lintas site, sertakan `SiteRef` sesuai standar environment;
- keputusan key tidak boleh diubah setelah data produksi tanpa migration plan.

## Query Verifikasi

### Verifikasi physical table

```sql
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%SMK_RSC_POS%';
```

### Verifikasi view

```sql
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_NAME LIKE '%SMK_RSC_POS%';
```

### Verifikasi kolom

```sql
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'ue_SMK_RSC_POS_Batch_mst'
ORDER BY ORDINAL_POSITION;
```

## Stored Procedure dan Form Logic

- Form script menangani tombol, konfirmasi, invoke method, refresh, dan pesan user.
- Validasi dan posting utama ditempatkan pada stored procedure atau server-side IDO Extension Class.
- Hindari loop besar di client/form.
- Proses batch besar diarahkan ke background task bila fasilitas environment mendukung.

## Deployment Discipline

Setiap perubahan harus dicatat dengan:

```text
Object name
Physical object name
Purpose
Columns/parameters changed
Dependency
Deployment date
Environment
Developer
Test result
Rollback notes
```
