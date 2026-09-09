# `<MetadataObjectName>`

## Identity

```text
Metadata object : <MetadataObjectName>
Physical table  : dbo.ue_<MetadataObjectName>
Purpose         : <Tujuan tabel>
```

## Primary Key

```text
<column_1> + <column_2>
```

## Struktur kolom

Gunakan format ini untuk seluruh dokumentasi tabel SyteLine pada repository ini.

| Column Name | Schema | Table Name | Data Type | System Data Type | Length | Decimal Position | Default Value | Is Nullable | Primary Key | Key Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `<column_name>` | dbo | ue_`<MetadataObjectName>` | `<ApplicationDataType>` | `<SQLDataType>` | `<length>` | `<scale>` | `<default>` | YES/NO | 0/1 | `<sequence>` |
| `CreateDate` | dbo | ue_`<MetadataObjectName>` | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `CreatedBy` | dbo | ue_`<MetadataObjectName>` | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |
| `InWorkflow` | dbo | ue_`<MetadataObjectName>` | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `NoteExistsFlag` | dbo | ue_`<MetadataObjectName>` | FlagNyType | tinyint |  |  | `0` | NO | 0 |  |
| `RecordDate` | dbo | ue_`<MetadataObjectName>` | CurrentDateType | datetime |  |  | `getdate()` | NO | 0 |  |
| `RowPointer` | dbo | ue_`<MetadataObjectName>` | RowPointerType | uniqueidentifier |  |  | `newid()` | NO | 0 |  |
| `SiteRef` | dbo | ue_`<MetadataObjectName>` | SiteType | nvarchar | 8 |  | `rtrim(CONVERT([nvarchar](8),context_info(),(0)))` | NO | 0 |  |
| `UpdatedBy` | dbo | ue_`<MetadataObjectName>` | UsernameType | nvarchar | 128 |  | `suser_sname()` | NO | 0 |  |

## Candidate Indexes

```text
<IndexName>
<Column1>, <Column2>, <Column3>
```

## Validation Rules

- <Rule 1>
- <Rule 2>

## Example

```text
<column_name> : <sample value>
```

## Formatting Rules

1. Gunakan physical table Cloud dengan prefix `ue_` pada kolom **Table Name**.
2. Tulis Application Data Type pada **Data Type** dan SQL storage type pada **System Data Type**.
3. Untuk decimal, isi precision pada **Length** dan scale pada **Decimal Position**.
4. Gunakan `YES` atau `NO` pada **Is Nullable**.
5. Gunakan `1` pada **Primary Key** hanya untuk kolom yang termasuk primary key.
6. Isi **Key Sequence** mulai dari `1` sesuai urutan composite key.
7. Sertakan seluruh standard Mongoose columns pada setiap tabel.
8. Nilai default SQL ditulis dengan backtick agar mudah dibaca.
